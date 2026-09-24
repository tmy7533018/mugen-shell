package server

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"

	"github.com/tmy7533018/mugen-ai/internal/config"
	"github.com/tmy7533018/mugen-ai/internal/history"
	"github.com/tmy7533018/mugen-ai/internal/mcp"
	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/store"
	"github.com/tmy7533018/mugen-ai/internal/tools"
)

func newFakeMCPServer(t *testing.T, callResult, callErrMessage string) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var req struct {
			ID     *int64          `json:"id"`
			Method string          `json:"method"`
			Params json.RawMessage `json:"params"`
		}
		_ = json.Unmarshal(body, &req)
		if req.ID == nil {
			w.WriteHeader(http.StatusAccepted)
			return
		}
		resp := map[string]any{"jsonrpc": "2.0", "id": *req.ID}
		switch req.Method {
		case "initialize":
			resp["result"] = map[string]any{
				"protocolVersion": "2025-06-18",
				"capabilities":    map[string]any{},
				"serverInfo":      map[string]any{"name": "fake", "version": "1"},
			}
		case "tools/list":
			resp["result"] = map[string]any{"tools": []map[string]any{{
				"name":        "huge",
				"description": "returns a huge or failing result",
				"inputSchema": map[string]any{"type": "object", "properties": map[string]any{}},
				"annotations": map[string]any{"readOnlyHint": true},
			}}}
		case "tools/call":
			if callErrMessage != "" {
				resp["error"] = map[string]any{"code": -32000, "message": callErrMessage}
			} else {
				resp["result"] = map[string]any{
					"content": []map[string]any{{"type": "text", "text": callResult}},
				}
			}
		default:
			resp["result"] = map[string]any{}
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
}

// Locked: handleChat fires an async generateTitle through the same provider after the turn.
type capturingProvider struct {
	mu   sync.Mutex
	turn int
	// Only the two real turns; generateTitle's own call is excluded.
	calls [][]provider.Message
}

func (p *capturingProvider) Name() string              { return "ollama" }
func (p *capturingProvider) Ping(context.Context) bool { return true }
func (p *capturingProvider) Models(context.Context) ([]string, error) {
	return []string{"test-model"}, nil
}

func (p *capturingProvider) Chat(_ context.Context, _ string, msgs []provider.Message,
	_ provider.ChatOptions, fn func(provider.ChatChunk) error) error {
	p.mu.Lock()
	p.turn++
	turn := p.turn
	if turn <= 2 {
		p.calls = append(p.calls, msgs)
	}
	p.mu.Unlock()
	if turn == 1 {
		return fn(provider.ChatChunk{Done: true, ToolCalls: []provider.ToolCall{
			{ID: "1", Name: "fake__huge", Arguments: map[string]any{}},
		}})
	}
	return fn(provider.ChatChunk{Content: "ok", Done: true})
}

func (p *capturingProvider) toolMessages() []provider.Message {
	p.mu.Lock()
	defer p.mu.Unlock()
	var out []provider.Message
	for _, msgs := range p.calls {
		for _, m := range msgs {
			if m.Role == "tool" {
				out = append(out, m)
			}
		}
	}
	return out
}

func newMCPBoundServer(t *testing.T, p provider.Provider, ts *httptest.Server) *Server {
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

	mgr := mcp.Connect(context.Background(), map[string]mcp.ServerConfig{"fake": {URL: ts.URL}})
	t.Cleanup(mgr.Close)

	toolReg := tools.New("", nil, nil, nil)
	// Trusted, so the readOnlyHint above skips a confirmation dialog nothing here answers.
	toolReg.AttachMCP(mgr, map[string]bool{"fake": true})

	return New(provider.NewRegistry("test-model", p), hist, st, toolReg, mgr, config.Context{})
}

func TestChatBoundsAHugeMCPResultForTheProvider(t *testing.T) {
	huge := strings.Repeat("a", 4<<20)
	ts := newFakeMCPServer(t, huge, "")
	defer ts.Close()

	p := &capturingProvider{}
	s := newMCPBoundServer(t, p, ts)

	rec := postChat(t, s, `{"message":"hi","conversation_id":0}`)
	if !strings.Contains(rec.Body.String(), "[truncated:") {
		t.Fatalf("SSE tool_result was not bounded:\n%s", rec.Body.String())
	}
	if strings.Contains(rec.Body.String(), strings.Repeat("a", 4<<20)) {
		t.Fatal("SSE stream carried the full 4 MiB result, want it bounded")
	}

	toolMsgs := p.toolMessages()
	if len(toolMsgs) != 1 {
		t.Fatalf("found %d tool-role message(s) across the turn, want 1", len(toolMsgs))
	}
	m := toolMsgs[0]
	if len(m.Content) > tools.MaxLLMResultBytes+100 {
		t.Fatalf("tool message reached the provider at %d bytes, want it bounded near %d",
			len(m.Content), tools.MaxLLMResultBytes)
	}
	wantMarker := "\n[truncated: " + strconv.Itoa(len(huge)-tools.MaxLLMResultBytes) + " of " + strconv.Itoa(len(huge)) + " bytes omitted]"
	if !strings.HasSuffix(m.Content, wantMarker) {
		t.Fatalf("tool message suffix = %q, want %q", m.Content[max(0, len(m.Content)-len(wantMarker)):], wantMarker)
	}
}

func TestChatBoundsAHugeMCPErrorForTheProvider(t *testing.T) {
	hugeErr := strings.Repeat("e", 4<<20)
	ts := newFakeMCPServer(t, "", hugeErr)
	defer ts.Close()

	p := &capturingProvider{}
	s := newMCPBoundServer(t, p, ts)

	rec := postChat(t, s, `{"message":"hi","conversation_id":0}`)
	if !strings.Contains(rec.Body.String(), "[truncated:") {
		t.Fatalf("SSE tool_result was not bounded:\n%s", rec.Body.String())
	}

	toolMsgs := p.toolMessages()
	if len(toolMsgs) != 1 {
		t.Fatalf("found %d tool-role message(s) across the turn, want 1", len(toolMsgs))
	}
	m := toolMsgs[0]
	if len(m.Content) > tools.MaxLLMResultBytes+100 {
		t.Fatalf("tool message reached the provider at %d bytes, want it bounded near %d",
			len(m.Content), tools.MaxLLMResultBytes)
	}
	if !strings.HasPrefix(m.Content, "error: fake__huge failed: mcp error -32000: ") {
		t.Fatalf("tool message = %q, want it to start with the mcp error prefix", m.Content[:min(60, len(m.Content))])
	}
}
