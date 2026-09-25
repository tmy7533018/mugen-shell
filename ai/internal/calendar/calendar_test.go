package calendar

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestNormalizeTime(t *testing.T) {
	tests := []struct {
		name    string
		in      string
		want    string
		wantErr bool
	}{
		{name: "single digit hour", in: "9:00", want: "09:00"},
		{name: "midnight", in: "0:00", want: "00:00"},
		{name: "already padded", in: "23:59", want: "23:59"},
		{name: "empty is all-day", in: "", want: ""},
		{name: "trims space", in: "  9:00  ", want: "09:00"},
		{name: "missing minute digit", in: "9:5", wantErr: true},
		{name: "hour out of range", in: "24:00", wantErr: true},
		{name: "minute out of range", in: "12:60", wantErr: true},
		{name: "all-day sentinel", in: "all-day", wantErr: true},
		{name: "null literal", in: "<nil>", wantErr: true},
		{name: "seconds not accepted", in: "21:00:00", wantErr: true},
		{name: "full-width digits", in: "９:００", wantErr: true},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got, err := normalizeTime(tc.in)
			if tc.wantErr {
				if err == nil {
					t.Fatalf("normalizeTime(%q) = %q, want error", tc.in, got)
				}
				return
			}
			if err != nil {
				t.Fatalf("normalizeTime(%q): unexpected error: %v", tc.in, err)
			}
			if got != tc.want {
				t.Errorf("normalizeTime(%q) = %q, want %q", tc.in, got, tc.want)
			}
		})
	}
}

func TestNormalizeDate(t *testing.T) {
	tests := []struct {
		name    string
		in      string
		want    string
		wantErr bool
	}{
		{name: "unpadded month and day", in: "2026-9-3", want: "2026-09-03"},
		{name: "already padded", in: "2026-09-03", want: "2026-09-03"},
		{name: "day out of range", in: "2026-02-31", wantErr: true},
		{name: "month out of range", in: "2026-13-01", wantErr: true},
		{name: "not a date", in: "tomorrow", wantErr: true},
		{name: "slash separators", in: "2026/09/03", wantErr: true},
		{name: "empty", in: "", wantErr: true},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got, err := normalizeDate(tc.in)
			if tc.wantErr {
				if err == nil {
					t.Fatalf("normalizeDate(%q) = %q, want error", tc.in, got)
				}
				return
			}
			if err != nil {
				t.Fatalf("normalizeDate(%q): unexpected error: %v", tc.in, err)
			}
			if got != tc.want {
				t.Errorf("normalizeDate(%q) = %q, want %q", tc.in, got, tc.want)
			}
		})
	}
}

func openTestStore(t *testing.T) *Store {
	t.Helper()
	// migrateLegacy reads XDG_DATA_HOME regardless of the db path passed to Open.
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	st, err := Open(filepath.Join(t.TempDir(), "events.db"))
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { st.Close() })
	return st
}

func TestStoreAddNormalizesTime(t *testing.T) {
	st := openTestStore(t)

	id, err := st.Add("2026-9-3", "9:00", "nine")
	if err != nil {
		t.Fatalf("add: %v", err)
	}

	events, err := st.ListRange("2026-09-01", "2026-09-30")
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(events) != 1 || events[0].ID != id {
		t.Fatalf("got %+v, want one event with id %q", events, id)
	}
	if events[0].Date != "2026-09-03" || events[0].Time != "09:00" {
		t.Errorf("got date=%q time=%q, want date=2026-09-03 time=09:00", events[0].Date, events[0].Time)
	}
}

func TestStoreAddRejectsInvalidInput(t *testing.T) {
	tests := []struct {
		name string
		date string
		time string
	}{
		{name: "all-day sentinel as time", date: "2026-09-03", time: "all-day"},
		{name: "null literal as time", date: "2026-09-03", time: "<nil>"},
		{name: "invalid calendar date", date: "2026-02-31", time: "09:00"},
		{name: "unpadded minute", date: "2026-09-03", time: "9:5"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			st := openTestStore(t)
			if _, err := st.Add(tc.date, tc.time, "x"); err == nil {
				t.Fatalf("Add(%q, %q) succeeded, want error", tc.date, tc.time)
			}
		})
	}
}

func TestStoreUpdateNormalizesTime(t *testing.T) {
	st := openTestStore(t)

	id, err := st.Add("2026-09-03", "", "x")
	if err != nil {
		t.Fatalf("add: %v", err)
	}
	if _, err := st.Update(id, "x", "9:00"); err != nil {
		t.Fatalf("update: %v", err)
	}

	events, err := st.ListRange("2026-09-01", "2026-09-30")
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(events) != 1 || events[0].Time != "09:00" {
		t.Fatalf("got %+v, want time=09:00", events)
	}
}

