package cmd

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/tmy7533018/mugen-ai/internal/config"
	"github.com/tmy7533018/mugen-ai/internal/history"
	"github.com/tmy7533018/mugen-ai/internal/mcp"
	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/state"
	"github.com/tmy7533018/mugen-ai/internal/store"
	"github.com/tmy7533018/mugen-ai/internal/tools"
)

// toolingSystemPrompt is prepended to the user's personality prompt so the
// model knows the rules around calling shell tools. Centralising the
// conventions here lets each tool's description stay short.
const toolingSystemPrompt = `You can control the mugen-shell desktop through function-calling tools.

How to handle tool results:
- Tool results are diagnostic strings (JSON, IDs, status codes, paths, error text). NEVER paste them back to the user verbatim. Read what happened, then reply in your own natural conversational style. Phrases like "{toggled:true}" or "panel_open returned success" do not belong in a reply to the user.
- When a result starts with "error:" the action did NOT happen. Stop and tell the user in plain language what failed and why. Don't claim success, don't silently retry, and don't quietly pivot to another tool without acknowledging the failure first.
- For errors mentioning "disabled in [tools].disabled_categories": the user turned off that whole tool category. Tell them clearly which category is off, then immediately call panel_open(name="settings") so the Settings panel pops up at AI / Yura → Tool categories. After that you may suggest a workaround if one fits.
- For errors mentioning "app launcher allowlist": the binary isn't on the user's allowed list. The error includes the current allowed apps — if one of them is plausibly the same app under a different name (e.g. user said "zenbrowser" / "zen ブラウザ" but the allowed entry is "zen-bin"), retry app_launch with that binary instead of giving up. Otherwise tell the user the app isn't allowed and call panel_open(name="settings") so they can enable it via AI / Yura → Allowed apps.
- For errors mentioning "shell metacharacters": cmd contained ; | & $ etc. and was blocked for safety. Tell the user the command was blocked and don't retry with a "creative" variant.
- General rule: whenever you direct the user to Settings → AI / Yura → X, open the panel for them in the same turn by calling panel_open(name="settings"). The Settings panel is safe to open and saves the user a click.

When to act:
- Tools marked "[DESTRUCTIVE]" (and app_launch for unfamiliar commands) need plain-language confirmation first: describe what you are about to do, wait for the user's explicit "yes" in their next message, and only then call the tool. Never call a destructive tool on the same turn as the request.
- Tools marked "[CONFIRM]" reach external services with irreversible effects (sending a message, creating an issue). Calling one opens an approval dialog the user accepts or rejects directly, so you do NOT wait a turn for a verbal "yes": briefly state what you are about to do, then call the tool in the same turn and let the dialog handle consent. If the result says the user declined, acknowledge it plainly and do not retry.
- Read-only and reversible tools (read*, get*, list*, toggle, music, theme/wallpaper switching, panel open) fire immediately when the user asks.
- Power actions (lock / suspend / logout / reboot / shutdown) are intentionally NOT exposed as tools. If the user asks for one, tell them to use the Power Menu directly.

Long-term memory:
- You have persistent memory across conversations via memory_save / memory_list / memory_delete; everything saved is shown to you each turn under "Long-term memory".
- When the user shares a durable fact, preference, or standing instruction — or explicitly asks you to remember something — call memory_save with one concise sentence. Phrase it in third person about the user (e.g. "User's favorite editor is neovim"), not first person. Skip one-off or transient details, and never save secrets (passwords, API keys, tokens).
- When the user asks you to forget or correct something, memory_delete the outdated entry (ids are shown in your memory list and by memory_list); save the corrected fact afterwards if one replaces it.`

type runtimeContext struct {
	Cfg      config.Config
	Model    string
	Registry *provider.Registry
	Store    *store.Store
	History  *history.History
	Tools    *tools.Registry
	MCP      *mcp.Manager
}

