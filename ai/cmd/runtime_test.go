package cmd

import (
	"context"
	"testing"

	"github.com/tmy7533018/mugen-ai/internal/config"
)

// Only the key should decide whether a provider is offered: leaving [provider.google].models
// out is documented as "use the provider's default model", same as anthropic.
func googleOnlyConfig() config.Config {
	cfg := config.Default()
	// Port 1 is closed, so the ollama probe fails at once instead of finding a real daemon.
	cfg.Provider.Ollama.Host = "http://127.0.0.1:1"
	return cfg
}

func offeredModels(t *testing.T, cfg config.Config) []string {
	t.Helper()
	registry, _ := buildRegistry(cfg, "")
	models, err := registry.Models(context.Background())
	if err != nil {
		t.Fatalf("Models: %v", err)
	}
	return models
}

func TestGoogleIsOfferedWithoutExplicitModels(t *testing.T) {
	t.Setenv("GEMINI_API_KEY", "test-key")
	t.Setenv("GOOGLE_API_KEY", "")
	t.Setenv("ANTHROPIC_API_KEY", "")
	t.Setenv("OPENAI_API_KEY", "")

	if models := offeredModels(t, googleOnlyConfig()); len(models) != 1 {
		t.Fatalf("want the google default model, got %v", models)
	}
}

func TestGoogleFallsBackToGoogleAPIKey(t *testing.T) {
	t.Setenv("GEMINI_API_KEY", "")
	t.Setenv("GOOGLE_API_KEY", "fallback-key")
	t.Setenv("ANTHROPIC_API_KEY", "")
	t.Setenv("OPENAI_API_KEY", "")

	if models := offeredModels(t, googleOnlyConfig()); len(models) != 1 {
		t.Fatalf("want the google default model, got %v", models)
	}
}

func TestGoogleStaysOffWithoutAKey(t *testing.T) {
	t.Setenv("GEMINI_API_KEY", "")
	t.Setenv("GOOGLE_API_KEY", "")
	t.Setenv("ANTHROPIC_API_KEY", "")
	t.Setenv("OPENAI_API_KEY", "")

	if models := offeredModels(t, googleOnlyConfig()); len(models) != 0 {
		t.Fatalf("want no models offered, got %v", models)
	}
}
