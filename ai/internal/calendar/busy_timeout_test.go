package calendar

import (
	"path/filepath"
	"testing"
)

// The notify timer, the shell and the LLM tool all open this DB from separate
// processes, and the driver's default of 0 turns any overlap into an error.
func TestOpenWaitsOnContention(t *testing.T) {
	st, err := Open(filepath.Join(t.TempDir(), "events.db"))
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer st.Close()

	var ms int
	if err := st.db.QueryRow("PRAGMA busy_timeout").Scan(&ms); err != nil {
		t.Fatalf("pragma: %v", err)
	}
	if ms <= 0 {
		t.Errorf("busy_timeout = %d, want a positive wait", ms)
	}
}
