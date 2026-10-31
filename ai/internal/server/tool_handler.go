package server

import (
	"encoding/json"
	"net/http"

	"github.com/tmy7533018/mugen-ai/internal/mcp"
	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/tools"
)

func (s *Server) handleListTools(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, map[string]any{"tools": s.tools.List()})
}

func (s *Server) handleListMCPServers(w http.ResponseWriter, _ *http.Request) {
	var statuses []mcp.ServerStatus
	if s.mcp != nil {
		statuses = s.mcp.Statuses()
	}
	if statuses == nil {
		statuses = []mcp.ServerStatus{}
	}
	writeJSON(w, map[string]any{"servers": statuses})
}

func (s *Server) handleMCPDiscover(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]any{"candidates": mcp.Discover(r.Context())})
}

// ProviderTools converts registry tools into the schema the providers take.
func ProviderTools(in []tools.Tool) []provider.Tool {
	out := make([]provider.Tool, len(in))
	for i, t := range in {
		out[i] = provider.Tool{
			Name:        t.Name,
			Description: t.Description,
			Parameters:  t.Parameters,
		}
	}
	return out
}

type toolCallRequest struct {
	Name string         `json:"name"`
	Args map[string]any `json:"args"`
}

func (s *Server) handleToolCall(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBody)
	var req toolCallRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Name == "" {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}
	// No user is in the loop here, so this debug path must not bypass the confirmation gate.
	if s.tools.NeedsConfirm(req.Name) {
		http.Error(w, "tool requires confirmation; invoke via /chat", http.StatusForbidden)
		return
	}
	result, err := s.tools.Call(r.Context(), req.Name, req.Args)
	resp := map[string]any{"result": result}
	if err != nil {
		resp["error"] = err.Error()
	}
	writeJSON(w, resp)
}
