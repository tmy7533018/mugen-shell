package hypr

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"time"
)

type client struct {
	Address      string `json:"address"`
	Class        string `json:"class"`
	InitialClass string `json:"initialClass"`
}

var luaProviderRe = regexp.MustCompile(`(?m)^configProvider:\s*lua\s*$`)

// A Lua Hyprland config rejects the legacy dispatch string, so probe for it.
func usesLuaConfig(ctx context.Context) bool {
	if os.Getenv("HYPR_CONFIG_LUA") == "1" {
		return true
	}
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()

	out, err := exec.CommandContext(ctx, "hyprctl", "systeminfo").Output()
	if err != nil {
		return false
	}
	return luaProviderRe.Match(out)
}

func clients(ctx context.Context) []client {
	out, err := exec.CommandContext(ctx, "hyprctl", "clients", "-j").Output()
	if err != nil {
		return nil
	}
	var parsed []client
	if json.Unmarshal(out, &parsed) != nil {
		return nil
	}
	return parsed
}

// FocusOrLaunch raises the window matching desktopEntry, or starts it when none
// is open. Reports whether a matching window was focused.
func FocusOrLaunch(ctx context.Context, desktopEntry string) (bool, error) {
	term := strings.ToLower(strings.TrimSuffix(strings.ToLower(desktopEntry), ".desktop"))

	for _, c := range clients(ctx) {
		cls := strings.ToLower(c.Class)
		initial := strings.ToLower(c.InitialClass)

		if term == cls || term == initial ||
			// An empty class is a substring of everything, so it would swallow the match.
			(cls != "" && (strings.Contains(cls, term) || strings.Contains(term, cls))) ||
			(initial != "" && (strings.Contains(initial, term) || strings.Contains(term, initial))) {
			return true, focusWindow(ctx, c.Address)
		}
	}

	return false, launch(desktopEntry)
}

func focusWindow(ctx context.Context, address string) error {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	args := []string{"dispatch", "focuswindow", "address:" + address}
	if usesLuaConfig(ctx) {
		args = []string{"dispatch", fmt.Sprintf("hl.dsp.focus({ window = \"address:%s\" })", address)}
	}

	out, err := exec.CommandContext(ctx, "hyprctl", args...).Output()
	if err != nil {
		return err
	}
	// hyprctl exits 0 even when the dispatch is rejected, so the reply is the only signal.
	if reply := strings.TrimSpace(string(out)); reply != "ok" {
		return fmt.Errorf("focus rejected for %s: %s", address, reply)
	}
	return nil
}

// Detached so the app outlives the short-lived process that asked for it.
func launch(desktopEntry string) error {
	cmd := exec.Command("gtk-launch", desktopEntry)
	cmd.SysProcAttr = detachedAttr()
	return cmd.Start()
}
