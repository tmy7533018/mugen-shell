package tools

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

type fakeMCPTool struct {
	name   string
	result string
}

func newFakeMCPServer(t *testing.T, toolList []fakeMCPTool) *httptest.Server {
	t.Helper()
	callResult := map[string]fakeMCPTool{}
	for _, tl := range toolList {
		callResult[tl.name] = tl
	}
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
			tools := make([]map[string]any, len(toolList))
			for i, tl := range toolList {
				tools[i] = map[string]any{
					"name":        tl.name,
					"description": "fake tool",
					"inputSchema": map[string]any{"type": "object", "properties": map[string]any{}},
				}
			}
			resp["result"] = map[string]any{"tools": tools}
		case "tools/call":
			var params struct {
				Name string `json:"name"`
			}
			_ = json.Unmarshal(req.Params, &params)
			resp["result"] = map[string]any{
				"content": []map[string]any{{"type": "text", "text": callResult[params.Name].result}},
			}
		default:
			resp["result"] = map[string]any{}
		}

		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
}
