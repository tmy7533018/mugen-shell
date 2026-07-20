package server

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"os/exec"
	"time"

	"github.com/tmy7533018/mugen-ai/internal/config"
)

// Only the presence of these is ever reported, so the UI can show "configured"
// without receiving the secret.
var providerKeyEnv = map[string][]string{
	"anthropic": {"ANTHROPIC_API_KEY"},
	"google":    {"GEMINI_API_KEY", "GOOGLE_API_KEY"},
	"openai":    {"OPENAI_API_KEY"},
}

func (s *Server) handleGetConfig(w http.ResponseWriter, _ *http.Request) {
	cfg, err := config.Load()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	keys := map[string]bool{}
	for name, envs := range providerKeyEnv {
		for _, env := range envs {
			if os.Getenv(env) != "" {
				keys[name] = true
				break
			}
		}
		if _, ok := keys[name]; !ok {
			keys[name] = false
		}
	}
	writeJSON(w, map[string]any{
		"config":             cfg,
		"path":               config.Path(),
		"api_key_configured": keys,
	})
}

func (s *Server) handlePutConfig(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBody)
	// Decode over the existing config, not a zero value, so a partial body
	// patches rather than wiping the sections it didn't send.
	cfg, err := config.Load()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	// The decode merges maps rather than replacing them, so a deleted MCP
	// server would survive. Clear the map first so deletions persist.
	if mcpServersPresent(body) {
		cfg.MCP.Servers = nil
	}
	if err := json.Unmarshal(body, &cfg); err != nil {
		http.Error(w, "invalid json: "+err.Error(), http.StatusBadRequest)
		return
	}
	if err := config.Save(cfg); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]any{"saved": true, "restart_required": true})
}

func mcpServersPresent(body []byte) bool {
	var probe struct {
		MCP *struct {
			Servers json.RawMessage `json:"servers"`
		} `json:"mcp"`
	}
	if err := json.Unmarshal(body, &probe); err != nil {
		return false
	}
	return probe.MCP != nil && probe.MCP.Servers != nil
}

func (s *Server) handleRestart(w http.ResponseWriter, _ *http.Request) {
	// INVOCATION_ID marks a service-managed process; bailing out keeps a dev
	// `go run` from being killed silently.
	if os.Getenv("INVOCATION_ID") == "" {
		http.Error(w, "not running under systemd", http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]any{"restarting": true})
	if f, ok := w.(http.Flusher); ok {
		f.Flush()
	}
	// Detached so systemctl survives our exit; the delay lets the response
	// drain before systemd sends SIGTERM.
	go func() {
		time.Sleep(150 * time.Millisecond)
		_ = exec.Command("systemctl", "--user", "restart", "mugen-ai").Start()
	}()
}
