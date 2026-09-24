package calendar

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func fakeNotifySend(t *testing.T) string {
	t.Helper()
	bin := t.TempDir()
	log := filepath.Join(bin, "notify.log")
	script := "#!/bin/sh\necho \"$@\" >> " + log + "\n"
	if err := os.WriteFile(filepath.Join(bin, "notify-send"), []byte(script), 0o755); err != nil {
		t.Fatalf("write fake notify-send: %v", err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	return log
}

func readLog(t *testing.T, path string) string {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return ""
		}
		t.Fatalf("read log: %v", err)
	}
	return string(raw)
}

func TestNotifyFiresAtPaddedTime(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	log := fakeNotifySend(t)

	st, err := Open("")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	today := time.Now().Format("2006-01-02")
	if _, err := st.Add(today, "9:00", "nine"); err != nil {
		t.Fatalf("add: %v", err)
	}
	st.Close()

	now := time.Now()
	at := func(h, m int) time.Time {
		return time.Date(now.Year(), now.Month(), now.Day(), h, m, 0, 0, now.Location())
	}

	if err := Notify(at(8, 59)); err != nil {
		t.Fatalf("notify before due time: %v", err)
	}
	if got := readLog(t, log); got != "" {
		t.Fatalf("notified before the event's time: %q", got)
	}

	if err := Notify(at(9, 0)); err != nil {
		t.Fatalf("notify at due time: %v", err)
	}
	got := readLog(t, log)
	if !strings.Contains(got, "09:00") || !strings.Contains(got, "nine") {
		t.Fatalf("notify-send argv = %q, want it to mention 09:00 and nine", got)
	}

	if err := Notify(at(9, 1)); err != nil {
		t.Fatalf("notify after due time: %v", err)
	}
	if got2 := readLog(t, log); got2 != got {
		t.Fatalf("notified again after already firing: %q", got2)
	}
}
