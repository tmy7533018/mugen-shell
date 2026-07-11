// Package toolfilter narrows the tool list sent to the LLM to the categories
// relevant to the current user message. Local models mis-pick or hallucinate
// tool calls more as the catalog grows, so the filter keeps each turn's list
// short. Selection is a cascade — keyword match, embedding similarity,
// recently-used categories, always-included categories — and any turn without
// a confident signal falls back to the full list, so filtering can only trim,
// never remove a capability outright.
package toolfilter

import (
	"context"
	"fmt"
	"math"
	"os"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/tmy7533018/mugen-ai/internal/tools"
)

// EmbedFunc returns one vector per input text. nil disables the embedding
// layer (keyword-only mode).
type EmbedFunc func(ctx context.Context, texts []string) ([][]float32, error)

type Config struct {
	TopK          int
	MinScore      float64
	AlwaysInclude []string
}

// minToolsToFilter skips filtering for small catalogs where trimming isn't
// worth the extra moving parts.
const minToolsToFilter = 12

// utteranceEmbedBudget bounds the per-turn embedding call so a cold model
// load can't stall the chat; the turn degrades to keyword-only instead.
const utteranceEmbedBudget = 800 * time.Millisecond

// warmRetryCooldown spaces re-attempts at building category vectors after a
// failure (Ollama down, model not pulled) so we don't hammer a dead backend.
const warmRetryCooldown = 5 * time.Minute

type Filter struct {
	cfg   Config
	embed EmbedFunc

	mu       sync.Mutex
	catVecs  map[string][]float32 // unit vectors, ready when non-nil
	warming  bool
	retryAt  time.Time
	warnOnce sync.Once
}

func New(cfg Config, embed EmbedFunc) *Filter {
	if cfg.TopK <= 0 {
		cfg.TopK = 4
	}
	if cfg.MinScore <= 0 {
		cfg.MinScore = 0.4
	}
	return &Filter{cfg: cfg, embed: embed}
}

// Warm builds and embeds one profile text per tool category so Select can
// score utterances against them. Safe to call concurrently; only one build
// runs at a time. A failure is remembered and retried lazily by Select.
func (f *Filter) Warm(ctx context.Context, all []tools.Tool) {
	if f == nil || f.embed == nil {
		return
	}
	f.mu.Lock()
	if f.warming || f.catVecs != nil {
		f.mu.Unlock()
		return
	}
	f.warming = true
	f.mu.Unlock()

	profiles := categoryProfiles(all)
	names := make([]string, 0, len(profiles))
	texts := make([]string, 0, len(profiles))
	for name := range profiles {
		names = append(names, name)
	}
	sort.Strings(names)
	for _, name := range names {
		texts = append(texts, profiles[name])
	}

	vecs, err := f.embed(ctx, texts)

	f.mu.Lock()
	defer f.mu.Unlock()
	f.warming = false
	if err != nil || len(vecs) != len(names) {
		f.retryAt = time.Now().Add(warmRetryCooldown)
		f.warnOnce.Do(func() {
			fmt.Fprintf(os.Stderr, "toolfilter: embedding warm failed, keyword-only until it heals (is the embed model pulled?): %v\n", err)
		})
		return
	}
	f.catVecs = make(map[string][]float32, len(names))
	for i, name := range names {
		f.catVecs[name] = normalize(vecs[i])
	}
}

