package server

import (
	"encoding/json"
	"net/http"
	"os"
	"os/exec"
	"time"

	"github.com/tmy7533018/mugen-ai/internal/config"
)

// providerKeyEnv lists env vars whose presence we report as "configured" so
// the UI can show a green dot without ever seeing the secret itself.
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
	var cfg config.Config
	if err := json.NewDecoder(r.Body).Decode(&cfg); err != nil {
		http.Error(w, "invalid json: "+err.Error(), http.StatusBadRequest)
		return
	}
	if err := config.Save(cfg); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]any{"saved": true, "restart_required": true})
}

func (s *Server) handleRestart(w http.ResponseWriter, _ *http.Request) {
	// Only meaningful under systemd. INVOCATION_ID is set for service-managed
	// processes; bail out cleanly when running ad-hoc so dev `go run` isn't
	// killed silently.
	if os.Getenv("INVOCATION_ID") == "" {
		http.Error(w, "not running under systemd", http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]any{"restarting": true})
	if f, ok := w.(http.Flusher); ok {
		f.Flush()
	}
	// Detached so systemctl survives our exit; small delay lets the response
	// drain before systemd sends SIGTERM.
	go func() {
		time.Sleep(150 * time.Millisecond)
		_ = exec.Command("systemctl", "--user", "restart", "mugen-ai").Start()
	}()
}
