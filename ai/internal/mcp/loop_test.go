// Self-loop test: mugen-ai's MCP server consumed by its own MCP client. An
// external test package so the mcp ← tools ← mcpserver import chain stays
// acyclic.
package mcp_test

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/tmy7533018/mugen-ai/internal/mcp"
	"github.com/tmy7533018/mugen-ai/internal/mcpserver"
	"github.com/tmy7533018/mugen-ai/internal/tools"
)

type loopSource struct{ lastArgs map[string]any }

func (s *loopSource) ExposedTools(_ bool, _ []string) []tools.Tool {
	return []tools.Tool{
		{
			Name:        "theme_get",
			Description: "Read theme.",
			Parameters:  map[string]any{"type": "object", "properties": map[string]any{}},
		},
	}
}

func (s *loopSource) Call(_ context.Context, name string, args map[string]any) (string, error) {
	s.lastArgs = args
	if name != "theme_get" {
		return "error: unexpected tool", nil
	}
	return "dark", nil
}

func TestClientServerLoopOverHTTP(t *testing.T) {
	src := &loopSource{}
	ts := httptest.NewServer(mcpserver.New(src, true, nil, "test"))
	defer ts.Close()

	mgr := mcp.Connect(context.Background(), map[string]mcp.ServerConfig{
		"self": {URL: ts.URL},
	})
	defer mgr.Close()

	statuses := mgr.Statuses()
	if len(statuses) != 1 || !statuses[0].Connected {
		t.Fatalf("expected connected status, got %+v", statuses)
	}
	if statuses[0].ToolCount != 1 {
		t.Fatalf("expected 1 tool, got %d", statuses[0].ToolCount)
	}

	client := mgr.Clients()["self"]
	if client == nil {
		t.Fatal("client missing")
	}
	defs := client.Tools()
	if len(defs) != 1 || defs[0].Name != "theme_get" {
		t.Fatalf("unexpected tool defs: %+v", defs)
	}

	out, err := mgr.Call(context.Background(), "self", "theme_get", map[string]any{"x": 1})
	if err != nil {
		t.Fatalf("call failed: %v", err)
	}
	if strings.TrimSpace(out) != "dark" {
		t.Errorf("expected result 'dark', got %q", out)
	}
	if src.lastArgs["x"] != float64(1) {
		t.Errorf("arguments did not round-trip: %v", src.lastArgs)
	}
}
