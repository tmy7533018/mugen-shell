package mcp

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDiscoverIn(t *testing.T) {
	root := t.TempDir()
	mk := func(parts ...string) {
		if err := os.MkdirAll(filepath.Join(append([]string{root}, parts...)...), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	mk("@modelcontextprotocol", "server-memory")
	mk("@modelcontextprotocol", "server-filesystem")
	mk("@modelcontextprotocol", "sdk") // not a server, must be skipped
	mk("mcp-server-git")
	mk("some-random-package")
	mk("@otherscope", "thing")

	got := discoverIn(root)
	want := map[string]string{
		"filesystem": "@modelcontextprotocol/server-filesystem",
		"git":        "mcp-server-git",
		"memory":     "@modelcontextprotocol/server-memory",
	}
	if len(got) != len(want) {
		t.Fatalf("expected %d candidates, got %d: %+v", len(want), len(got), got)
	}
	for _, c := range got {
		pkg, ok := want[c.Name]
		if !ok {
			t.Errorf("unexpected candidate %q", c.Name)
			continue
		}
		if c.Command != "npx" || len(c.Args) != 2 || c.Args[1] != pkg {
			t.Errorf("candidate %q badly shaped: %+v", c.Name, c)
		}
	}
}

func TestDiscoverInEmptyRoot(t *testing.T) {
	got := discoverIn(t.TempDir())
	if got == nil || len(got) != 0 {
		t.Fatalf("expected empty non-nil slice, got %v", got)
	}
}
