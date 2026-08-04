package tools

import (
	"os"
	"path/filepath"
	"testing"
)

func TestAuditLogIsOwnerOnly(t *testing.T) {
	path := filepath.Join(t.TempDir(), "audit.log")
	a := &Auditor{path: path}

	a.Log("audio_set_volume", map[string]any{"level": 54}, "ok", nil)

	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("stat: %v", err)
	}
	if perm := info.Mode().Perm(); perm&0o077 != 0 {
		t.Errorf("audit log is %o, must not be readable by group or other", perm)
	}
}

// A log written before the mode was tightened has to be brought in line, not
// left behind at its original permissions.
func TestAuditLogTightensAnExistingFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "audit.log")
	if err := os.WriteFile(path, []byte("{}\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	(&Auditor{path: path}).Log("theme_get", nil, "dark", nil)

	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("stat: %v", err)
	}
	if perm := info.Mode().Perm(); perm&0o077 != 0 {
		t.Errorf("pre-existing log left at %o", perm)
	}
}
