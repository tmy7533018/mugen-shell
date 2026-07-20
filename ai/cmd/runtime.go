package cmd

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/tmy7533018/mugen-ai/internal/config"
	"github.com/tmy7533018/mugen-ai/internal/history"
	"github.com/tmy7533018/mugen-ai/internal/mcp"
	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/state"
	"github.com/tmy7533018/mugen-ai/internal/store"
	"github.com/tmy7533018/mugen-ai/internal/toolfilter"
	"github.com/tmy7533018/mugen-ai/internal/tools"
)

// Centralising the tool-calling conventions here lets each individual tool's
// description stay short.
const toolingSystemPrompt = `You can control the mugen-shell desktop through function-calling tools.

How to handle tool results:
- Tool results are diagnostic strings (JSON, IDs, status codes, paths, error text). NEVER paste them back to the user verbatim. Read what happened, then reply in your own natural conversational style. Phrases like "{toggled:true}" or "panel_open returned success" do not belong in a reply to the user.
- When a result starts with "error:" the action did NOT happen. Stop and tell the user in plain language what failed and why. Don't claim success, don't silently retry, and don't quietly pivot to another tool without acknowledging the failure first.
- For errors mentioning "disabled in [tools].disabled_categories": the user turned off that whole tool category. Tell them clearly which category is off, then immediately call panel_open(name="settings") so the Settings panel pops up at AI / Yura → Tool categories. After that you may suggest a workaround if one fits.
- For errors mentioning "app launcher allowlist": the binary isn't on the user's allowed list. The error includes the current allowed apps — if one of them is plausibly the same app under a different name (e.g. user said "zenbrowser" / "zen ブラウザ" but the allowed entry is "zen-bin"), retry app_launch with that binary instead of giving up. Otherwise tell the user the app isn't allowed and call panel_open(name="settings") so they can enable it via AI / Yura → Allowed apps.
- For errors mentioning "shell metacharacters": cmd contained ; | & $ etc. and was blocked for safety. Tell the user the command was blocked and don't retry with a "creative" variant.
- General rule: whenever you direct the user to Settings → AI / Yura → X, open the panel for them in the same turn by calling panel_open(name="settings"). The Settings panel is safe to open and saves the user a click.

When to act:
- Prefer doing over describing: when a visible tool can fulfil the request, call it — don't explain how the user could do it themselves, and don't ask whether you should proceed (except for the confirmation rules below).
- Never announce without acting: if your reply says or implies you are about to do something ("ちょっと待ってて", "I'll open it now"), the tool call MUST be in that same reply. A text-only promise ends the turn and nothing happens.
- Call immediate tools silently: when a tool fires right away (read-only, reversible, allowlisted app launch), attach NO text to the tool call — no "ちょっと待ってて", no "opening it now". The result arrives within a second, so wait-filler renders together with your completion message and reads as a broken play-by-play ("開くね。待ってて。開いたよ。"). Say everything in ONE short reply after the tool result, and never claim "開いたよ" / "done" before that result confirms it. (The [CONFIRM] and [DESTRUCTIVE] rules below take precedence for those tools.)
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
	// Filter is nil when [tools.context_filter] is disabled.
	Filter *toolfilter.Filter
}

// Caller closes rt.Store.
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

	// Filtering disabled categories out of List() saves tokens, but then the
	// model never realises they exist and silently pivots to another tool
	// instead of telling the user the category is off.
	tooling := toolingSystemPrompt
	if len(cfg.Tools.DisabledCategories) > 0 {
		tooling += "\n\nCurrently disabled tool categories: " + strings.Join(cfg.Tools.DisabledCategories, ", ") +
			". If the user asks for something in one of these categories, tell them the category is off and point them at Settings → AI / Yura → Tool categories before doing anything else (no silent pivot to another tool)."
	}
	// Without this note a filtered turn makes the model under-report what it
	// can do ("I have no wallpaper tools") instead of realising the visible
	// list is per-turn.
	if cfg.Tools.ContextFilter.Enabled {
		if caps := enabledCapabilities(cfg); caps != "" {
			tooling += "\n\nTool visibility: for efficiency you may be shown only the tools relevant to the current message. Your full capabilities cover: " + caps +
				". If the user asks what you can do, describe that full set even when only a few tools are visible this turn."
		}
	}

	var system string
	if persona != "" {
		system = tooling + "\n\n" + persona
	} else {
		system = tooling
	}

	registry, ollamaProvider := buildRegistry(cfg, model)
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

	// Must prune before the history layer loads, so a pruned-away current
	// pointer self-heals.
	if cfg.History.RetainDays > 0 {
		cutoff := time.Now().AddDate(0, 0, -cfg.History.RetainDays).Unix()
		if n, err := st.PruneConversationsOlderThan(cutoff); err != nil {
			fmt.Fprintf(os.Stderr, "history: prune failed: %v\n", err)
		} else if n > 0 {
			fmt.Fprintf(os.Stderr, "history: pruned %d conversation(s) older than %d days\n", n, cfg.History.RetainDays)
		}
	}

	hist, err := history.New(st, system, cfg.History.MaxContextTokens)
	if err != nil {
		st.Close()
		return nil, fmt.Errorf("init history: %w", err)
	}

	// Empty path → nil auditor → every Log() call is a no-op.
	auditPath := ""
	if cfg.Logging.Audit {
		auditPath = filepath.Join(stateDir, "audit.log")
	}
	toolReg := tools.New(
		cfg.Shell.QsConfig,
		resolveScriptsDir(cfg.Shell.ScriptsDir),
		cfg.Tools.AppLaunch.AllowedCommands,
		cfg.Tools.DisabledCategories,
		tools.NewAuditor(auditPath),
	)

	toolReg.AttachMemory(st)
	toolReg.AttachWeather(cfg.Weather.Place)

	// Connect never fails outright — a broken server is logged and skipped —
	// so the returned Manager is always safe to attach and to Close later.
	mcpMgr := mcp.Connect(context.Background(), mcpServerConfigs(cfg.MCP))
	toolReg.AttachMCP(mcpMgr, trustedMCPServers(cfg.MCP))

	// Category vectors warm lazily on the first turn that actually needs them,
	// so cloud-only users never spawn a doomed embed call against a
	// non-running Ollama.
	var filter *toolfilter.Filter
	if fc := cfg.Tools.ContextFilter; fc.Enabled {
		var embed toolfilter.EmbedFunc
		if fc.EmbedModel != "" {
			embedModel := fc.EmbedModel
			embed = func(ctx context.Context, texts []string) ([][]float32, error) {
				return ollamaProvider.Embed(ctx, embedModel, texts)
			}
		}
		filter = toolfilter.New(toolfilter.Config{
			TopK:          fc.TopK,
			MinScore:      fc.MinScore,
			AlwaysInclude: fc.AlwaysInclude,
		}, embed)
	}

	return &runtimeContext{
		Cfg:      cfg,
		Model:    model,
		Registry: registry,
		Store:    st,
		History:  hist,
		Tools:    toolReg,
		MCP:      mcpMgr,
		Filter:   filter,
	}, nil
}

// Destructive tools from a trusted server skip the per-call approval prompt.
func trustedMCPServers(c config.MCP) map[string]bool {
	trusted := map[string]bool{}
	for name, s := range c.Servers {
		if s.Trusted {
			trusted[name] = true
		}
	}
	return trusted
}

// Adapts to the mcp package's own ServerConfig so that package needn't import
// internal/config.
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
			URL:      s.URL,
			Disabled: s.Disabled,
		}
	}
	return out
}

// Resolving ${VAR} against mugen-ai's own environment lets a secret stay in
// the environment instead of being stored in plaintext in config.toml.
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

// Returns the Ollama provider separately because the tool context filter
// needs its Embed method, which is not part of the Provider interface.
func buildRegistry(cfg config.Config, model string) (*provider.Registry, *provider.Ollama) {
	ollama := provider.NewOllama(cfg.Provider.Ollama.Host, cfg.Provider.Ollama.NumCtx, cfg.Provider.Ollama.KeepAlive)
	providers := []provider.Provider{ollama}
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
			cfg.Provider.Anthropic.MaxTokens,
			cfg.Provider.Anthropic.ThinkingBudget,
		))
	}
	return provider.NewRegistry(model, providers...), ollama
}

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
	// Pin gender-neutral pronouns so models don't default to "俺/僕" in
	// Japanese under a casual tone. Only for Yura: a custom name means the
	// user has redefined the persona.
	if name == "Yura" {
		lines = append(lines, "You appear as a luminous orb of light and have no gender. Your first-person pronoun is わたし in Japanese (never 俺, 僕, or あたし) and I in English. This identity rule overrides any casual tone.")
	}
	if p.Language != "" {
		lines = append(lines, fmt.Sprintf("Respond in %s.", p.Language))
	} else {
		// Stated explicitly because small local models drift to
		// English/Chinese without an anchor.
		lines = append(lines, "Respond in the language the user writes in.")
	}
	header := strings.Join(lines, "\n")
	if p.SystemPrompt == "" {
		return header
	}
	return header + "\n\n" + p.SystemPrompt
}

var builtinCapabilities = []struct{ cat, phrase string }{
	{"audio", "audio and mic volume"},
	{"music", "music playback"},
	{"panel", "shell panels"},
	{"brightness", "brightness"},
	{"theme", "theme"},
	{"wallpaper", "wallpaper"},
	{"notification", "notifications and DnD"},
	{"timer", "timers"},
	{"calendar", "calendar"},
	{"app", "app launching"},
	{"memory", "long-term memory"},
	{"weather", "weather"},
}

// An MCP server's name is its tool category. Returns "" when everything is
// disabled.
func enabledCapabilities(cfg config.Config) string {
	disabled := map[string]bool{}
	for _, c := range cfg.Tools.DisabledCategories {
		disabled[strings.ToLower(strings.TrimSpace(c))] = true
	}
	var parts []string
	for _, bc := range builtinCapabilities {
		if !disabled[bc.cat] {
			parts = append(parts, bc.phrase)
		}
	}
	names := make([]string, 0, len(cfg.MCP.Servers))
	for name := range cfg.MCP.Servers {
		names = append(names, name)
	}
	sort.Strings(names)
	for _, name := range names {
		s := cfg.MCP.Servers[name]
		if !s.Disabled && !disabled[strings.ToLower(name)] {
			parts = append(parts, name)
		}
	}
	return strings.Join(parts, ", ")
}

func stateBaseDir() string {
	d := os.Getenv("XDG_STATE_HOME")
	if d == "" {
		home, _ := os.UserHomeDir()
		d = filepath.Join(home, ".local", "state")
	}
	return filepath.Join(d, "mugen-ai")
}
