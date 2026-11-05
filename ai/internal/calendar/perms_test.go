package calendar

import (
	"os"
	"path/filepath"
	"testing"
)

func perm(t *testing.T, path string) os.FileMode {
	t.Helper()
	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("stat %s: %v", path, err)
	}
	return info.Mode().Perm()
}

func expectOwnerOnly(t *testing.T, paths ...string) {
	t.Helper()
	for _, p := range paths {
		if got := perm(t, p); got&0o077 != 0 {
			t.Errorf("%s is %o", filepath.Base(p), got)
		}
	}
}

func TestCalendarIsOwnerOnly(t *testing.T) {
	path := filepath.Join(t.TempDir(), "share", "calendar.db")
	st, err := Open(path)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer st.Close()
	if _, err := st.Add("2030-06-15", "09:00", "standup"); err != nil {
		t.Fatalf("add: %v", err)
	}
	expectOwnerOnly(t, filepath.Dir(path), path, path+"-wal", path+"-shm")
}

func TestCalendarTightensWhatIsAlreadyThere(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "share")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(dir, "calendar.db")
	if err := os.WriteFile(path, nil, 0o644); err != nil {
		t.Fatal(err)
	}

	st, err := Open(path)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer st.Close()
	if _, err := st.Add("2030-06-15", "09:00", "standup"); err != nil {
		t.Fatalf("add: %v", err)
	}
	expectOwnerOnly(t, dir, path, path+"-wal", path+"-shm")
}

func TestCalendarTightensLeftoverSidecars(t *testing.T) {
	path := filepath.Join(t.TempDir(), "calendar.db")
	holder, err := Open(path)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer holder.Close()
	if _, err := holder.Add("2030-06-15", "09:00", "standup"); err != nil {
		t.Fatalf("add: %v", err)
	}
	for _, p := range []string{path, path + "-wal", path + "-shm"} {
		if err := os.Chmod(p, 0o644); err != nil {
			t.Fatal(err)
		}
	}

	st, err := Open(path)
	if err != nil {
		t.Fatalf("reopen: %v", err)
	}
	defer st.Close()
	expectOwnerOnly(t, path, path+"-wal", path+"-shm")
}

func TestNotifiedFileIsOwnerOnly(t *testing.T) {
	log := notifySandbox(t)
	seedEvent(t, "2030-06-15", "09:00", "standup")
	if err := Notify(clock(9, 0)); err != nil {
		t.Fatalf("notify: %v", err)
	}
	if readLog(t, log) == "" {
		t.Fatal("nothing fired, so nothing was written")
	}
	expectOwnerOnly(t, firedPath(), filepath.Dir(firedPath()))
}

// Most runs fire nothing, so the tightening cannot wait for the next write.
func TestNotifyTightensAnOldFiredFileEvenWhenNothingIsDue(t *testing.T) {
	log := notifySandbox(t)
	dir := filepath.Dir(firedPath())
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(firedPath(), []byte(`{"fired":[]}`), 0o644); err != nil {
		t.Fatal(err)
	}

	if err := Notify(clock(3, 0)); err != nil {
		t.Fatalf("notify: %v", err)
	}
	if got := readLog(t, log); got != "" {
		t.Fatalf("nothing was due, but notified %q", got)
	}
	expectOwnerOnly(t, firedPath(), dir)
}
