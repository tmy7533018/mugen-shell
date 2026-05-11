package cmd

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/tmy7533018/mugen-ai/internal/config"
	ctxinfo "github.com/tmy7533018/mugen-ai/internal/context"
	"github.com/tmy7533018/mugen-ai/internal/history"
	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/state"
	"github.com/tmy7533018/mugen-ai/internal/store"
	"github.com/tmy7533018/mugen-ai/internal/tools"
)

// toolingSystemPrompt is prepended to the user's personality prompt so the
// model knows the rules around calling shell tools. Confirmations are
// expected in plain language; we do not surface a confirmation UI.
const toolingSystemPrompt = `You can control the mugen-shell desktop through function-calling tools (audio, music, panel groups). Call read-only and reversible tools (reading volume, toggling music, opening a panel, switching theme) immediately when the user asks. For destructive or irreversible actions (deleting calendar events, clearing notifications, launching arbitrary apps, anything the user might regret), first describe what you are about to do in plain language and wait for the user's explicit confirmation in their next message; do not call the tool on the same turn as the request. Never call power-related tools — those are gated by a separate confirmation UI and are not exposed here yet.`

type runtimeContext struct {
	Cfg      config.Config
	Model    string
	Registry *provider.Registry
	Store    *store.Store
	History  *history.History
	Tools    *tools.Registry
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
	system := systemOverride
	if system == "" {
		system = cfg.Personality.SystemPrompt
	}
	// Always prepend tooling guidance so the model knows when to call
	// shell tools vs. ask first. Personality stays the user's domain.
	if system != "" {
		system = toolingSystemPrompt + "\n\n" + system
	} else {
		system = toolingSystemPrompt
	}

	registry := buildRegistry(cfg, model)
	if model == "" {
		if models, _ := registry.Models(context.Background()); len(models) > 0 {
			model = models[0]
			registry.SetModel(model)
		}
	}

	st, err := store.Open(historyDBPath())
	if err != nil {
		return nil, fmt.Errorf("open history store: %w", err)
	}

	hist, err := history.New(st, system)
	if err != nil {
		st.Close()
		return nil, fmt.Errorf("init history: %w", err)
	}
	hist.ContextFunc = func() string { return ctxinfo.Build(cfg.Context) }

	return &runtimeContext{
		Cfg:      cfg,
		Model:    model,
		Registry: registry,
		Store:    st,
		History:  hist,
		Tools:    tools.New(cfg.Shell.QsConfig),
	}, nil
}

func buildRegistry(cfg config.Config, model string) *provider.Registry {
	providers := []provider.Provider{
		provider.NewOllama(cfg.Provider.Ollama.Host),
	}
	if cfg.Provider.Google.Model != "" {
		key := os.Getenv("GEMINI_API_KEY")
		if key == "" {
			key = os.Getenv("GOOGLE_API_KEY")
		}
		if key != "" {
			providers = append(providers, provider.NewGoogle(key, cfg.Provider.Google.Model))
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

func historyDBPath() string {
	d := os.Getenv("XDG_STATE_HOME")
	if d == "" {
		home, _ := os.UserHomeDir()
		d = filepath.Join(home, ".local", "state")
	}
	return filepath.Join(d, "mugen-ai", "history.db")
}