// loadRuntimeContext is the shared `serve` / `chat` bootstrap. Caller closes rt.Store.
func loadRuntimeContext(modelOverride, systemOverride string) (*runtimeContext, error) {
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "warning: config load failed, using defaults: %v\n", err)
		cfg = config.Default()
	}

	model := modelOverride
	if model == "" {
		model = state.LoadModel()
	}
	persona := systemOverride
	if persona == "" {
		persona = assemblePersona(cfg.Personality)
	}

	// Disabled tool categories are surfaced explicitly: filtering them out of
	// List() saves tokens, but the model never realises they exist, so it
	// "successfully" pivots to a different tool without telling the user. A
	// short note makes Yura proactively explain that <category> is off.
	tooling := toolingSystemPrompt
	if len(cfg.Tools.DisabledCategories) > 0 {
		tooling += "\n\nCurrently disabled tool categories: " + strings.Join(cfg.Tools.DisabledCategories, ", ") +
			". If the user asks for something in one of these categories, tell them the category is off and point them at Settings → AI / Yura → Tool categories before doing anything else (no silent pivot to another tool)."
	}

	var system string
	if persona != "" {
		system = tooling + "\n\n" + persona
	} else {
		system = tooling
	}

	registry := buildRegistry(cfg, model)
	if model == "" {
		if models, _ := registry.Models(context.Background()); len(models) > 0 {
			model = models[0]
			registry.SetModel(model)
		}
	}

	stateDir := stateBaseDir()

	st, err := store.Open(filepath.Join(stateDir, "history.db"))
	if err != nil {
		return nil, fmt.Errorf("open history store: %w", err)
	}

	// Retention: drop conversations idle longer than retain_days before the
	// history layer loads, so a pruned-away current pointer self-heals.
	if cfg.History.RetainDays > 0 {
		cutoff := time.Now().AddDate(0, 0, -cfg.History.RetainDays).Unix()
		if n, err := st.PruneConversationsOlderThan(cutoff); err != nil {
			fmt.Fprintf(os.Stderr, "history: prune failed: %v\n", err)
		} else if n > 0 {
			fmt.Fprintf(os.Stderr, "history: pruned %d conversation(s) older than %d days\n", n, cfg.History.RetainDays)
		}
	}

	hist, err := history.New(st, system)
	if err != nil {
		st.Close()
		return nil, fmt.Errorf("init history: %w", err)
	}

	toolReg := tools.New(
		cfg.Shell.QsConfig,
		resolveScriptsDir(cfg.Shell.ScriptsDir),
		cfg.Tools.AppLaunch.AllowedCommands,
		cfg.Tools.DisabledCategories,
		tools.NewAuditor(filepath.Join(stateDir, "audit.log")),
	)

	toolReg.AttachMemory(st)

	// Spawn any configured MCP servers and merge their tools in. Connect
	// never fails outright — a broken server is logged and skipped — so the
	// returned Manager is always safe to attach and to Close later.
	mcpMgr := mcp.Connect(context.Background(), mcpServerConfigs(cfg.MCP))
	toolReg.AttachMCP(mcpMgr, trustedMCPServers(cfg.MCP))

	return &runtimeContext{
		Cfg:      cfg,
		Model:    model,
		Registry: registry,
		Store:    st,
		History:  hist,
		Tools:    toolReg,
		MCP:      mcpMgr,
	}, nil
}

// trustedMCPServers is the set of server names the user marked trusted —
// their destructive tools skip the per-call approval prompt.
func trustedMCPServers(c config.MCP) map[string]bool {
	trusted := map[string]bool{}
	for name, s := range c.Servers {
		if s.Trusted {
			trusted[name] = true
		}
	}
	return trusted
}

// mcpServerConfigs adapts the config-file shape to the mcp package's own
// ServerConfig so that package needn't import internal/config.
func mcpServerConfigs(c config.MCP) map[string]mcp.ServerConfig {
	if len(c.Servers) == 0 {
		return nil
	}
	out := make(map[string]mcp.ServerConfig, len(c.Servers))
	for name, s := range c.Servers {
		out[name] = mcp.ServerConfig{
			Command:  s.Command,
			Args:     s.Args,
			Env:      expandEnv(s.Env),
			Disabled: s.Disabled,
		}
	}
	return out
}

