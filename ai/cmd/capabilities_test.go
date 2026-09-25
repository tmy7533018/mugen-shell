package cmd

import (
	"strings"
	"testing"

	"github.com/tmy7533018/mugen-ai/internal/config"
)

func TestCapabilitiesLeaveOutServersConnectRefuses(t *testing.T) {
	cfg := config.Default()
	cfg.MCP.Servers = map[string]config.MCPServer{
		"github": {Command: "gh-mcp"},
		"my.srv": {Command: "x"},
		"off":    {Command: "x", Disabled: true},
	}
	got := enabledCapabilities(cfg)
	if !strings.Contains(got, "github") {
		t.Errorf("capabilities %q should name the valid server", got)
	}
	for _, name := range []string{"my.srv", "off"} {
		if strings.Contains(got, name) {
			t.Errorf("capabilities %q should not name %q", got, name)
		}
	}
}
