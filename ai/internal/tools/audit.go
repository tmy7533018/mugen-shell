package tools

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"
	"unicode/utf8"
)

type Auditor struct {
	path string
}

func NewAuditor(path string) *Auditor {
	if path == "" {
		return nil
	}
	return &Auditor{path: path}
}

// Log appends one JSON line per tool call. Best-effort: every error is
// swallowed so a broken log file never blocks a real tool call.
func (a *Auditor) Log(tool string, args map[string]any, result string, callErr error) {
	if a == nil {
		return
	}
	if err := os.MkdirAll(filepath.Dir(a.path), 0o755); err != nil {
		return
	}
	f, err := os.OpenFile(a.path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()

	entry := map[string]any{
		"t":      time.Now().UTC().Format(time.RFC3339Nano),
		"tool":   tool,
		"args":   args,
		"result": truncate(result, 1024),
	}
	if callErr != nil {
		entry["error"] = callErr.Error()
	}
	_ = json.NewEncoder(f).Encode(entry)
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	// Back off to a rune boundary so the audit log stays valid UTF-8.
	for n > 0 && !utf8.RuneStart(s[n]) {
		n--
	}
	return s[:n] + "…"
}