func TestListRangeNormalizesDates(t *testing.T) {
	st := openTestStore(t)

	if _, err := st.Add("2026-09-03", "10:00", "x"); err != nil {
		t.Fatalf("add: %v", err)
	}

	events, err := st.ListRange("2026-9-1", "2026-9-30")
	if err != nil {
		t.Fatalf("list-range with unpadded dates: %v", err)
	}
	if len(events) != 1 {
		t.Fatalf("got %d events, want 1", len(events))
	}
}

func TestListRangeRejectsInvalidDate(t *testing.T) {
	st := openTestStore(t)
	if _, err := st.ListRange("2026-13-01", "2026-09-30"); err == nil {
		t.Fatal("ListRange with an invalid start date succeeded, want error")
	}
}

func TestOpenFixesUnpaddedTimes(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	path := filepath.Join(t.TempDir(), "events.db")

	st, err := Open(path)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	if _, err := st.db.Exec(
		"INSERT INTO events (id, date, time, title) VALUES ('x', '2026-09-03', '9:00', 'legacy')"); err != nil {
		t.Fatalf("seed unpadded row: %v", err)
	}
	st.Close()

	readTime := func() string {
		st, err := Open(path)
		if err != nil {
			t.Fatalf("reopen: %v", err)
		}
		defer st.Close()
		var got string
		if err := st.db.QueryRow("SELECT time FROM events WHERE id = 'x'").Scan(&got); err != nil {
			t.Fatalf("select: %v", err)
		}
		return got
	}

	if got := readTime(); got != "09:00" {
		t.Fatalf("time after fixing = %q, want 09:00", got)
	}
	if got := readTime(); got != "09:00" {
		t.Fatalf("time after a second Open = %q, want 09:00 (fix must be idempotent)", got)
	}
}

func TestOpenFixesUnpaddedDates(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	path := filepath.Join(t.TempDir(), "events.db")

	st, err := Open(path)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	seed := []struct{ id, date string }{
		{"a", "2026-9-3"},
		{"b", "2026-10-5"},
		{"c", "2026-9-30"},
		{"d", "2026-09-03"},
	}
	for _, row := range seed {
		if _, err := st.db.Exec(
			"INSERT INTO events (id, date, time, title) VALUES (?, ?, '', 'legacy')", row.id, row.date,
		); err != nil {
			t.Fatalf("seed %s: %v", row.id, err)
		}
	}
	st.Close()

	want := map[string]string{"a": "2026-09-03", "b": "2026-10-05", "c": "2026-09-30", "d": "2026-09-03"}

	for i := 0; i < 2; i++ {
		st, err := Open(path)
		if err != nil {
			t.Fatalf("open #%d: %v", i, err)
		}
		events, err := st.ListRange("2026-09-01", "2026-10-31")
		st.Close()
		if err != nil {
			t.Fatalf("ListRange #%d: %v", i, err)
		}
		if len(events) != len(want) {
			t.Fatalf("Open #%d: got %d events, want %d", i, len(events), len(want))
		}
		got := map[string]string{}
		for _, e := range events {
			got[e.ID] = e.Date
		}
		if !reflect.DeepEqual(got, want) {
			t.Fatalf("Open #%d: dates = %v, want %v", i, got, want)
		}
	}
}

func TestLegacyImportSkipsBadRows(t *testing.T) {
	dataDir := t.TempDir()
	t.Setenv("XDG_DATA_HOME", dataDir)

	shellDir := filepath.Join(dataDir, "mugen-shell")
	if err := os.MkdirAll(shellDir, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	const legacy = `{"events":[
		{"id":"a","date":"2026-09-03","time":"9:00","title":"good"},
		{"id":"b","date":"2026-02-31","time":"","title":"bad date"}
	]}`
	if err := os.WriteFile(filepath.Join(shellDir, "events.json"), []byte(legacy), 0o644); err != nil {
		t.Fatalf("write legacy events.json: %v", err)
	}

	st, err := Open("")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer st.Close()

	events, err := st.ListRange("2026-01-01", "2026-12-31")
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(events) != 1 {
		t.Fatalf("got %d events, want 1 (bad row should be skipped): %+v", len(events), events)
	}
	if events[0].ID != "a" || events[0].Time != "09:00" {
		t.Errorf("got %+v, want id=a time=09:00", events[0])
	}
}
