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

// testTools builds two dummy tools per category — enough to clear
// minToolsToFilter with a handful of categories.
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

// basisEmbed returns unit basis vectors: Warm gets one axis per profile (in
// the sorted-category order Warm uses), and utterances embed to the vector
// configured in target at call time.
type basisEmbed struct {
	axes   map[string]int // category → axis
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
		// Warm profiles start with the category name on the first line;
		// utterances use the preset target vector.
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
		{"こんにちは", nil},                     // chat-only
		{"開いて firefox", []string{"app"}},   // ja keyword
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
	// weather keyword in the utterance, but no weather category registered.
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
	f := New(Config{}, nil) // no embedder
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

	// Utterance points squarely at gamma; no keywords exist for these fake
	// categories, so only the embedding layer can pick it.
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

	// Below MinScore everywhere → embedding returns no category; with no
	// keyword/sticky/always either, Select must fall back to all.
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
	// Keyword still hits → trimmed selection without embedding.
	sel, _ := f.Select(context.Background(), "音量上げて", nil, all)
	got := names(sel)
	want := []string{"audio_get", "audio_set"}
	if fmt.Sprint(got) != fmt.Sprint(want) {
		t.Fatalf("got %v, want %v", got, want)
	}
	// No keyword → all.
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
	f.Warm(context.Background(), all) // fails, sets cooldown

	sel, _ := f.Select(context.Background(), "音量上げて", nil, all)
	got := names(sel)
	want := []string{"audio_get", "audio_set"}
	if fmt.Sprint(got) != fmt.Sprint(want) {
		t.Fatalf("got %v, want %v", got, want)
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
