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

// MCPExpose publishes mugen-ai's own tools as an MCP server, over HTTP at
// POST /mcp on the loopback-only API port and over stdio via the
// `mugen-ai mcp-server` bridge. Tools sourced from external MCP servers are
// never re-exported. Enabled means read-only unless Categories names groups
// to make writable — a deliberate decision per category, since external
// clients skip Yura's confirmation flow.
type MCPExpose struct {
	Enabled  bool `toml:"enabled" json:"enabled"`
	Readonly bool `toml:"readonly" json:"readonly"`
	// Categories additionally exposes every tool (reads and writes) of the
	// listed categories.
	Categories []string `toml:"categories" json:"categories"`
}

// Logging controls diagnostic output. Audit gates the JSONL tool-call log
// (audit.log); turning it off means tool calls — including their arguments —
// leave no trace on disk.
type Logging struct {
	Audit bool `toml:"audit" json:"audit"`
}

// Weather configures the weather_get tool (Open-Meteo, no API key). Place
// is the default location used when the user doesn't name one.
type Weather struct {
	Place string `toml:"place" json:"place"`
}

// Context controls extra, non-conversation information injected into chat
// turns. DesktopState adds a transient system message with a live desktop
// snapshot, never persisted to history. DesktopStateRemote extends that to
// cloud providers; off keeps window titles and media names on the machine.
type Context struct {
	DesktopState       bool `toml:"desktop_state" json:"desktop_state"`
	DesktopStateRemote bool `toml:"desktop_state_remote" json:"desktop_state_remote"`
}

// History controls retention of stored conversations. RetainDays > 0 prunes,
// at startup, conversations whose last activity is older than that many days;
// 0 keeps everything.
type History struct {
	RetainDays int `toml:"retain_days" json:"retain_days"`
	// MaxContextTokens caps the estimated token footprint of the history
	// sent per turn (oldest messages drop first), leaving context-window
	// room for tools, system prompt, and the response. 0 disables the cap
	// (the 100-message limit still applies).
	MaxContextTokens int `toml:"max_context_tokens" json:"max_context_tokens"`
}

// MCP configures external Model Context Protocol servers whose tools are
// merged into the registry. Tools are exposed under a "<name>__<tool>"
// prefix, so the server name doubles as a tool category.
type MCP struct {
	Servers map[string]MCPServer `toml:"servers" json:"servers"`
}

// MCPServer is one MCP server entry. Command spawns a stdio server, URL
// connects to a remote Streamable HTTP one; when both are set, URL wins.
// Trusted skips the per-call approval prompt for this server's destructive
// tools — opt-in, since it removes the only gate on irreversible writes.
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
	// DisabledCategories hides whole tool groups (audio / music / panel /
	// brightness / theme / wallpaper / notification / timer / calendar /
	// app) from the LLM. Empty = every category enabled.
	DisabledCategories []string      `toml:"disabled_categories" json:"disabled_categories"`
	ContextFilter      ContextFilter `toml:"context_filter" json:"context_filter"`
}

// ContextFilter narrows the tool list sent per chat turn to the categories
// relevant to the user's message, because local models pick the wrong tool
// more often as the tool count grows. When neither the keyword nor the
// embedding layer is confident the full list is sent, so filtering can only
// trim, never brick a request.
type ContextFilter struct {
	Enabled bool `toml:"enabled" json:"enabled"`
	// ApplyToRemote extends filtering to cloud providers. Off by default:
	// a per-turn tool list defeats their prompt caching (the tool block is
	// a cache prefix), and large hosted models handle the full list fine.
	ApplyToRemote bool `toml:"apply_to_remote" json:"apply_to_remote"`
	// EmbedModel is the Ollama embedding model for the similarity layer.
	// Missing model or empty string degrades to keyword-only matching.
	EmbedModel string `toml:"embed_model" json:"embed_model"`
	// TopK caps how many categories the embedding layer may add; MinScore
	// is the cosine floor below which a category is not considered related.
	TopK     int     `toml:"top_k" json:"top_k"`
	MinScore float64 `toml:"min_score" json:"min_score"`
	// AlwaysInclude categories ride along on every filtered turn. panel is
	// referenced by tool error messages (panel_open recovery path) and
	// memory powers spontaneous memory_save, so dropping either breaks
	// flows that don't correlate with the user's wording.
	AlwaysInclude []string `toml:"always_include" json:"always_include"`
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
// claude-haiku-4-5 (cheap, fast, tool-capable). MaxTokens caps each reply
// (0 → 2048); ThinkingBudget is the extended-thinking token budget when the
// conversation has thinking on (0 → 1024).
type Anthropic struct {
	Models         []string `toml:"models" json:"models"`
	MaxTokens      int      `toml:"max_tokens" json:"max_tokens"`
	ThinkingBudget int      `toml:"thinking_budget" json:"thinking_budget"`
}

type Ollama struct {
	Host string `toml:"host" json:"host"`
	// NumCtx is the context window requested on every chat call. Ollama's
	// own default (4k) is smaller than the tools + system prompt + history
	// footprint and overflow is truncated silently, so mugen-ai always asks
	// for an explicit window. Ollama clamps it to the model's maximum.
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

// Save writes cfg atomically so a crash mid-write can't corrupt the file.
// BurntSushi's encoder drops user comments — callers should warn that
// hand-written comments are lost.
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
