package config

import (
	"os"
	"path/filepath"

	"github.com/BurntSushi/toml"
)

type Config struct {
	Personality Personality `toml:"personality"`
	Context     Context     `toml:"context"`
	Provider    Provider    `toml:"provider"`
}

type Personality struct {
	SystemPrompt string `toml:"system_prompt"`
}

type Context struct {
	Locale string `toml:"locale"`
	City   string `toml:"city"`
}

type Provider struct {
	Ollama Ollama `toml:"ollama"`
	Google Google `toml:"google"`
	OpenAI OpenAI `toml:"openai"`
}

type Ollama struct {
	Host string `toml:"host"`
}

type Google struct {
	Model string `toml:"model"`
}

// OpenAI covers any provider that speaks the OpenAI Chat Completions API:
// OpenAI itself, OpenRouter, LM Studio, vLLM, LiteLLM, etc. The API key is
// loaded from OPENAI_API_KEY (left empty for local servers that don't need
// one). Models is optional — if empty, the provider asks /v1/models.
type OpenAI struct {
	BaseURL string   `toml:"base_url"`
	Models  []string `toml:"models"`
}

func Default() Config {
	return Config{
		Personality: Personality{
			SystemPrompt: "You are a helpful desktop assistant. Be concise.",
		},
		Context: Context{
			Locale: "en",
		},
		Provider: Provider{
			Ollama: Ollama{Host: "http://localhost:11434"},
		},
	}
}

func Load() (Config, error) {
	cfg := Default()
	path := filePath()

	if _, err := os.Stat(path); os.IsNotExist(err) {
		if err := writeDefault(path, cfg); err != nil {
			return cfg, err
		}
		return cfg, nil
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

func writeDefault(path string, cfg Config) error {
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	return toml.NewEncoder(f).Encode(cfg)
}
