package toolfilter

import (
	"context"
	"errors"
	"fmt"
	"math"
	"sort"
	"strings"
	"testing"

	"github.com/tmy7533018/mugen-ai/internal/tools"
)

// Two tools per category, so a handful of categories clears minToolsToFilter.
func testTools(cats ...string) []tools.Tool {
	var out []tools.Tool
	for _, c := range cats {
		out = append(out,
			tools.Tool{Name: c + "_get", Description: "Read " + c + " state."},
			tools.Tool{Name: c + "_set", Description: "Change " + c + " state."},
		)
	}
	return out
}

func catsOf(ts []tools.Tool) []string {
	seen := map[string]bool{}
	var out []string
	for _, t := range ts {
		c := tools.CategoryOf(t.Name)
		if !seen[c] {
			seen[c] = true
			out = append(out, c)
		}
	}
	sort.Strings(out)
	return out
}

// Returns unit basis vectors: Warm gets one axis per profile in the
// sorted-category order it uses, and utterances embed to target.
type basisEmbed struct {
	axes   map[string]int
	dim    int
	target []float32
	fail   bool
}

func newBasisEmbed(sortedCats []string) *basisEmbed {
	axes := map[string]int{}
	for i, c := range sortedCats {
		axes[c] = i
	}
	// One padding axis represents "unrelated to every category" so a target
	// can be built whose cosine against each category equals its weight.
	return &basisEmbed{axes: axes, dim: len(sortedCats) + 1}
}

func (b *basisEmbed) fn(_ context.Context, texts []string) ([][]float32, error) {
	if b.fail {
		return nil, errors.New("embed backend down")
	}
	out := make([][]float32, len(texts))
	for i, text := range texts {
		// Warm profiles start with the category name on the first line.
		firstLine := text
		if j := strings.IndexByte(text, '\n'); j >= 0 {
			firstLine = text[:j]
		}
		if axis, ok := b.axes[firstLine]; ok && len(texts) > 1 {
			v := make([]float32, b.dim)
			v[axis] = 1
			out[i] = v
			continue
		}
		out[i] = b.target
	}
	return out, nil
}

func (b *basisEmbed) pointAt(t *testing.T, weights map[string]float64) {
	t.Helper()
	v := make([]float32, b.dim)
	var sumSq float64
	for cat, w := range weights {
		axis, ok := b.axes[cat]
		if !ok {
			t.Fatalf("unknown category %q", cat)
		}
		v[axis] = float32(w)
		sumSq += w * w
	}
	if sumSq > 1 {
		t.Fatalf("weights exceed unit length: %v", weights)
	}
	// Rest of the mass on the padding axis keeps the vector unit-length, so
	// normalization is a no-op and each weight IS the cosine score.
	v[b.dim-1] = float32(math.Sqrt(1 - sumSq))
	b.target = v
}

func names(ts []tools.Tool) []string {
	out := make([]string, len(ts))
	for i, t := range ts {
		out[i] = t.Name
	}
	return out
}

func TestKeywordHitsJapaneseAndEnglish(t *testing.T) {
	cats := map[string]bool{"audio": true, "timer": true, "weather": true, "app": true}

	cases := []struct {
		utterance string
		want      []string
	}{
		{"音量ちょっと上げて", []string{"audio"}},
		{"set a TIMER for five minutes", []string{"timer"}},
		{"明日の天気どう？", []string{"weather"}},
		{"the dynamic range is wide", nil}, // "mic" must not fire inside "dynamic"
		{"こんにちは", nil},
		{"開いて firefox", []string{"app"}}, // ja keyword
		{"volume and weather", []string{"audio", "weather"}},
	}
	for _, c := range cases {
		got := keywordHits(c.utterance, cats)
		if fmt.Sprint(got) != fmt.Sprint(c.want) {
			t.Errorf("keywordHits(%q) = %v, want %v", c.utterance, got, c.want)
		}
	}
}

