package calendar

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// The timer's catch-up runs at login, before the shell that serves notifications is up.
func TestNotifyRetriesWhatTheNotificationServerWasNotUpFor(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	bin := t.TempDir()
	log := filepath.Join(bin, "notify.log")
	up := filepath.Join(bin, "up")
	script := "#!/bin/sh\n[ -e " + up + " ] || exit 1\necho \"$@\" >> " + log + "\n"
	if err := os.WriteFile(filepath.Join(bin, "notify-send"), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))

	st, err := Open("")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	today := time.Now().Format("2006-01-02")
	if _, err := st.Add(today, "9:00", "timed"); err != nil {
		t.Fatalf("add: %v", err)
	}
	if _, err := st.Add(today, "", "allday"); err != nil {
		t.Fatalf("add: %v", err)
	}
	if _, err := st.db.Exec("UPDATE events SET created_at = 0, modified_at = 0"); err != nil {
		t.Fatalf("backdate: %v", err)
	}
	st.Close()

	now := time.Now()
	at := func(m int) time.Time {
		return time.Date(now.Year(), now.Month(), now.Day(), 9, m, 0, 0, now.Location())
	}

	if err := Notify(at(0)); err != nil {
		t.Fatalf("notify while the server is down: %v", err)
	}
	if err := os.WriteFile(up, nil, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := Notify(at(1)); err != nil {
		t.Fatalf("notify once it is up: %v", err)
	}
	if err := Notify(at(2)); err != nil {
		t.Fatalf("notify a minute later: %v", err)
	}

	got := readLog(t, log)
	for _, title := range []string{"timed", "allday"} {
		if n := strings.Count(got, title); n != 1 {
			t.Errorf("%s fired %d times, want once: %q", title, n, got)
		}
	}
}
