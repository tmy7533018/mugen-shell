package provider

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func stubOllamaThinking(t *testing.T) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/x-ndjson")
		flusher := w.(http.Flusher)
		for _, line := range []string{
			`{"message":{"thinking":"weigh it "},"done":false}`,
			`{"message":{"thinking":"carefully"},"done":false}`,
			`{"message":{"content":"54"},"done":false}`,
			`{"message":{"content":""},"done":true}`,
		} {
			io.WriteString(w, line+"\n")
			flusher.Flush()
		}
	}))
}

// think:true was already sent, but nothing read the channel back, so the switch only cost time.
func TestOllamaThinkingIsReadBack(t *testing.T) {
	srv := stubOllamaThinking(t)
	defer srv.Close()

	var reasoning strings.Builder
	var final ChatChunk
	err := testOllama(srv.URL).Chat(context.Background(), "stub",
		[]Message{{Role: "user", Content: "what is the volume"}},
		ChatOptions{Thinking: true},
		func(c ChatChunk) error {
			reasoning.WriteString(c.ThinkingDelta)
			if c.Done {
				final = c
			}
			return nil
		})
	if err != nil {
		t.Fatalf("chat: %v", err)
	}

	if reasoning.String() != "weigh it carefully" {
		t.Errorf("streamed reasoning = %q", reasoning.String())
	}
	if final.Thinking != "weigh it carefully" {
		t.Errorf("final chunk reasoning = %q", final.Thinking)
	}
}