func TestKeywordHitsRespectsPresentCategories(t *testing.T) {
	got := keywordHits("天気は？", map[string]bool{"audio": true})
	if len(got) != 0 {
		t.Errorf("expected no hits for absent category, got %v", got)
	}
}

func TestSelectSmallCatalogPassesThrough(t *testing.T) {
	f := New(Config{}, nil)
	all := testTools("audio", "music") // 4 tools, under the threshold
	sel, _ := f.Select(context.Background(), "音量上げて", nil, all)
	if len(sel) != len(all) {
		t.Fatalf("small catalog must pass through, got %d/%d", len(sel), len(all))
	}
}

func TestSelectNoSignalFallsBackToAll(t *testing.T) {
	f := New(Config{}, nil)
	all := testTools("audio", "music", "theme", "wallpaper", "timer", "calendar", "weather")
	sel, reason := f.Select(context.Background(), "こんにちは", nil, all)
	if len(sel) != len(all) {
		t.Fatalf("no keyword + no embedding must return all, got %d/%d (%s)", len(sel), len(all), reason)
	}
}

func TestSelectKeywordOnlyTrims(t *testing.T) {
	f := New(Config{AlwaysInclude: []string{"panel"}}, nil)
	all := testTools("audio", "music", "theme", "wallpaper", "timer", "calendar", "panel")
	sel, _ := f.Select(context.Background(), "音量上げて", nil, all)
	got := names(sel)
	want := []string{"audio_get", "audio_set", "panel_get", "panel_set"}
	if fmt.Sprint(got) != fmt.Sprint(want) {
		t.Fatalf("got %v, want %v", got, want)
	}
}

func TestSelectStickyKeepsCategories(t *testing.T) {
	f := New(Config{}, nil)
	all := testTools("audio", "music", "theme", "wallpaper", "timer", "calendar", "weather")
	sel, _ := f.Select(context.Background(), "音量上げて", []string{"theme"}, all)
	got := names(sel)
	want := []string{"audio_get", "audio_set", "theme_get", "theme_set"}
	if fmt.Sprint(got) != fmt.Sprint(want) {
		t.Fatalf("got %v, want %v", got, want)
	}
}

func TestSelectEmbeddingTrims(t *testing.T) {
	all := testTools("alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta")
	sorted := catsOf(all)
	be := newBasisEmbed(sorted)
	f := New(Config{TopK: 4, MinScore: 0.4}, be.fn)
	f.Warm(context.Background(), all)

	// No keywords exist for these fake categories, so only the embedding layer
	// can pick gamma.
	be.pointAt(t, map[string]float64{"gamma": 1})
	sel, reason := f.Select(context.Background(), "whatever", nil, all)
	got := names(sel)
	want := []string{"gamma_get", "gamma_set"}
	if fmt.Sprint(got) != fmt.Sprint(want) {
		t.Fatalf("got %v, want %v (%s)", got, want, reason)
	}
}

func TestSelectEmbeddingHonorsTopKAndMinScore(t *testing.T) {
	all := testTools("alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta")
	sorted := catsOf(all)
	be := newBasisEmbed(sorted)
	f := New(Config{TopK: 1, MinScore: 0.4}, be.fn)
	f.Warm(context.Background(), all)

	// Two categories above MinScore, but TopK=1 keeps only the stronger.
	be.pointAt(t, map[string]float64{"alpha": 0.8, "beta": 0.55})
	sel, _ := f.Select(context.Background(), "whatever", nil, all)
	got := names(sel)
	want := []string{"alpha_get", "alpha_set"}
	if fmt.Sprint(got) != fmt.Sprint(want) {
		t.Fatalf("got %v, want %v", got, want)
	}

	// Below MinScore everywhere, and no keyword/sticky/always either.
	be.pointAt(t, map[string]float64{"alpha": 0.2})
	sel, reason := f.Select(context.Background(), "whatever", nil, all)
	if len(sel) != len(all) {
		t.Fatalf("expected fallback to all, got %d/%d (%s)", len(sel), len(all), reason)
	}
}

