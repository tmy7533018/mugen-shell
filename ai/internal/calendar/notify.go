package calendar

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// All-day events have no minute to match, so they fire once the morning is up.
const allDayFireTime = "08:00"

const firedRetention = 7 * 24 * time.Hour

func stateHome() string {
	if dir := os.Getenv("XDG_STATE_HOME"); dir != "" {
		return dir
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ".local/state"
	}
	return filepath.Join(home, ".local", "state")
}

func firedPath() string {
	return filepath.Join(stateHome(), "mugen-shell", "notified.json")
}

type firedState struct {
	Fired []string `json:"fired"`
}

// Notify fires a desktop notification for each of today's events whose moment
// has come, and records them so a later run does not repeat one.
func Notify(now time.Time) error {
	fired := loadFired()
	today := now.Format("2006-01-02")
	currentHM := now.Format("15:04")

	store, err := Open("")
	if err != nil {
		return nil
	}
	defer store.Close()

	events, err := store.ListToday()
	if err != nil {
		return nil
	}

	var added []string
	for _, e := range events {
		if e.ID == "" || e.Title == "" {
			continue
		}
		key := today + ":" + e.ID
		if fired[key] {
			continue
		}

		switch {
		case e.Time != "" && e.Time == currentHM:
			send("Mugen Calendar", e.Time+" — "+e.Title)
			added = append(added, key)
		case e.Time == "" && currentHM >= allDayFireTime:
			send("Mugen Calendar", "Today — "+e.Title)
			added = append(added, key)
		}
	}

	if len(added) == 0 {
		return nil
	}
	for _, key := range added {
		fired[key] = true
	}
	return saveFired(pruneFired(fired, now))
}

func send(summary, body string) {
	exec.Command("notify-send", "-a", "mugen-shell", "-i", "x-office-calendar", summary, body).Run()
}

func loadFired() map[string]bool {
	out := map[string]bool{}
	raw, err := os.ReadFile(firedPath())
	if err != nil {
		return out
	}
	var state firedState
	if json.Unmarshal(raw, &state) != nil {
		return out
	}
	for _, key := range state.Fired {
		out[key] = true
	}
	return out
}

func pruneFired(fired map[string]bool, now time.Time) map[string]bool {
	cutoff := now.Add(-firedRetention)
	kept := map[string]bool{}
	for key := range fired {
		date, _, found := strings.Cut(key, ":")
		if !found {
			continue
		}
		when, err := time.ParseInLocation("2006-01-02", date, now.Location())
		if err != nil || when.Before(cutoff) {
			continue
		}
		kept[key] = true
	}
	return kept
}

func saveFired(fired map[string]bool) error {
	keys := make([]string, 0, len(fired))
	for key := range fired {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	path := firedPath()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	raw, err := json.Marshal(firedState{Fired: keys})
	if err != nil {
		return err
	}
	return os.WriteFile(path, raw, 0o644)
}