// expandEnv resolves ${VAR} / $VAR references in MCP server env values
// against mugen-ai's own environment, so a secret can be kept in the real
// environment instead of stored in plaintext in config.toml. A value with
// no reference is passed through unchanged.
func expandEnv(in map[string]string) map[string]string {
	if len(in) == 0 {
		return in
	}
	out := make(map[string]string, len(in))
	for k, v := range in {
		out[k] = os.Expand(v, os.Getenv)
	}
	return out
}

func resolveScriptsDir(configured string) string {
	if configured != "" {
		return configured
	}
	xdg := os.Getenv("XDG_CONFIG_HOME")
	if xdg == "" {
		home, _ := os.UserHomeDir()
		xdg = filepath.Join(home, ".config")
	}
	return filepath.Join(xdg, "quickshell", "mugen-shell", "scripts")
}

func buildRegistry(cfg config.Config, model string) *provider.Registry {
	providers := []provider.Provider{
		provider.NewOllama(cfg.Provider.Ollama.Host),
	}
	googleModels := cfg.Provider.Google.Models
	if len(googleModels) == 0 && cfg.Provider.Google.Model != "" {
		googleModels = []string{cfg.Provider.Google.Model}
	}
	if len(googleModels) > 0 {
		key := os.Getenv("GEMINI_API_KEY")
		if key == "" {
			key = os.Getenv("GOOGLE_API_KEY")
		}
		if key != "" {
			providers = append(providers, provider.NewGoogle(key, googleModels))
		}
	}
	openaiKey := os.Getenv("OPENAI_API_KEY")
	if openaiKey != "" || cfg.Provider.OpenAI.BaseURL != "" {
		providers = append(providers, provider.NewOpenAI(
			cfg.Provider.OpenAI.BaseURL,
			openaiKey,
			cfg.Provider.OpenAI.Models,
		))
	}
	anthropicKey := os.Getenv("ANTHROPIC_API_KEY")
	if anthropicKey != "" {
		providers = append(providers, provider.NewAnthropic(
			anthropicKey,
			cfg.Provider.Anthropic.Models,
		))
	}
	return provider.NewRegistry(model, providers...)
}

// assemblePersona prepends an auto-built header (name/tone/language) to the
// user's free-form SystemPrompt. Name defaults to "Yura" when empty so the
// assistant always has an identity; Tone and Language only contribute their
// line when set, and an entirely-empty Personality returns SystemPrompt as-is.
func assemblePersona(p config.Personality) string {
	if p.Name == "" && p.Tone == "" && p.Language == "" {
		return p.SystemPrompt
	}
	name := p.Name
	if name == "" {
		name = "Yura"
	}
	var lines []string
	if p.Tone != "" {
		lines = append(lines, fmt.Sprintf("You are %s, a %s desktop assistant for mugen-shell.", name, p.Tone))
	} else {
		lines = append(lines, fmt.Sprintf("You are %s, a desktop assistant for mugen-shell.", name))
	}
	// Yura's visual identity is a luminous orb — pin gender-neutral pronouns
	// so models don't default to "俺/僕" in Japanese even under casual tone.
	// Skip this for custom names where the user has redefined the persona.
	if name == "Yura" {
		lines = append(lines, "You appear as a luminous orb of light and have no gender. Your first-person pronoun is わたし in Japanese (never 俺, 僕, or あたし) and I in English. This identity rule overrides any casual tone.")
	}
	if p.Language != "" {
		lines = append(lines, fmt.Sprintf("Respond in %s.", p.Language))
	}
	header := strings.Join(lines, "\n")
	if p.SystemPrompt == "" {
		return header
	}
	return header + "\n\n" + p.SystemPrompt
}

func stateBaseDir() string {
	d := os.Getenv("XDG_STATE_HOME")
	if d == "" {
		home, _ := os.UserHomeDir()
		d = filepath.Join(home, ".local", "state")
	}
	return filepath.Join(d, "mugen-ai")
}