func TestSelectEmbedFailureDegradesToKeywords(t *testing.T) {
	all := testTools("audio", "music", "theme", "wallpaper", "timer", "calendar", "weather")
	sorted := catsOf(all)
	be := newBasisEmbed(sorted)
	f := New(Config{}, be.fn)
	f.Warm(context.Background(), all)

	be.fail = true
	sel, _ := f.Select(context.Background(), "音量上げて", nil, all)
	got := names(sel)
	want := []string{"audio_get", "audio_set"}
	if fmt.Sprint(got) != fmt.Sprint(want) {
		t.Fatalf("got %v, want %v", got, want)
	}
	sel, _ = f.Select(context.Background(), "こんにちは", nil, all)
	if len(sel) != len(all) {
		t.Fatalf("expected all on embed failure without keywords, got %d/%d", len(sel), len(all))
	}
}

func TestSelectAllCategoriesSelectedReturnsAll(t *testing.T) {
	f := New(Config{AlwaysInclude: []string{"audio", "music"}}, nil)
	all := testTools("audio", "music")
	// Under min size anyway, but exercise the covers-all branch with a
	// bigger always-include list.
	f2 := New(Config{AlwaysInclude: []string{"a", "b", "c", "d", "e", "f", "g"}}, nil)
	all2 := testTools("a", "b", "c", "d", "e", "f", "g")
	sel, _ := f2.Select(context.Background(), "音量", nil, all2)
	if len(sel) != len(all2) {
		t.Fatalf("covers-all selection must return the full list")
	}
	_ = f
	_ = all
}

func TestWarmFailureThenSelectStillWorks(t *testing.T) {
	all := testTools("audio", "music", "theme", "wallpaper", "timer", "calendar", "weather")
	be := newBasisEmbed(catsOf(all))
	be.fail = true
	f := New(Config{}, be.fn)
	f.Warm(context.Background(), all)

	sel, _ := f.Select(context.Background(), "音量上げて", nil, all)
	got := names(sel)
	want := []string{"audio_get", "audio_set"}
	if fmt.Sprint(got) != fmt.Sprint(want) {
		t.Fatalf("got %v, want %v", got, want)
	}
}

func TestContainsWordUTF8Boundary(t *testing.T) {
	// The boundary byte before "open" is リ's trailing UTF-8 byte (0xAA); a
	// byte-wise check mis-reads it as a letter and drops the match.
	if !containsWord("アプリopen", "open") {
		t.Error(`containsWord("アプリopen","open") should be true`)
	}
	if !containsWord("東京はrain", "rain") {
		t.Error(`containsWord("東京はrain","rain") should be true`)
	}
	if containsWord("dynamic", "mic") {
		t.Error(`"mic" must not match inside "dynamic"`)
	}
	if containsWord("wallpaper", "app") {
		t.Error(`"app" must not match inside "wallpaper"`)
	}
}

func TestSelectKeywordOnlyKeepsBlindCategories(t *testing.T) {
	// "github" stands in for an MCP server: no keyword dictionary entry, so a
	// keyword hit for audio must not drop it.
	f := New(Config{}, nil)
	all := testTools("audio", "music", "theme", "wallpaper", "timer", "calendar", "github")
	sel, reason := f.Select(context.Background(), "音量上げて", nil, all)
	got := map[string]bool{}
	for _, c := range catsOf(sel) {
		got[c] = true
	}
	if !got["audio"] {
		t.Errorf("keyword-hit category audio missing: %s", reason)
	}
	if !got["github"] {
		t.Errorf("keyword-blind category github must be kept in keyword-only mode: %s", reason)
	}
	if got["music"] || got["theme"] {
		t.Errorf("unrelated built-in categories should be trimmed: %v", got)
	}
}

func TestNilFilterPassesThrough(t *testing.T) {
	var f *Filter
	all := testTools("audio", "music", "theme", "wallpaper", "timer", "calendar", "weather")
	sel, _ := f.Select(context.Background(), "音量上げて", nil, all)
	if len(sel) != len(all) {
		t.Fatalf("nil filter must pass everything through")
	}
}
