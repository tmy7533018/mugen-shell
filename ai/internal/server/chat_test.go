package server

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"

	"github.com/tmy7533018/mugen-ai/internal/config"
	"github.com/tmy7533018/mugen-ai/internal/history"
	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/store"
	"github.com/tmy7533018/mugen-ai/internal/tools"
)

// Streams the given chunks, then either fails or completes. Named "ollama" so
// the local-provider branches behave as they do in practice.
type scriptedProvider struct {
	chunks    []string
	toolCalls []provider.ToolCall
	failWith  error
	turns     int
}

func (p *scriptedProvider) Name() string { return "ollama" }

func (p *scriptedProvider) Ping(context.Context) bool { return true }

func (p *scriptedProvider) Models(context.Context) ([]string, error) {
	return []string{"test-model"}, nil
}

func (p *scriptedProvider) Chat(_ context.Context, _ string, _ []provider.Message,
	_ provider.ChatOptions, fn func(provider.ChatChunk) error) error {
	p.turns++
	for _, c := range p.chunks {
		if err := fn(provider.ChatChunk{Content: c}); err != nil {
			return err
		}
	}
	if p.failWith != nil {
		return p.failWith
	}
	// Tool calls ride the done chunk, matching every real provider.
	return fn(provider.ChatChunk{Done: true, ToolCalls: p.toolCalls})
}

func newChatServer(t *testing.T, p provider.Provider) (*Server, *store.Store) {
	t.Helper()
	st, err := store.Open(filepath.Join(t.TempDir(), "chat.db"))
	if err != nil {
		t.Fatalf("store: %v", err)
	}
	t.Cleanup(func() { st.Close() })

	hist, err := history.New(st, "test system prompt", 0)
	if err != nil {
		t.Fatalf("history: %v", err)
	}
	// DesktopState off: on it would shell out to `qs` from the test.
	s := New(provider.NewRegistry("test-model", p), hist, st,
		tools.New("", "", nil, nil, nil), nil, config.Context{})
	return s, st
}

func postChat(t *testing.T, s *Server, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/chat", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	s.handleChat(rec, req)
	return rec
}

func lastStored(t *testing.T, st *store.Store, convID int64) store.Message {
	t.Helper()
	msgs, err := st.ListMessages(convID)
	if err != nil {
		t.Fatalf("list messages: %v", err)
	}
	if len(msgs) == 0 {
		t.Fatal("conversation has no messages")
	}
	return msgs[len(msgs)-1]
}

func TestChatPersistsACompleteReplyUnmarked(t *testing.T) {
	s, st := newChatServer(t, &scriptedProvider{chunks: []string{"all ", "done"}})

	rec := postChat(t, s, `{"message":"hi","conversation_id":0}`)
	if !strings.Contains(rec.Body.String(), `"content":"all "`) {
		t.Fatalf("reply did not stream:\n%s", rec.Body.String())
	}

	last := lastStored(t, st, s.history.ConvID())
	if last.Role != "assistant" || last.Content != "all done" {
		t.Fatalf("stored %q as %q, want the plain reply", last.Content, last.Role)
	}
}

// The user watched a partial answer arrive, so it stays — but it must not read
// back as the whole answer.
func TestChatMarksAPartialReplyThatFailedMidStream(t *testing.T) {
	s, st := newChatServer(t, &scriptedProvider{
		chunks:   []string{"half an ans"},
		failWith: errors.New("ollama stopped sending output for 1m0s"),
	})

	rec := postChat(t, s, `{"message":"hi","conversation_id":0}`)
	if !strings.Contains(rec.Body.String(), "stopped sending output") {
		t.Fatalf("error was not reported to the client:\n%s", rec.Body.String())
	}

	last := lastStored(t, st, s.history.ConvID())
	if !strings.HasPrefix(last.Content, "half an ans") {
		t.Fatalf("partial text was lost: %q", last.Content)
	}
	if !strings.Contains(last.Content, "[interrupted]") {
		t.Fatalf("partial reply stored without a marker: %q", last.Content)
	}
}

// Nothing streamed and no tool ran, so the turn left no trace: the user message
// goes too, rather than sitting there unanswered forever.
func TestChatDropsTheUserMessageWhenNothingHappened(t *testing.T) {
	s, st := newChatServer(t, &scriptedProvider{failWith: errors.New("ollama unreachable")})

	postChat(t, s, `{"message":"hi","conversation_id":0}`)

	msgs, err := st.ListMessages(s.history.ConvID())
	if err != nil {
		t.Fatalf("list messages: %v", err)
	}
	for _, m := range msgs {
		if m.Role == "user" || m.Role == "assistant" {
			t.Fatalf("expected an empty exchange, found %s: %q", m.Role, m.Content)
		}
	}
}

// A tool fired, so the turn had side effects even with no text to show. History
// must record that rather than end on a user message with no reply.
func TestChatMarksAToolOnlyTurnThatFailed(t *testing.T) {
	p := &scriptedProvider{
		toolCalls: []provider.ToolCall{{ID: "1", Name: "theme_get", Arguments: map[string]any{}}},
		failWith:  nil,
	}
	s, st := newChatServer(t, p)
	// The tool call comes back every iteration, so the loop runs out of turns
	// without ever producing text.
	rec := postChat(t, s, `{"message":"hi","conversation_id":0}`)
	if !strings.Contains(rec.Body.String(), "max tool iterations exceeded") {
		t.Fatalf("expected the iteration cap to end the turn:\n%s", rec.Body.String())
	}

	last := lastStored(t, st, s.history.ConvID())
	if last.Role != "assistant" || last.Content != "[interrupted]" {
		t.Fatalf("stored %q as %q, want a bare marker", last.Content, last.Role)
	}
}