// Select returns the tools to present for this utterance plus a short
// human-readable reason for the decision (for the stderr log). sticky is the
// set of categories the conversation used recently.
func (f *Filter) Select(ctx context.Context, utterance string, sticky []string, all []tools.Tool) ([]tools.Tool, string) {
	if f == nil || len(all) <= minToolsToFilter {
		return all, "small toolset"
	}

	cats := map[string]bool{}
	for _, t := range all {
		cats[tools.CategoryOf(t.Name)] = true
	}

	kw := keywordHits(utterance, cats)
	emb, embOK := f.embedHits(ctx, utterance, cats, all)

	// No embedding signal available and no keyword hit: too little evidence
	// to trim anything safely.
	if !embOK && len(kw) == 0 {
		return all, "no signal (embedding unavailable)"
	}

	selected := map[string]bool{}
	for _, c := range kw {
		selected[c] = true
	}
	for _, c := range emb {
		selected[c] = true
	}
	for _, c := range sticky {
		if cats[c] {
			selected[c] = true
		}
	}
	for _, c := range f.cfg.AlwaysInclude {
		if cats[c] {
			selected[c] = true
		}
	}

	// Nothing at all (no always-include configured, fresh conversation):
	// an empty tool list would silently strip capabilities, so send all.
	if len(selected) == 0 {
		return all, "no categories selected"
	}
	if len(selected) >= len(cats) {
		return all, "selection covers all categories"
	}

	out := make([]tools.Tool, 0, len(all))
	for _, t := range all {
		if selected[tools.CategoryOf(t.Name)] {
			out = append(out, t)
		}
	}
	reason := fmt.Sprintf("kw=%v embed=%v sticky=%v", kw, emb, sticky)
	return out, reason
}

// embedHits scores the utterance against every category profile and returns
// the confident matches. ok=false means the embedding layer produced no
// verdict (disabled, not warmed, or the call failed) — distinct from "ran
// and found nothing related", which returns an empty slice with ok=true.
func (f *Filter) embedHits(ctx context.Context, utterance string, cats map[string]bool, all []tools.Tool) ([]string, bool) {
	if f.embed == nil {
		return nil, false
	}
	f.mu.Lock()
	vecs := f.catVecs
	needWarm := vecs == nil && !f.warming && time.Now().After(f.retryAt)
	f.mu.Unlock()

	if vecs == nil {
		// Heal a failed startup warm in the background; this turn still
		// degrades to keyword-only.
		if needWarm {
			toolsCopy := append([]tools.Tool(nil), all...)
			go f.Warm(context.Background(), toolsCopy)
		}
		return nil, false
	}

	ectx, cancel := context.WithTimeout(ctx, utteranceEmbedBudget)
	defer cancel()
	uv, err := f.embed(ectx, []string{truncate(utterance, 512)})
	if err != nil || len(uv) != 1 {
		return nil, false
	}
	u := normalize(uv[0])

	type scored struct {
		cat   string
		score float64
	}
	var ranked []scored
	for cat, v := range vecs {
		if !cats[cat] {
			continue
		}
		if s := dot(u, v); s >= f.cfg.MinScore {
			ranked = append(ranked, scored{cat, s})
		}
	}
	sort.Slice(ranked, func(i, j int) bool { return ranked[i].score > ranked[j].score })
	if len(ranked) > f.cfg.TopK {
		ranked = ranked[:f.cfg.TopK]
	}
	out := make([]string, len(ranked))
	for i, s := range ranked {
		out[i] = s.cat
	}
	return out, true
}

// categoryProfiles builds the text embedded per category: the category name
// followed by every tool's name and description, so the vector reflects the
// category's whole vocabulary (including MCP servers we have no keywords for).
func categoryProfiles(all []tools.Tool) map[string]string {
	var b = map[string]*strings.Builder{}
	for _, t := range all {
		cat := tools.CategoryOf(t.Name)
		sb, ok := b[cat]
		if !ok {
			sb = &strings.Builder{}
			sb.WriteString(cat)
			b[cat] = sb
		}
		fmt.Fprintf(sb, "\n%s: %s", t.Name, t.Description)
	}
	out := make(map[string]string, len(b))
	for cat, sb := range b {
		out[cat] = sb.String()
	}
	return out
}

func normalize(v []float32) []float32 {
	var sum float64
	for _, x := range v {
		sum += float64(x) * float64(x)
	}
	n := math.Sqrt(sum)
	if n == 0 {
		return v
	}
	out := make([]float32, len(v))
	for i, x := range v {
		out[i] = float32(float64(x) / n)
	}
	return out
}

func dot(a, b []float32) float64 {
	if len(a) != len(b) {
		return 0
	}
	var s float64
	for i := range a {
		s += float64(a[i]) * float64(b[i])
	}
	return s
}

func truncate(s string, n int) string {
	rs := []rune(s)
	if len(rs) <= n {
		return s
	}
	return string(rs[:n])
}
