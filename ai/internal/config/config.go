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
	MCPExpose   MCPExpose   `toml:"mcp_expose" json:"mcp_expose"`
	History     History     `toml:"history" json:"history"`
	Context     Context     `toml:"context" json:"context"`
	Weather     Weather     `toml:"weather" json:"weather"`
	Logging     Logging     `toml:"logging" json:"logging"`
}

// MCPExpose publishes mugen-ai's own tools as an MCP server, never re-exporting external
// ones. Read-only unless Categories opts a group in — clients skip Yura's confirmation.
type MCPExpose struct {
	Enabled  bool `toml:"enabled" json:"enabled"`
	Readonly bool `toml:"readonly" json:"readonly"`
	// Categories additionally exposes every tool (reads and writes) of the
	// listed categories.
	Categories []string `toml:"categories" json:"categories"`
}

// Logging.Audit gates the JSONL tool-call log; off leaves no trace of calls or arguments on disk.
type Logging struct {
	Audit bool `toml:"audit" json:"audit"`
}

// Weather configures the weather_get tool (Open-Meteo, no API key). Place
// is the default location used when the user doesn't name one.
type Weather struct {
	Place string `toml:"place" json:"place"`
}

// Context injects a live desktop snapshot into chat turns, never persisted to history.
// DesktopStateRemote off keeps window titles and media names off cloud providers.
type Context struct {
	DesktopState       bool `toml:"desktop_state" json:"desktop_state"`
	DesktopStateRemote bool `toml:"desktop_state_remote" json:"desktop_state_remote"`
}

// History prunes conversations idle longer than RetainDays at startup; 0 keeps everything.
type History struct {
	RetainDays int `toml:"retain_days" json:"retain_days"`
	// MaxContextTokens caps the history's estimated tokens per turn (oldest drop first),
	// leaving room for tools, system prompt and the reply. 0 disables the cap.
	MaxContextTokens int `toml:"max_context_tokens" json:"max_context_tokens"`
}

// MCP merges external MCP servers' tools into the registry under a "<name>__<tool>"
// prefix, so the server name doubles as a tool category.
type MCP struct {
	Servers map[string]MCPServer `toml:"servers" json:"servers"`
}

// MCPServer is one server entry; URL (Streamable HTTP) wins over Command (stdio).
// Trusted skips the approval prompt — the only gate on irreversible writes.
type MCPServer struct {
	Command  string            `toml:"command" json:"command"`
	Args     []string          `toml:"args" json:"args"`
	Env      map[string]string `toml:"env" json:"env"`
	URL      string            `toml:"url" json:"url"`
	Disabled bool              `toml:"disabled" json:"disabled"`
	Trusted  bool              `toml:"trusted" json:"trusted"`
}

type Tools struct {
	AppLaunch AppLaunchTool `toml:"app_launch" json:"app_launch"`
	// DisabledCategories hides whole tool groups from the LLM. Empty = every category enabled.
	DisabledCategories []string      `toml:"disabled_categories" json:"disabled_categories"`
	ContextFilter      ContextFilter `toml:"context_filter" json:"context_filter"`
}

// ContextFilter narrows the per-turn tool list, because local models pick the wrong tool
// more often as the count grows. An unconfident layer sends the full list, so it can't brick.
type ContextFilter struct {
	Enabled bool `toml:"enabled" json:"enabled"`
	// ApplyToRemote extends filtering to cloud providers. Off by default: a per-turn
	// tool list defeats their prompt caching, and hosted models handle the full list.
	ApplyToRemote bool `toml:"apply_to_remote" json:"apply_to_remote"`
	// EmbedModel is the Ollama embedding model for the similarity layer.
	// Missing model or empty string degrades to keyword-only matching.
	EmbedModel string `toml:"embed_model" json:"embed_model"`
	// TopK caps how many categories the embedding layer may add; MinScore
	// is the cosine floor below which a category is not considered related.
	TopK     int     `toml:"top_k" json:"top_k"`
	MinScore float64 `toml:"min_score" json:"min_score"`
	// AlwaysInclude rides along on every filtered turn: panel is named by tool error
	// messages and memory powers spontaneous saves, neither tied to the user's wording.
	AlwaysInclude []string `toml:"always_include" json:"always_include"`
}

// AppLaunchTool gates app_launch. Empty AllowedCommands launches nothing, so a
// prompt-injected request can't run rm or curl; the user allows apps from Settings.
type AppLaunchTool struct {
	AllowedCommands []string `toml:"allowed_commands" json:"allowed_commands"`
}

type Shell struct {
	// QsConfig is the quickshell `-c` name used to target mugen-shell from
	// `qs ipc call`. Defaults to "mugen-shell".
	QsConfig string `toml:"qs_config" json:"qs_config"`
	// ScriptsDir holds calendar-cli.py / toggle-*.sh, for tools that can't fit through IPC.
	// Defaults to "$XDG_CONFIG_HOME/quickshell/mugen-shell/scripts".
	ScriptsDir string `toml:"scripts_dir" json:"scripts_dir"`
}

type Personality struct {
	// Name / Tone / Language build the persona header prepended to SystemPrompt, the
	// user's free-form append. All are optional — an empty field skips its line.
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

// Anthropic lists the Claude models to expose (empty → claude-haiku-4-5). MaxTokens
// caps each reply (0 → 2048); ThinkingBudget is the extended-thinking budget (0 → 1024).
type Anthropic struct {
	Models         []string `toml:"models" json:"models"`
	MaxTokens      int      `toml:"max_tokens" json:"max_tokens"`
	ThinkingBudget int      `toml:"thinking_budget" json:"thinking_budget"`
}

type Ollama struct {
	Host string `toml:"host" json:"host"`
	// NumCtx is requested on every chat call: Ollama's own 4k default is smaller than
	// tools + prompt + history and overflow truncates silently. Clamped to the model max.
	NumCtx int `toml:"num_ctx" json:"num_ctx"`
	// KeepAlive keeps the model loaded between chats ("30m", "1h", "-1" for
	// forever). Empty falls back to Ollama's default (5m unload).
	KeepAlive string `toml:"keep_alive" json:"keep_alive"`
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
			Ollama: Ollama{Host: "http://localhost:11434", NumCtx: 16384, KeepAlive: "30m"},
		},
		Shell:   Shell{QsConfig: "mugen-shell"},
		Context: Context{DesktopState: true, DesktopStateRemote: true},
		History: History{MaxContextTokens: 8000},
		Logging: Logging{Audit: true},
		Tools: Tools{
			ContextFilter: ContextFilter{
				Enabled:       true,
				EmbedModel:    "bge-m3",
				TopK:          4,
				MinScore:      0.4,
				AlwaysInclude: []string{"panel", "memory"},
			},
		},
		MCPExpose: MCPExpose{Readonly: true},
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
	// config.toml can carry MCP secrets in [mcp.servers.*.env]; tighten a loose umask.
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

// Save writes cfg atomically so a crash mid-write can't corrupt the file. BurntSushi's
// encoder drops user comments — callers should warn that hand-written ones are lost.
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
