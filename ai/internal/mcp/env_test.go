package mcp

import (
	"strings"
	"testing"
)

// A stdio server used to inherit the whole environment, provider API keys included.
func TestEnvWithoutSecretsDropsKeys(t *testing.T) {
	t.Setenv("ANTHROPIC_API_KEY", "sk-secret")
	t.Setenv("GEMINI_API_KEY", "g-secret")
	t.Setenv("GITHUB_TOKEN", "gh-secret")
	t.Setenv("PATH", "/usr/bin")

	var sawPath bool
	for _, kv := range envWithoutSecrets() {
		name, value, _ := strings.Cut(kv, "=")
		if strings.Contains(value, "secret") {
			t.Errorf("%s leaked into the child environment", name)
		}
		if name == "PATH" {
			sawPath = true
		}
	}
	if !sawPath {
		t.Error("PATH must still reach the child")
	}
}
