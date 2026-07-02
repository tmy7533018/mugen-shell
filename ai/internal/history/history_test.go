package history

import (
	"testing"

	"github.com/tmy7533018/mugen-ai/internal/provider"
)

func TestTruncateKeepsUserLeading(t *testing.T) {
	// A tiny token budget forces truncation to drop into the middle of an
	// exchange; the survivor list must still open with a user message.
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
	// Even with the token cap off, a conversation that happens to start with
	// an assistant message (e.g. loaded mid-stream) must be realigned.
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
