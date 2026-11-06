package state

import (
	"os"
	"testing"
)

func TestSaveModelReplacesTheFileInsteadOfRewritingIt(t *testing.T) {
	t.Setenv("XDG_STATE_HOME", t.TempDir())

	if err := SaveModel("first"); err != nil {
		t.Fatal(err)
	}
	before, err := os.Stat(path())
	if err != nil {
		t.Fatal(err)
	}
	if err := SaveModel("second"); err != nil {
		t.Fatal(err)
	}
	after, err := os.Stat(path())
	if err != nil {
		t.Fatal(err)
	}
	if os.SameFile(before, after) {
		t.Error("the save wrote into the live file, so a crash can leave it empty")
	}
	if got := LoadModel(); got != "second" {
		t.Errorf("LoadModel = %q, want second", got)
	}
	entries, err := os.ReadDir(dir())
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 1 {
		t.Errorf("left %d files behind, want only %s", len(entries), filename)
	}
}
