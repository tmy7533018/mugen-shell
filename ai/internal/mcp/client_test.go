package mcp

import (
	"context"
	"encoding/json"
	"io"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"
)

// An in-process MCP server for tests. handler returning ok=false models a
// notification (no reply). out is buffered because the client writes and its
// readLoop reads on separate goroutines.
type scriptedTransport struct {
	handler func(req rpcMessage) (rpcMessage, bool)
	out     chan []byte
	done    chan struct{}

	mu   sync.Mutex
	sent []rpcMessage
}

func newScriptedTransport(handler func(rpcMessage) (rpcMessage, bool)) *scriptedTransport {
	return &scriptedTransport{
		handler: handler,
		out:     make(chan []byte, 16),
		done:    make(chan struct{}),
	}
}

func (s *scriptedTransport) send(data []byte) error {
	var req rpcMessage
	if err := json.Unmarshal(data, &req); err != nil {
		return err
	}
	s.mu.Lock()
	s.sent = append(s.sent, req)
	s.mu.Unlock()

	resp, ok := s.handler(req)
	if !ok {
		return nil
	}
	resp.JSONRPC = "2.0"
	resp.ID = req.ID
	b, err := json.Marshal(resp)
	if err != nil {
		return err
	}
	s.out <- b
	return nil
}

func (s *scriptedTransport) recv() ([]byte, error) {
	select {
	case b := <-s.out:
		return b, nil
	case <-s.done:
		return nil, io.EOF
	}
}

func (s *scriptedTransport) close() error {
	select {
	case <-s.done:
	default:
		close(s.done)
	}
	return nil
}

func (s *scriptedTransport) sentMethods() []string {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]string, len(s.sent))
	for i, m := range s.sent {
		out[i] = m.Method
	}
	return out
}

func resultMsg(v any) rpcMessage {
	b, _ := json.Marshal(v)
	return rpcMessage{Result: b}
}

func testCtx(t *testing.T) context.Context {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	t.Cleanup(cancel)
	return ctx
}

func TestClientInitialize(t *testing.T) {
	tr := newScriptedTransport(func(req rpcMessage) (rpcMessage, bool) {
		if req.Method == "initialize" {
			return resultMsg(map[string]any{"protocolVersion": protocolVersion}), true
		}
		return rpcMessage{}, false // notifications/initialized expects no reply
	})
	c := newClient("test", tr)
	defer c.Close()

	if err := c.Initialize(testCtx(t)); err != nil {
		t.Fatalf("Initialize: %v", err)
	}
	got := tr.sentMethods()
	want := []string{"initialize", "notifications/initialized"}
	if !slices.Equal(got, want) {
		t.Fatalf("sent %v, want %v", got, want)
	}
}

func TestClientListToolsPagination(t *testing.T) {
	page := 0
	tr := newScriptedTransport(func(req rpcMessage) (rpcMessage, bool) {
		if req.Method != "tools/list" {
			return rpcMessage{}, false
		}
		page++
		if page == 1 {
			return resultMsg(map[string]any{
				"tools": []map[string]any{
					{"name": "alpha", "description": "first",
						"annotations": map[string]any{"readOnlyHint": true}},
				},
				"nextCursor": "p2",
			}), true
		}
		return resultMsg(map[string]any{
			"tools": []map[string]any{
				{"name": "beta", "description": "second",
					"inputSchema": map[string]any{"type": "object", "properties": map[string]any{
						"q": map[string]any{"type": "string"},
					}}},
			},
		}), true
	})
	c := newClient("test", tr)
	defer c.Close()

	got, err := c.ListTools(testCtx(t))
	if err != nil {
		t.Fatalf("ListTools: %v", err)
	}
	if len(got) != 2 || got[0].Name != "alpha" || got[1].Name != "beta" {
		t.Fatalf("tools = %+v", got)
	}
	if !got[0].ReadOnly || got[1].ReadOnly {
		t.Fatalf("readonly hints wrong: %v %v", got[0].ReadOnly, got[1].ReadOnly)
	}
	// Providers need a valid parameter spec even when the server omits one.
	if got[0].InputSchema["type"] != "object" {
		t.Fatalf("default schema not applied: %v", got[0].InputSchema)
	}
}

func TestClientCallTool(t *testing.T) {
	tr := newScriptedTransport(func(req rpcMessage) (rpcMessage, bool) {
		if req.Method != "tools/call" {
			return rpcMessage{}, false
		}
		var p struct {
			Name string `json:"name"`
		}
		_ = json.Unmarshal(req.Params, &p)
		if p.Name == "boom" {
			return resultMsg(map[string]any{
				"content": []map[string]any{{"type": "text", "text": "it failed"}},
				"isError": true,
			}), true
		}
		return resultMsg(map[string]any{
			"content": []map[string]any{
				{"type": "text", "text": "line one"},
				{"type": "image"},
				{"type": "text", "text": "line two"},
			},
		}), true
	})
	c := newClient("test", tr)
	defer c.Close()
	ctx := testCtx(t)

	out, err := c.CallTool(ctx, "ok", nil)
	if err != nil {
		t.Fatalf("CallTool: %v", err)
	}
	if want := "line one\n[non-text content: image]\nline two"; out != want {
		t.Fatalf("got %q, want %q", out, want)
	}

	out, err = c.CallTool(ctx, "boom", nil)
	if err != nil {
		t.Fatalf("CallTool(boom): %v", err)
	}
	if !strings.HasPrefix(out, "error: ") {
		t.Fatalf("isError result should be error-prefixed, got %q", out)
	}
}

func TestResolveDestructive(t *testing.T) {
	yes, no := true, false
	cases := []struct {
		desc        string
		toolName    string
		readOnly    bool
		destructive *bool
		want        bool
	}{
		{"readOnlyHint wins over name", "delete_thing", true, nil, false},
		{"readOnlyHint wins over destructiveHint", "x", true, &yes, false},
		{"explicit destructiveHint true", "search_x", false, &yes, true},
		{"explicit destructiveHint false", "create_x", false, &no, false},
		{"unannotated read verb", "read_graph", false, nil, false},
		{"unannotated search verb", "search_nodes", false, nil, false},
		{"unannotated camelCase read", "getUserProfile", false, nil, false},
		{"unannotated write verb", "create_entities", false, nil, true},
		{"unannotated delete verb", "delete_entities", false, nil, true},
		{"unannotated ambiguous name", "open_nodes", false, nil, true},
		{"reader is not the read verb", "reader_load", false, nil, true},
	}
	for _, tc := range cases {
		if got := resolveDestructive(tc.toolName, tc.readOnly, tc.destructive); got != tc.want {
			t.Errorf("%s: resolveDestructive(%q, %v, %v) = %v, want %v",
				tc.desc, tc.toolName, tc.readOnly, tc.destructive, got, tc.want)
		}
	}
}

func TestClientConnectionLost(t *testing.T) {
	tr := newScriptedTransport(func(rpcMessage) (rpcMessage, bool) {
		return rpcMessage{}, false // never answers
	})
	c := newClient("test", tr)

	// Dropping the transport mid-call must unblock the request, not hang.
	go func() {
		time.Sleep(10 * time.Millisecond)
		c.Close()
	}()
	if _, err := c.call(testCtx(t), "tools/list", nil); err == nil {
		t.Fatal("expected error after transport closed")
	}
}
