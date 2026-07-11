package mcpserver

import (
	"context"
	"encoding/json"
	"errors"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/tmy7533018/mugen-ai/internal/tools"
)

type fakeSource struct {
	tools  []tools.Tool
	called []string
	result string
	err    error
}

func (f *fakeSource) ExposedTools(_ bool, _ []string) []tools.Tool { return f.tools }

func (f *fakeSource) Call(_ context.Context, name string, _ map[string]any) (string, error) {
	f.called = append(f.called, name)
	return f.result, f.err
}

func newTestHandler(result string, err error) (*Handler, *fakeSource) {
	src := &fakeSource{
		tools: []tools.Tool{
			{Name: "theme_get", Description: "Read theme.", Parameters: map[string]any{"type": "object"}},
		},
		result: result,
		err:    err,
	}
	return New(src, true, nil, "1"), src
}

func handle(t *testing.T, h *Handler, msg string) map[string]any {
	t.Helper()
	raw := h.HandleMessage(context.Background(), []byte(msg))
	if raw == nil {
		t.Fatalf("expected a response for %s", msg)
	}
	var out map[string]any
	if err := json.Unmarshal(raw, &out); err != nil {
		t.Fatalf("bad response JSON: %v", err)
	}
	return out
}

func TestInitializeEchoesClientVersion(t *testing.T) {
	h, _ := newTestHandler("", nil)
	resp := handle(t, h, `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"x","version":"1"}}}`)
	result := resp["result"].(map[string]any)
	if result["protocolVersion"] != "2025-03-26" {
		t.Errorf("expected echoed protocol version, got %v", result["protocolVersion"])
	}
	if result["serverInfo"].(map[string]any)["name"] != "mugen-shell" {
		t.Errorf("unexpected serverInfo: %v", result["serverInfo"])
	}
}

func TestToolsListShape(t *testing.T) {
	h, _ := newTestHandler("", nil)
	resp := handle(t, h, `{"jsonrpc":"2.0","id":2,"method":"tools/list"}`)
	list := resp["result"].(map[string]any)["tools"].([]any)
	if len(list) != 1 {
		t.Fatalf("expected 1 tool, got %d", len(list))
	}
	tool := list[0].(map[string]any)
	if tool["name"] != "theme_get" || tool["inputSchema"] == nil {
		t.Errorf("unexpected tool shape: %v", tool)
	}
	if tool["annotations"].(map[string]any)["readOnlyHint"] != false {
		// fake tools have no readonly flag set; the annotation must still exist
		t.Errorf("expected readOnlyHint annotation, got %v", tool["annotations"])
	}
}

func TestToolsCallHappyPath(t *testing.T) {
	h, src := newTestHandler("dark", nil)
	resp := handle(t, h, `{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"theme_get","arguments":{}}}`)
	result := resp["result"].(map[string]any)
	if result["isError"] != false {
		t.Errorf("expected isError false: %v", result)
	}
	content := result["content"].([]any)[0].(map[string]any)
	if content["text"] != "dark" {
		t.Errorf("expected tool output, got %v", content)
	}
	if len(src.called) != 1 || src.called[0] != "theme_get" {
		t.Errorf("expected exactly one dispatch, got %v", src.called)
	}
}

func TestToolsCallRejectsUnexposedTool(t *testing.T) {
	h, src := newTestHandler("", nil)
	resp := handle(t, h, `{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"app_launch","arguments":{"cmd":"rm"}}}`)
	if resp["error"] == nil {
		t.Fatal("expected a JSON-RPC error for an unexposed tool")
	}
	if len(src.called) != 0 {
		t.Fatalf("unexposed tool must never be dispatched, got %v", src.called)
	}
}

func TestToolsCallMapsErrorResults(t *testing.T) {
	h, _ := newTestHandler("error: category disabled", nil)
	resp := handle(t, h, `{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"theme_get"}}`)
	if resp["result"].(map[string]any)["isError"] != true {
		t.Error("error:-prefixed results must map to isError true")
	}

	h2, _ := newTestHandler("", errors.New("exec failed"))
	resp2 := handle(t, h2, `{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"theme_get"}}`)
	result := resp2["result"].(map[string]any)
	if result["isError"] != true {
		t.Error("Go errors must map to isError true")
	}
}

func TestNotificationsProduceNoResponse(t *testing.T) {
	h, _ := newTestHandler("", nil)
	if resp := h.HandleMessage(context.Background(), []byte(`{"jsonrpc":"2.0","method":"notifications/initialized"}`)); resp != nil {
		t.Errorf("notification must not be answered, got %s", resp)
	}
}

func TestIDLessToolsCallDoesNotExecute(t *testing.T) {
	h, src := newTestHandler("dark", nil)
	// A tools/call missing its id must NOT run the tool fire-and-forget.
	if resp := h.HandleMessage(context.Background(), []byte(`{"jsonrpc":"2.0","method":"tools/call","params":{"name":"theme_get"}}`)); resp != nil {
		t.Errorf("id-less request must not be answered, got %s", resp)
	}
	if len(src.called) != 0 {
		t.Errorf("id-less tools/call must not dispatch the tool, got %v", src.called)
	}
}

func TestUnknownMethodAndBatch(t *testing.T) {
	h, _ := newTestHandler("", nil)
	resp := handle(t, h, `{"jsonrpc":"2.0","id":7,"method":"resources/list"}`)
	if resp["error"] == nil {
		t.Error("unsupported method must return an error")
	}
	batch := handle(t, h, `[{"jsonrpc":"2.0","id":8,"method":"ping"}]`)
	if batch["error"] == nil {
		t.Error("batch messages must be refused")
	}
}

func TestServeHTTP(t *testing.T) {
	h, _ := newTestHandler("", nil)

	req := httptest.NewRequest("POST", "/mcp", strings.NewReader(`{"jsonrpc":"2.0","id":1,"method":"ping"}`))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), `"result"`) {
		t.Errorf("request: expected 200 + result, got %d %s", rec.Code, rec.Body.String())
	}

	req = httptest.NewRequest("POST", "/mcp", strings.NewReader(`{"jsonrpc":"2.0","method":"notifications/initialized"}`))
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != 202 {
		t.Errorf("notification: expected 202, got %d", rec.Code)
	}

	req = httptest.NewRequest("GET", "/mcp", nil)
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != 405 {
		t.Errorf("GET: expected 405, got %d", rec.Code)
	}
}
