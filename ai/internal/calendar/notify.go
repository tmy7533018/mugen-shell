package calendar

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// All-day events have no minute to match, so they fire once the morning is up.
const allDayFireTime = "08:00"

// A run after suspend still fires what the sleep crossed, without unloading a whole morning at once.
const missedEventGrace = 30 * time.Minute

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
	currentHM := now.Format("15:04")

	store, err := Open("")
	if err != nil {
		return nil
	}
	defer store.Close()

	events, err := store.notifyCandidates(now.Add(-missedEventGrace), now)
	if err != nil {
		return nil
	}

	var added []string
	for _, e := range events {
		if e.ID == "" || e.Title == "" {
			continue
		}
		key := e.Date + ":" + e.ID
		if fired[key] {
			continue
		}

		switch {
		case e.Time != "" && e.dueAt(now):
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

type notifyCandidate struct {
	Event
	lastWritten int64
}

func (s *Store) notifyCandidates(from, to time.Time) ([]notifyCandidate, error) {
	rows, err := s.db.Query("SELECT id, date, time, title, MAX(created_at, modified_at) FROM events WHERE date >= ? AND date <= ? "+orderClause,
		from.Format("2006-01-02"), to.Format("2006-01-02"))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []notifyCandidate
	for rows.Next() {
		var c notifyCandidate
		if err := rows.Scan(&c.ID, &c.Date, &c.Time, &c.Title, &c.lastWritten); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// An event written after its own minute was never pending, so the grace does not apply to it.
func (c notifyCandidate) dueAt(now time.Time) bool {
	due, err := time.ParseInLocation("2006-01-02 15:04", c.Date+" "+c.Time, now.Location())
	if err != nil {
		return false
	}
	age := now.Sub(due)
	return age >= 0 && age <= missedEventGrace && c.lastWritten < due.Add(time.Minute).Unix()
}

// Reported to the journal: a silent failure here is a notification the user never learns was due.
func send(summary, body string) {
	out, err := exec.Command("notify-send", "-a", "mugen-shell",
		"-i", "x-office-calendar", summary, body).CombinedOutput()
	if err != nil {
		fmt.Fprintf(os.Stderr, "notify-send: %v: %s\n", err, out)
	}
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
