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
	if _, err := st.db.Exec("UPDATE events SET created_at = 0, modified_at = 0"); err != nil {
		t.Fatalf("backdate: %v", err)
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

func TestNotifyUsesTheDayItWasGiven(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	log := fakeNotifySend(t)

	st, err := Open("")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	today := time.Date(2030, 6, 15, 0, 0, 0, 0, time.Local)
	if _, err := st.Add(today.Format("2006-01-02"), "", "all day"); err != nil {
		t.Fatalf("add: %v", err)
	}
	st.Close()

	if err := Notify(today.Add(-time.Second)); err != nil {
		t.Fatalf("notify on the previous day: %v", err)
	}
	if got := readLog(t, log); got != "" {
		t.Fatalf("fired on the day before: %q", got)
	}

	if err := Notify(today.Add(8 * time.Hour)); err != nil {
		t.Fatalf("notify at 08:00: %v", err)
	}
	if got := strings.Count(readLog(t, log), "all day"); got != 1 {
		t.Fatalf("fired %d times, want 1", got)
	}
}

var catchUpDay = time.Date(2030, 6, 15, 0, 0, 0, 0, time.Local)

func clock(h, m int) time.Time {
	return catchUpDay.Add(time.Duration(h)*time.Hour + time.Duration(m)*time.Minute)
}

func seedEvent(t *testing.T, date, eventTime, title string) {
	t.Helper()
	st, err := Open("")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer st.Close()
	if _, err := st.Add(date, eventTime, title); err != nil {
		t.Fatalf("add: %v", err)
	}
	if _, err := st.db.Exec("UPDATE events SET created_at = 0, modified_at = 0"); err != nil {
		t.Fatalf("backdate: %v", err)
	}
}

func notifySandbox(t *testing.T) string {
	t.Helper()
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	return fakeNotifySend(t)
}

func TestNotifyCatchesAnEventCrossedDuringSuspend(t *testing.T) {
	log := notifySandbox(t)
	seedEvent(t, "2030-06-15", "09:00", "standup")

	if err := Notify(clock(9, 20)); err != nil {
		t.Fatalf("notify: %v", err)
	}
	if got := strings.Count(readLog(t, log), "standup"); got != 1 {
		t.Fatalf("fired %d times on resume, want 1", got)
	}
	if err := Notify(clock(9, 21)); err != nil {
		t.Fatalf("notify: %v", err)
	}
	if got := strings.Count(readLog(t, log), "standup"); got != 1 {
		t.Fatalf("fired %d times after the next tick, want 1", got)
	}
}

func TestNotifyGraceWindowIsThirtyMinutes(t *testing.T) {
	for _, tc := range []struct {
		at   time.Time
		want int
	}{
		{clock(8, 59), 0},
		{clock(9, 0), 1},
		{clock(9, 30), 1},
		{clock(9, 31), 0},
	} {
		t.Run(tc.at.Format("15:04"), func(t *testing.T) {
			log := notifySandbox(t)
			seedEvent(t, "2030-06-15", "09:00", "standup")
			if err := Notify(tc.at); err != nil {
				t.Fatalf("notify: %v", err)
			}
			if got := strings.Count(readLog(t, log), "standup"); got != tc.want {
				t.Errorf("fired %d times, want %d", got, tc.want)
			}
		})
	}
}

func TestNotifyAfterALongSuspendOnlyFiresWhatIsRecent(t *testing.T) {
	log := notifySandbox(t)
	for _, hm := range []string{"07:00", "08:00", "09:00", "09:45", "11:00"} {
		seedEvent(t, "2030-06-15", hm, "event-"+hm)
	}

	if err := Notify(clock(9, 50)); err != nil {
		t.Fatalf("notify: %v", err)
	}
	got := readLog(t, log)
	if strings.Count(got, "event-") != 1 || !strings.Contains(got, "event-09:45") {
		t.Fatalf("notified %q, want only event-09:45", got)
	}
}

func TestNotifyCatchesAnEventAcrossMidnight(t *testing.T) {
	log := notifySandbox(t)
	seedEvent(t, "2030-06-14", "23:50", "late")
	seedEvent(t, "2030-06-14", "22:00", "stale")
	seedEvent(t, "2030-06-14", "", "yesterday all day")

	if err := Notify(clock(0, 10)); err != nil {
		t.Fatalf("notify: %v", err)
	}
	if err := Notify(clock(0, 11)); err != nil {
		t.Fatalf("notify: %v", err)
	}
	got := readLog(t, log)
	if strings.Count(got, "late") != 1 {
		t.Errorf("notified %q, want late exactly once", got)
	}
	if strings.Contains(got, "stale") || strings.Contains(got, "yesterday all day") {
		t.Errorf("notified %q, want neither the stale nor the all-day event", got)
	}
}

func TestNotifyStaysQuietForAnEventWrittenAfterItsTime(t *testing.T) {
	for _, tc := range []struct {
		name   string
		column string
		offset time.Duration
		want   int
	}{
		{"added minutes later", "created_at", 5 * time.Minute, 0},
		{"moved minutes later", "modified_at", 5 * time.Minute, 0},
		{"added within its minute", "created_at", 20 * time.Second, 1},
		{"added beforehand", "created_at", -time.Hour, 1},
	} {
		t.Run(tc.name, func(t *testing.T) {
			log := notifySandbox(t)
			seedEvent(t, "2030-06-15", "09:00", "standup")
			st, err := Open("")
			if err != nil {
				t.Fatalf("open: %v", err)
			}
			if _, err := st.db.Exec("UPDATE events SET "+tc.column+" = ?", clock(9, 0).Add(tc.offset).Unix()); err != nil {
				t.Fatalf("stamp: %v", err)
			}
			st.Close()

			if err := Notify(clock(9, 10)); err != nil {
				t.Fatalf("notify: %v", err)
			}
			if got := strings.Count(readLog(t, log), "standup"); got != tc.want {
				t.Errorf("fired %d times, want %d", got, tc.want)
			}
		})
	}
}
