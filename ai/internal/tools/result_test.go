package tools

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"testing"
)

func TestForLLM(t *testing.T) {
	tests := []struct {
		name string
		in   string
	}{
		{"empty", ""},
		{"well under the cap", "hello"},
		{"exactly at the cap", strings.Repeat("a", MaxLLMResultBytes)},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := ForLLM(tc.in); got != tc.in {
				t.Fatalf("ForLLM(%d bytes) changed a result within the cap", len(tc.in))
			}
		})
	}

	t.Run("over the cap, ASCII", func(t *testing.T) {
		in := strings.Repeat("a", MaxLLMResultBytes+10)
		got := ForLLM(in)
		if len(got) <= MaxLLMResultBytes {
			t.Fatalf("len(got) = %d, want it to still carry the marker past the cap", len(got))
		}
		if !strings.HasPrefix(got, strings.Repeat("a", MaxLLMResultBytes)) {
			t.Fatalf("kept prefix does not match the first %d bytes of input", MaxLLMResultBytes)
		}
		want := "\n[truncated: 10 of " + strconv.Itoa(len(in)) + " bytes omitted]"
		if !strings.HasSuffix(got, want) {
			t.Fatalf("got suffix %q, want %q", got[len(got)-len(want):], want)
		}
		if strings.Contains(got, "…") {
			t.Fatalf("got %q, want no ellipsis", got)
		}
	})

	t.Run("cut backs off to a rune boundary", func(t *testing.T) {
		// A 3-byte rune (日) straddling the cap must not be split mid-rune.
		in := strings.Repeat("a", MaxLLMResultBytes-1) + "日本語"
		got := ForLLM(in)
		kept, _, ok := strings.Cut(got, "\n[truncated:")
		if !ok {
			t.Fatalf("no truncation marker in %q", got)
		}
		if !strings.HasSuffix(kept, "a") {
			t.Fatalf("kept text %q, want it to back off before the multi-byte rune", kept)
		}
		omitted := len(in) - len(kept)
		wantMarker := "\n[truncated: " + strconv.Itoa(omitted) + " of " + strconv.Itoa(len(in)) + " bytes omitted]"
		if !strings.HasSuffix(got, wantMarker) {
			t.Fatalf("got %q, want it to end with %q", got, wantMarker)
		}
	})

	t.Run("a distant rune start is not backed off to", func(t *testing.T) {
		in := "a" + strings.Repeat("\x80", MaxLLMResultBytes+10)
		kept, _, _ := strings.Cut(ForLLM(in), "\n[truncated:")
		if len(kept) != MaxLLMResultBytes {
			t.Fatalf("len(kept) = %d, want %d", len(kept), MaxLLMResultBytes)
		}
	})

	t.Run("invalid UTF-8 still keeps a full cap's worth", func(t *testing.T) {
		// Every byte is a continuation byte, so no rune start exists to back off to.
		in := strings.Repeat("\x80", MaxLLMResultBytes+10)
		got := ForLLM(in)
		kept, _, ok := strings.Cut(got, "\n[truncated:")
		if !ok {
			t.Fatalf("no truncation marker in %q", got)
		}
		if len(kept) != MaxLLMResultBytes {
			t.Fatalf("len(kept) = %d, want the full %d-byte cap kept", len(kept), MaxLLMResultBytes)
		}
		want := "\n[truncated: 10 of " + strconv.Itoa(len(in)) + " bytes omitted]"
		if !strings.HasSuffix(got, want) {
			t.Fatalf("got suffix %q, want %q", got[len(got)-len(want):], want)
		}
	})
}

func TestResultPayload(t *testing.T) {
	t.Run("success passes through", func(t *testing.T) {
		if got := ResultPayload("30", nil); got != "30" {
			t.Fatalf("got %q, want 30", got)
		}
	})

	t.Run("error with no output has nothing to append", func(t *testing.T) {
		got := ResultPayload("", errors.New("boom"))
		want := "error: boom"
		if got != want {
			t.Fatalf("got %q, want %q", got, want)
		}
	})

	t.Run("error not already carrying the output appends it once", func(t *testing.T) {
		got := ResultPayload("stdout text", errors.New("exit status 1"))
		want := "error: exit status 1 (output: stdout text)"
		if got != want {
			t.Fatalf("got %q, want %q", got, want)
		}
	})

	t.Run("error already embedding the output is not duplicated", func(t *testing.T) {
		callErr := errors.New(`calendar_add failed: exit status 1 (output: {"error":"bad date"})`)
		got := ResultPayload(`{"error":"bad date"}`, callErr)
		want := "error: " + callErr.Error()
		if got != want {
			t.Fatalf("got %q, want %q (no second (output: ...))", got, want)
		}
		if strings.Count(got, "(output:") != 1 {
			t.Fatalf("got %q, want exactly one (output: ...) block", got)
		}
	})

	t.Run("output that is a substring of the error text is still appended", func(t *testing.T) {
		got := ResultPayload("on", errors.New("connection failed"))
		want := "error: connection failed (output: on)"
		if got != want {
			t.Fatalf("got %q, want %q (bare substring match must not suppress it)", got, want)
		}
	})

	t.Run("a huge error message is bounded", func(t *testing.T) {
		msg := strings.Repeat("x", 4<<20)
		got := ResultPayload("", errors.New(msg))
		if len(got) > MaxLLMResultBytes+100 {
			t.Fatalf("len(got) = %d, want it bounded near the %d-byte cap", len(got), MaxLLMResultBytes)
		}
		if !strings.Contains(got, "[truncated:") {
			t.Fatalf("got %q, want a truncation marker", got)
		}
	})
}

func TestCallStaysUnboundedForNonChatCallers(t *testing.T) {
	r, fr, _ := newTestRegistry(t, nil, nil)
	huge := `{"events":[` + strings.Repeat(`{"id":"e","date":"2026-09-24","time":"09:00","title":"x"},`, 3000) + `{"id":"last","date":"2026-09-24","time":"09:00","title":"x"}]}`
	if len(huge) <= MaxLLMResultBytes {
		t.Fatalf("test setup: huge (%d bytes) must exceed the cap (%d)", len(huge), MaxLLMResultBytes)
	}
	fr.result = huge

	out, err := r.Call(context.Background(), "calendar_list_range", map[string]any{
		"start": "2026-01-01", "end": "2026-12-31",
	})
	if err != nil {
		t.Fatalf("Call: %v", err)
	}
	if out != huge {
		t.Fatalf("Call bounded its result (%d bytes, want %d); ForLLM belongs in the chat loops, not Call", len(out), len(huge))
	}
}
