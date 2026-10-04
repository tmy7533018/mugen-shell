package provider

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
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

type ollamaSent struct {
	Think bool  `json:"think"`
	Tools []any `json:"tools"`
}

// Rejects the way Ollama 0.34's ChatHandler does: thinking is checked before tools.
func stubOllamaCapabilities(t *testing.T, thinking, tools bool) (*httptest.Server, func() []ollamaSent) {
	t.Helper()
	var mu sync.Mutex
	var sent []ollamaSent
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var req ollamaSent
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Errorf("decode request: %v", err)
		}
		mu.Lock()
		sent = append(sent, req)
		mu.Unlock()
		switch {
		case req.Think && !thinking:
			w.WriteHeader(http.StatusBadRequest)
			io.WriteString(w, `{"error":"\"stub\" does not support thinking"}`)
		case len(req.Tools) > 0 && !tools:
			w.WriteHeader(http.StatusBadRequest)
			io.WriteString(w, `{"error":"stub does not support tools"}`)
		default:
			io.WriteString(w, `{"message":{"content":"ok"},"done":false}`+"\n")
			io.WriteString(w, `{"message":{"content":""},"done":true}`+"\n")
		}
	}))
	return srv, func() []ollamaSent {
		mu.Lock()
		defer mu.Unlock()
		return append([]ollamaSent(nil), sent...)
	}
}

func TestOllamaRetriesWithoutThinkingTheModelLacks(t *testing.T) {
	tool := []Tool{{Name: "audio_get_volume", Parameters: map[string]any{"type": "object"}}}
	cases := []struct {
		name      string
		opts      ChatOptions
		thinking  bool
		tools     bool
		wantThink []bool
		wantTools []int
	}{
		{
			name:      "thinking rejected",
			opts:      ChatOptions{Thinking: true},
			wantThink: []bool{true, false},
			wantTools: []int{0, 0},
		},
		{
			name:      "thinking then tools rejected",
			opts:      ChatOptions{Thinking: true, Tools: tool},
			wantThink: []bool{true, false, false},
			wantTools: []int{1, 1, 0},
		},
		{
			name:      "thinking model keeps think",
			opts:      ChatOptions{Thinking: true, Tools: tool},
			thinking:  true,
			tools:     true,
			wantThink: []bool{true},
			wantTools: []int{1},
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			srv, sent := stubOllamaCapabilities(t, tc.thinking, tc.tools)
			defer srv.Close()

			var got strings.Builder
			err := testOllama(srv.URL).Chat(context.Background(), "stub",
				[]Message{{Role: "user", Content: "hi"}}, tc.opts,
				func(c ChatChunk) error {
					got.WriteString(c.Content)
					return nil
				})
			if err != nil {
				t.Fatalf("chat: %v", err)
			}
			if got.String() != "ok" {
				t.Errorf("content = %q", got.String())
			}
			reqs := sent()
			if len(reqs) != len(tc.wantThink) {
				t.Fatalf("sent %d requests %+v, want %d", len(reqs), reqs, len(tc.wantThink))
			}
			for i, r := range reqs {
				if r.Think != tc.wantThink[i] || len(r.Tools) != tc.wantTools[i] {
					t.Errorf("request %d = think:%v tools:%d, want think:%v tools:%d",
						i, r.Think, len(r.Tools), tc.wantThink[i], tc.wantTools[i])
				}
			}
		})
	}
}

// A thinking rejection with think already off is not ours to retry; it must surface, not loop.
func TestOllamaThinkingRejectionWithoutThinkSurfaces(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		io.WriteString(w, `{"error":"\"stub\" does not support thinking"}`)
	}))
	defer srv.Close()

	err := testOllama(srv.URL).Chat(context.Background(), "stub",
		[]Message{{Role: "user", Content: "hi"}}, ChatOptions{},
		func(ChatChunk) error { return nil })
	if err == nil || !strings.Contains(err.Error(), "does not support thinking") {
		t.Fatalf("err = %v", err)
	}
}
