// Package toolfilter narrows the tool list sent to the LLM to the categories
// relevant to the current user message, because local models mis-pick tool
// calls more as the catalog grows. Selection cascades over keyword match,
// embedding similarity, recently-used and always-included categories; a turn
// without a confident signal falls back to the full list, so filtering can only
// trim, never remove a capability outright.
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

// Below this, trimming isn't worth the extra moving parts.
const minToolsToFilter = 12

// Bounds the per-turn embedding call so a cold model load can't stall the
// chat; the turn degrades to keyword-only instead.
const utteranceEmbedBudget = 800 * time.Millisecond

// Spaces re-attempts after a failure so we don't hammer a dead backend.
const warmRetryCooldown = 5 * time.Minute

// Without this, a backend that accepts the connection but never replies would
// leave warming=true forever, wedging the embedding layer in keyword-only mode.
// Generous because a cold embed model can take several seconds to load.
const warmBudget = 30 * time.Second

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
	// Negative is the "unset" sentinel; an explicit 0 TopK is honoured (it
	// means "add no embedding categories, keyword/sticky/always only").
	if cfg.TopK < 0 {
		cfg.TopK = 4
	}
	// A 0 MinScore would treat every positive cosine as a hit, defeating the
	// threshold.
	if cfg.MinScore <= 0 {
		cfg.MinScore = 0.4
	}
	return &Filter{cfg: cfg, embed: embed}
}

// Warm builds and embeds one profile text per tool category so Select can score
// utterances against them. Safe to call concurrently; a failure is remembered
// and retried lazily by Select.
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

	wctx, cancel := context.WithTimeout(ctx, warmBudget)
	defer cancel()
	vecs, err := f.embed(wctx, texts)

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

// Select returns the tools to present for this utterance plus a reason string
// for the stderr log. sticky is the set of categories the conversation used
// recently.
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

	// Only a keyword or embedding hit is evidence about THIS turn; sticky and
	// always merely ride along. Trimming to those alone would silently strip a
	// capability the user just asked for.
	if len(kw) == 0 && len(emb) == 0 {
		return all, "no signal"
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
	// Keyword-only mode can't assess a category with no keyword dictionary —
	// every MCP server. Trimming those would make the user's MCP tools vanish.
	if !embOK {
		for c := range cats {
			if !categoryHasKeywords(c) {
				selected[c] = true
			}
		}
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

// ok=false means the embedding layer produced no verdict at all (disabled, not
// warmed, or the call failed) — distinct from "ran and found nothing related",
// which is an empty slice with ok=true.
func (f *Filter) embedHits(ctx context.Context, utterance string, cats map[string]bool, all []tools.Tool) ([]string, bool) {
	if f.embed == nil {
		return nil, false
	}
	f.mu.Lock()
	vecs := f.catVecs
	needWarm := vecs == nil && !f.warming && time.Now().After(f.retryAt)
	f.mu.Unlock()

	if vecs == nil {
		// Heals a failed startup warm; this turn still degrades to keyword-only.
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

// Folding in every tool's name and description gives the vector the category's
// whole vocabulary, including MCP servers we have no keywords for.
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
