package history

import (
	"testing"

	"github.com/tmy7533018/mugen-ai/internal/provider"
)

func TestTruncateKeepsUserLeading(t *testing.T) {
	// A tiny budget forces the drop to land mid-exchange.
	h := &History{maxTokens: 20}
	big := ""
	for i := 0; i < 40; i++ {
		big += "word "
	}
	h.messages = []provider.Message{
		{Role: "user", Content: big},
		{Role: "assistant", Content: big},
		{Role: "user", Content: big},
		{Role: "assistant", Content: "ok"},
	}
	h.truncateLocked()

	if len(h.messages) == 0 {
		t.Fatal("truncation emptied the conversation")
	}
	if h.messages[0].Role != "user" {
		t.Fatalf("first message must be user, got %q", h.messages[0].Role)
	}
}

func TestTruncateNoTokenCapLeavesUserLead(t *testing.T) {
	h := &History{maxTokens: 0}
	h.messages = []provider.Message{
		{Role: "assistant", Content: "stray"},
		{Role: "user", Content: "hi"},
		{Role: "assistant", Content: "hello"},
	}
	h.truncateLocked()

	if h.messages[0].Role != "user" {
		t.Fatalf("first message must be user, got %q", h.messages[0].Role)
	}
}
