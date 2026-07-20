package tools

import (
	"context"
	"fmt"
	"strings"
	"testing"
)

// Canned per-endpoint results, so the gather + format path runs without
// subprocesses.
func desktopFakeRun(results map[string]string) func(context.Context, string, []string) (string, error) {
	return func(_ context.Context, name string, args []string) (string, error) {
		if name == "qs" && len(args) >= 2 && args[0] == "list" {
			return "Process ID: 42\n  Config path: /x/mugen-shell/shell.qml", nil
		}
		var key string
		if name == "qs" {
			// ipc --pid 42 call <target> <fn>
			if len(args) < 6 {
				return "", fmt.Errorf("unexpected qs args %v", args)
			}
			key = args[4] + "/" + args[5]
		} else if strings.HasSuffix(name, "calendar-cli.py") {
			key = "calendar"
		} else {
			return "", fmt.Errorf("unexpected exec %s", name)
		}
		out, ok := results[key]
		if !ok {
			return "", fmt.Errorf("no canned result for %s", key)
		}
		return out, nil
	}
}

func fullDesktopResults() map[string]string {
	return map[string]string{
		"window/active":         `{"app_id":"zen","title":"Some Page"}`,
		"music/now_playing":     `{"available":true,"status":"Playing","title":"Song","artist":"Artist"}`,
		"audio/get_volume":      "45",
		"notification/unread":   "3",
		"notification/get_dnd":  "false",
		"timer/get":             `{"running":true,"paused":false,"duration_sec":600,"remaining_sec":83,"alerting":false}`,
		"calendar":              `{"events":[{"id":"1","date":"2026-07-02","time":"14:00","title":"mtg"},{"id":"2","date":"2026-07-02","time":"","title":"errand"}]}`,
		"theme/get":             "dark",
	}
}

func TestDesktopContextGathersEverything(t *testing.T) {
	r, _, _ := newTestRegistry(t, nil, nil)
	r.run = desktopFakeRun(fullDesktopResults())

	out := r.DesktopContext(context.Background())
	for _, want := range []string{
		"- time: ",
		`active window: zen — "Some Page"`,
		`music: playing "Song" by Artist`,
		"volume: 45%",
		"notifications: 3 unread",
		"timer: 1m23s remaining",
		`calendar today: 14:00 "mtg", all-day "errand"`,
		"theme: dark mode",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q in:\n%s", want, out)
		}
	}
	if strings.Contains(out, "do-not-disturb") {
		t.Errorf("dnd-off must not be mentioned:\n%s", out)
	}
}

func TestDesktopContextRespectsDisabledCategories(t *testing.T) {
	r, _, _ := newTestRegistry(t, nil, []string{"music", "calendar", "notification"})
	r.run = desktopFakeRun(fullDesktopResults())

	out := r.DesktopContext(context.Background())
	for _, banned := range []string{"music:", "calendar today:", "notifications:"} {
		if strings.Contains(out, banned) {
			t.Errorf("disabled category leaked %q in:\n%s", banned, out)
		}
	}
	if !strings.Contains(out, "active window: zen") {
		t.Errorf("ungated field should survive:\n%s", out)
	}
}

func TestDesktopContextEmptyWhenAllFail(t *testing.T) {
	r, _, _ := newTestRegistry(t, nil, nil)
	r.run = func(_ context.Context, _ string, _ []string) (string, error) {
		return "", fmt.Errorf("shell is down")
	}
	if out := r.DesktopContext(context.Background()); out != "" {
		t.Errorf("expected empty context when every gather fails, got:\n%s", out)
	}
}

func TestDesktopContextSkipsIdleStates(t *testing.T) {
	results := fullDesktopResults()
	results["music/now_playing"] = `{"available":true,"status":"Stopped","title":"Song","artist":"A"}`
	results["timer/get"] = `{"running":false,"paused":false,"duration_sec":0,"remaining_sec":0,"alerting":false}`
	results["calendar"] = `{"events":[]}`
	results["notification/get_dnd"] = "true"

	r, _, _ := newTestRegistry(t, nil, nil)
	r.run = desktopFakeRun(results)

	out := r.DesktopContext(context.Background())
	for _, banned := range []string{"music:", "timer:", "calendar today:"} {
		if strings.Contains(out, banned) {
			t.Errorf("idle state should be omitted, found %q in:\n%s", banned, out)
		}
	}
	if !strings.Contains(out, "notifications: 3 unread (do-not-disturb is on)") {
		t.Errorf("dnd-on must be mentioned:\n%s", out)
	}
}
