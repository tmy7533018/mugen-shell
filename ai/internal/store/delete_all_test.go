package store

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func openStore(t *testing.T, path string) *Store {
	t.Helper()
	s, err := Open(path)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { s.Close() })
	return s
}

func seedConversation(t *testing.T, s *Store, content string) {
	t.Helper()
	id, err := s.CreateConversation("t", "m", false)
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if _, err := s.AppendMessage(id, "user", content, nil, ""); err != nil {
		t.Fatalf("append: %v", err)
	}
}

func journalMode(t *testing.T, s *Store) string {
	t.Helper()
	var mode string
	if err := s.db.QueryRow(`PRAGMA journal_mode`).Scan(&mode); err != nil {
		t.Fatalf("journal_mode: %v", err)
	}
	return mode
}

func TestDeleteAllWithAnotherConnectionOpen(t *testing.T) {
	path := filepath.Join(t.TempDir(), "history.db")
	serve := openStore(t, path)
	chat := openStore(t, path)
	seedConversation(t, serve, "hello")

	if err := serve.DeleteAllConversations(); err != nil {
		t.Fatalf("delete all with a second connection open: %v", err)
	}
	for name, s := range map[string]*Store{"serve": serve, "chat": chat} {
		if n, err := s.ConversationCount(); err != nil || n != 0 {
			t.Errorf("%s: count = %d, %v", name, n, err)
		}
		if mode := journalMode(t, s); mode != "wal" {
			t.Errorf("%s: journal mode = %s, want wal", name, mode)
		}
	}
	seedConversation(t, serve, "still writable")
	seedConversation(t, chat, "still writable")
}

// A reader pinning the old pages can stop the compaction, but the rows are gone and that is the job.
func TestDeleteAllSucceedsWhenCompactionIsBlocked(t *testing.T) {
	path := filepath.Join(t.TempDir(), "history.db")
	serve := openStore(t, path)
	reader := openStore(t, path)
	seedConversation(t, serve, "hello")
	if _, err := serve.db.Exec(`PRAGMA busy_timeout=50`); err != nil {
		t.Fatal(err)
	}

	tx, err := reader.db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	defer tx.Rollback()
	var n int
	if err := tx.QueryRow(`SELECT COUNT(*) FROM conversations`).Scan(&n); err != nil {
		t.Fatal(err)
	}

	if err := serve.DeleteAllConversations(); err != nil {
		t.Fatalf("delete all under a read transaction: %v", err)
	}
	if n, err := serve.ConversationCount(); err != nil || n != 0 {
		t.Errorf("count = %d, %v", n, err)
	}
}

func TestDeleteAllLeavesNoTextOnDisk(t *testing.T) {
	const marker = "marker-text-that-must-not-survive"
	for _, other := range []bool{false, true} {
		name := "alone"
		if other {
			name = "second connection open"
		}
		t.Run(name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "history.db")
			s := openStore(t, path)
			if other {
				openStore(t, path)
			}
			for i := 0; i < 200; i++ {
				seedConversation(t, s, marker+strings.Repeat("x", 4096))
			}
			before := s.SizeBytes()
			if err := s.DeleteAllConversations(); err != nil {
				t.Fatalf("delete all: %v", err)
			}
			for _, p := range []string{path, path + "-wal"} {
				raw, err := os.ReadFile(p)
				if err != nil {
					continue
				}
				if bytes.Contains(raw, []byte(marker)) {
					t.Errorf("%s still holds deleted text", filepath.Base(p))
				}
			}
			if after := s.SizeBytes(); after >= before || after > 64<<10 {
				t.Errorf("size went from %d to %d, want the pages back", before, after)
			}
		})
	}
}
