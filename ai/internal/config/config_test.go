package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func sandbox(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	return filepath.Join(dir, "mugen-ai", "config.toml")
}

func TestPathFollowsXDGConfigHome(t *testing.T) {
	want := sandbox(t)
	if got := Path(); got != want {
		t.Fatalf("Path() = %q, want %q", got, want)
	}
}

func TestPathFallsBackToHome(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("HOME", "/home/somebody")
	if got, want := Path(), "/home/somebody/.config/mugen-ai/config.toml"; got != want {
		t.Fatalf("Path() = %q, want %q", got, want)
	}
}

func TestDefaultKeepsTheRestrictiveChoices(t *testing.T) {
	cfg := Default()

	if len(cfg.Tools.AppLaunch.AllowedCommands) != 0 {
		t.Errorf("AllowedCommands = %v, want empty so a prompt-injected launch has nothing to run",
			cfg.Tools.AppLaunch.AllowedCommands)
	}
	if !cfg.MCPExpose.Readonly {
		t.Error("MCPExpose.Readonly = false, want true so exposed tools cannot write by default")
	}
	if cfg.MCPExpose.Enabled {
		t.Error("MCPExpose.Enabled = true, want false so no server is published unasked")
	}
	if len(cfg.MCP.Servers) != 0 {
		t.Errorf("MCP.Servers = %v, want none configured by default", cfg.MCP.Servers)
	}
	if !cfg.Logging.Audit {
		t.Error("Logging.Audit = false, want true so tool calls leave a trace")
	}
}

func TestLoadCreatesTheDefaultFileWhenMissing(t *testing.T) {
	path := sandbox(t)

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if cfg.Provider.Ollama.Host != Default().Provider.Ollama.Host {
		t.Errorf("Ollama.Host = %q, want the default", cfg.Provider.Ollama.Host)
	}

	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("Load() did not create %s: %v", path, err)
	}
	if perm := info.Mode().Perm(); perm != 0o600 {
		t.Errorf("new config mode = %04o, want 0600: it may later hold MCP server secrets", perm)
	}
}

func TestLoadTightensAWorldReadableConfig(t *testing.T) {
	path := sandbox(t)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte("[personality]\nname = \"Yura\"\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	if _, err := Load(); err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if perm := info.Mode().Perm(); perm&0o077 != 0 {
		t.Errorf("mode after Load = %04o, want no group/other bits", perm)
	}
}

func TestLoadOverlaysOntoDefaults(t *testing.T) {
	path := sandbox(t)
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	partial := "[personality]\nname = \"Yura\"\n"
	if err := os.WriteFile(path, []byte(partial), 0o600); err != nil {
		t.Fatal(err)
	}

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	def := Default()

	if cfg.Personality.Name != "Yura" {
		t.Errorf("Personality.Name = %q, want %q", cfg.Personality.Name, "Yura")
	}
	if cfg.Personality.SystemPrompt != def.Personality.SystemPrompt {
		t.Errorf("SystemPrompt = %q, want the default kept", cfg.Personality.SystemPrompt)
	}
	if cfg.Provider.Ollama.NumCtx != def.Provider.Ollama.NumCtx {
		t.Errorf("Ollama.NumCtx = %d, want %d", cfg.Provider.Ollama.NumCtx, def.Provider.Ollama.NumCtx)
	}
	if cfg.Shell.QsConfig != def.Shell.QsConfig {
		t.Errorf("Shell.QsConfig = %q, want %q", cfg.Shell.QsConfig, def.Shell.QsConfig)
	}
	if !cfg.Tools.ContextFilter.Enabled {
		t.Error("ContextFilter.Enabled = false, want the default kept")
	}
	if cfg.Tools.ContextFilter.MinScore != def.Tools.ContextFilter.MinScore {
		t.Errorf("ContextFilter.MinScore = %v, want %v",
			cfg.Tools.ContextFilter.MinScore, def.Tools.ContextFilter.MinScore)
	}
	if !cfg.MCPExpose.Readonly {
		t.Error("MCPExpose.Readonly = false, want the restrictive default kept")
	}
}

func TestLoadOnBrokenTomlReturnsDefaultsAndAnError(t *testing.T) {
	path := sandbox(t)
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte("[personality\nname = "), 0o600); err != nil {
		t.Fatal(err)
	}

	cfg, err := Load()
	if err == nil {
		t.Fatal("Load() error = nil, want a decode error")
	}
	if cfg.Provider.Ollama.Host != Default().Provider.Ollama.Host {
		t.Errorf("Ollama.Host = %q, want the untouched default", cfg.Provider.Ollama.Host)
	}
	if len(cfg.Tools.AppLaunch.AllowedCommands) != 0 {
		t.Errorf("AllowedCommands = %v, want empty on a failed decode",
			cfg.Tools.AppLaunch.AllowedCommands)
	}
}

func TestSaveRoundTrips(t *testing.T) {
	sandbox(t)

	cfg := Default()
	cfg.Personality.Name = "Yura"
	cfg.Tools.AppLaunch.AllowedCommands = []string{"firefox", "kitty"}
	cfg.Tools.DisabledCategories = []string{"weather"}
	cfg.MCP.Servers = map[string]MCPServer{
		"memory": {Command: "npx", Args: []string{"-y", "@modelcontextprotocol/server-memory"}, Trusted: true},
	}

	if err := Save(cfg); err != nil {
		t.Fatalf("Save() error = %v", err)
	}
	got, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	if got.Personality.Name != "Yura" {
		t.Errorf("Personality.Name = %q, want %q", got.Personality.Name, "Yura")
	}
	if strings.Join(got.Tools.AppLaunch.AllowedCommands, ",") != "firefox,kitty" {
		t.Errorf("AllowedCommands = %v, want [firefox kitty]", got.Tools.AppLaunch.AllowedCommands)
	}
	if strings.Join(got.Tools.DisabledCategories, ",") != "weather" {
		t.Errorf("DisabledCategories = %v, want [weather]", got.Tools.DisabledCategories)
	}
	srv, ok := got.MCP.Servers["memory"]
	if !ok {
		t.Fatalf("MCP.Servers = %v, want a \"memory\" entry", got.MCP.Servers)
	}
	if srv.Command != "npx" || !srv.Trusted {
		t.Errorf("memory server = %+v, want command npx and trusted true", srv)
	}
}

func TestSaveKeepsSecretsOffOtherUsersAndLeavesNoTempFile(t *testing.T) {
	path := sandbox(t)

	cfg := Default()
	cfg.MCP.Servers = map[string]MCPServer{
		"github": {Command: "npx", Env: map[string]string{"GITHUB_TOKEN": "sekrit"}},
	}
	if err := Save(cfg); err != nil {
		t.Fatalf("Save() error = %v", err)
	}

	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if perm := info.Mode().Perm(); perm&0o077 != 0 {
		t.Errorf("saved config mode = %04o, want no group/other bits: it holds MCP env secrets", perm)
	}

	entries, err := os.ReadDir(filepath.Dir(path))
	if err != nil {
		t.Fatal(err)
	}
	for _, e := range entries {
		if strings.HasSuffix(e.Name(), ".tmp") {
			t.Errorf("Save() left %s behind", e.Name())
		}
	}
}
