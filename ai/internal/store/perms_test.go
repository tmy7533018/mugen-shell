package store

import (
	"os"
	"path/filepath"
	"testing"
)

func loose(t *testing.T, path string) os.FileMode {
	t.Helper()
	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("stat %s: %v", path, err)
	}
	return info.Mode().Perm()
}

func TestHistoryIsOwnerOnly(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "state", "history.db")

	s, err := Open(path)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer s.Close()

	if perm := loose(t, path); perm&0o077 != 0 {
		t.Errorf("history.db is %o", perm)
	}
	if perm := loose(t, filepath.Dir(path)); perm&0o077 != 0 {
		t.Errorf("state dir is %o", perm)
	}
	// WAL sidecars hold the same rows and are created by the driver, not us.
	for _, suffix := range []string{"-wal", "-shm"} {
		p := path + suffix
		if _, err := os.Stat(p); err != nil {
			continue
		}
		if perm := loose(t, p); perm&0o077 != 0 {
			t.Errorf("%s is %o", suffix, perm)
		}
	}
}

// An install that predates this gets tightened rather than left behind.
func TestHistoryTightensWhatIsAlreadyThere(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(stateDir, "history.db")
	if err := os.WriteFile(path, nil, 0o644); err != nil {
		t.Fatal(err)
	}

	s, err := Open(path)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer s.Close()

	if perm := loose(t, path); perm&0o077 != 0 {
		t.Errorf("pre-existing db left at %o", perm)
	}
	if perm := loose(t, stateDir); perm&0o077 != 0 {
		t.Errorf("pre-existing dir left at %o", perm)
	}
}
