package config

import (
	"os"
	"path/filepath"

	"github.com/BurntSushi/toml"
)

type Config struct {
	Personality Personality `toml:"personality" json:"personality"`
	Provider    Provider    `toml:"provider" json:"provider"`
	Shell       Shell       `toml:"shell" json:"shell"`
	Tools       Tools       `toml:"tools" json:"tools"`
	MCP         MCP         `toml:"mcp" json:"mcp"`
}

// MCP configures external Model Context Protocol servers whose tools are
// merged into the registry alongside the built-in shell tools. Each server
// is spawned as a subprocess at startup and its tools exposed under a
// "<name>__<tool>" prefix so the server name doubles as a tool category.
type MCP struct {
	Servers map[string]MCPServer `toml:"servers" json:"servers"`
}

// MCPServer is one stdio MCP server entry. Command is the executable,
// Args its arguments, Env extra variables layered onto the inherited
// environment. Disabled keeps the entry in the file but skips spawning it.
// Trusted skips the per-call approval prompt for this server's destructive
// tools — opt-in, since it removes the only gate on irreversible writes.
type MCPServer struct {
	Command  string            `toml:"command" json:"command"`
	Args     []string          `toml:"args" json:"args"`
	Env      map[string]string `toml:"env" json:"env"`
	Disabled bool              `toml:"disabled" json:"disabled"`
	Trusted  bool              `toml:"trusted" json:"trusted"`
}

type Tools struct {
	AppLaunch AppLaunchTool `toml:"app_launch" json:"app_launch"`
	// DisabledCategories hides whole tool groups (audio / music / panel /
	// brightness / theme / wallpaper / notification / timer / calendar /
	// app) from the LLM. Empty = every category enabled.
	DisabledCategories []string `toml:"disabled_categories" json:"disabled_categories"`
}

// AppLaunchTool gates the app_launch tool. Default is strict: an empty
// AllowedCommands means no apps can be launched at all, so a prompt-
// injected request can't ask Yura to run rm or curl. The user picks
// which installed apps to allow via Settings → AI / Yura → Allowed apps.
type AppLaunchTool struct {
	AllowedCommands []string `toml:"allowed_commands" json:"allowed_commands"`
}

type Shell struct {
	// QsConfig is the quickshell `-c` name used to target mugen-shell from
	// `qs ipc call`. Defaults to "mugen-shell".
	QsConfig string `toml:"qs_config" json:"qs_config"`
	// ScriptsDir is where calendar-cli.py / toggle-*.sh live. mugen-ai
	// shells out to these for tools that can't fit through the IPC layer
	// (Calendar DB queries etc.). Defaults to
	// "$XDG_CONFIG_HOME/quickshell/mugen-shell/scripts".
	ScriptsDir string `toml:"scripts_dir" json:"scripts_dir"`
}

type Personality struct {
	// Name / Tone / Language drive the auto-assembled persona header that is
	// prepended to SystemPrompt. SystemPrompt is the user's free-form append.
	// All four are optional — empty fields skip their line in the header.
	Name         string `toml:"name" json:"name"`
	Tone         string `toml:"tone" json:"tone"`
	Language     string `toml:"language" json:"language"`
	SystemPrompt string `toml:"system_prompt" json:"system_prompt"`
}

type Provider struct {
	Ollama    Ollama    `toml:"ollama" json:"ollama"`
	Google    Google    `toml:"google" json:"google"`
	OpenAI    OpenAI    `toml:"openai" json:"openai"`
	Anthropic Anthropic `toml:"anthropic" json:"anthropic"`
}

// Anthropic lists the Claude models to expose. Empty → defaults to
// claude-haiku-4-5 (cheap, fast, tool-capable).
type Anthropic struct {
	Models []string `toml:"models" json:"models"`
}

type Ollama struct {
	Host string `toml:"host" json:"host"`
}

// Google reads from Models (plural). Legacy single-string Model is kept as
// fallback for old configs; new code should populate Models instead.
type Google struct {
	Model  string   `toml:"model,omitempty" json:"model,omitempty"`
	Models []string `toml:"models" json:"models"`
}

// OpenAI configures any OpenAI-compatible backend (OpenAI, OpenRouter,
// LM Studio, vLLM, ...). Empty Models means the provider asks /v1/models.
type OpenAI struct {
	BaseURL string   `toml:"base_url" json:"base_url"`
	Models  []string `toml:"models" json:"models"`
}

func Default() Config {
	return Config{
		Personality: Personality{
			SystemPrompt: "You are a helpful desktop assistant. Be concise.",
		},
		Provider: Provider{
			Ollama: Ollama{Host: "http://localhost:11434"},
		},
		Shell: Shell{QsConfig: "mugen-shell"},
	}
}

func Load() (Config, error) {
	cfg := Default()
	path := filePath()

	info, err := os.Stat(path)
	if os.IsNotExist(err) {
		if err := writeDefault(path, cfg); err != nil {
			return cfg, err
		}
		return cfg, nil
	}
	// config.toml can carry MCP server secrets in [mcp.servers.*.env];
	// tighten an existing file that a looser umask left group/world-readable.
	if err == nil && info.Mode().Perm()&0o077 != 0 {
		_ = os.Chmod(path, 0o600)
	}

	if _, err := toml.DecodeFile(path, &cfg); err != nil {
		return Default(), err
	}
	return cfg, nil
}

func filePath() string {
	dir := os.Getenv("XDG_CONFIG_HOME")
	if dir == "" {
		home, _ := os.UserHomeDir()
		dir = filepath.Join(home, ".config")
	}
	return filepath.Join(dir, "mugen-ai", "config.toml")
}

// Path returns the canonical config file path.
func Path() string { return filePath() }

// Save writes cfg to disk atomically (write to tmp, rename) so a crash mid-
// write can't corrupt the file. BurntSushi's encoder does not preserve user
// comments — callers should warn users that hand-written comments are lost.
func Save(cfg Config) error {
	path := filePath()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), "config.toml.*.tmp")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)

	if err := toml.NewEncoder(tmp).Encode(cfg); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpPath, path)
}

func writeDefault(path string, cfg Config) error {
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}
	// 0600: the file may later gain MCP server secrets in [mcp.servers.*.env].
	f, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return err
	}
	defer f.Close()
	return toml.NewEncoder(f).Encode(cfg)
}
