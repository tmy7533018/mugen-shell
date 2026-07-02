package tools

import (
	"context"
	"fmt"
	"path/filepath"
	"strings"
	"testing"

	"github.com/tmy7533018/mugen-ai/internal/store"
)

func newMemoryRegistry(t *testing.T, disabledCategories []string) (*Registry, *store.Store) {
	t.Helper()
	st, err := store.Open(filepath.Join(t.TempDir(), "history.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { st.Close() })
	r, _, _ := newTestRegistry(t, nil, disabledCategories)
	r.AttachMemory(st)
	return r, st
}

func TestMemorySaveListDelete(t *testing.T) {
	r, _ := newMemoryRegistry(t, nil)
	ctx := context.Background()

	out, err := r.Call(ctx, "memory_save", map[string]any{"content": "User prefers dark mode"})
	if err != nil || !strings.Contains(out, "saved as memory #1") {
		t.Fatalf("save: %q, %v", out, err)
	}

	out, err = r.Call(ctx, "memory_list", nil)
	if err != nil || !strings.Contains(out, "[#1] User prefers dark mode") {
		t.Fatalf("list: %q, %v", out, err)
	}

	out, err = r.Call(ctx, "memory_delete", map[string]any{"id": float64(1)})
	if err != nil || !strings.Contains(out, "deleted memory #1") {
		t.Fatalf("delete: %q, %v", out, err)
	}

	out, err = r.Call(ctx, "memory_delete", map[string]any{"id": float64(1)})
	if err != nil || !strings.Contains(out, "error: no memory with id 1") {
		t.Fatalf("double delete should report missing id: %q, %v", out, err)
	}

	if out, _ := r.Call(ctx, "memory_list", nil); !strings.Contains(out, "no memories saved yet") {
		t.Fatalf("empty list: %q", out)
	}
}

func TestMemorySaveRejectsEmptyAndOversized(t *testing.T) {
	r, _ := newMemoryRegistry(t, nil)
	ctx := context.Background()

	if out, _ := r.Call(ctx, "memory_save", map[string]any{"content": "  "}); !strings.Contains(out, "error: content is empty") {
		t.Fatalf("empty content: %q", out)
	}
	long := strings.Repeat("あ", maxMemoryLen+1)
	if out, _ := r.Call(ctx, "memory_save", map[string]any{"content": long}); !strings.Contains(out, "error: content is too long") {
		t.Fatalf("oversized content: %q", out)
	}
}

func TestMemorySaveCap(t *testing.T) {
	r, st := newMemoryRegistry(t, nil)
	for i := 0; i < maxMemories; i++ {
		if _, err := st.AddMemory(fmt.Sprintf("fact %d", i)); err != nil {
			t.Fatalf("seed: %v", err)
		}
	}
	out, err := r.Call(context.Background(), "memory_save", map[string]any{"content": "one more"})
	if err != nil || !strings.Contains(out, "error: memory is full") {
		t.Fatalf("cap: %q, %v", out, err)
	}
}

func TestMemoryBlock(t *testing.T) {
	r, st := newMemoryRegistry(t, nil)
	if blk := r.MemoryBlock(); blk != "" {
		t.Fatalf("empty store should give no block, got %q", blk)
	}
	if _, err := st.AddMemory("User's name is Noki"); err != nil {
		t.Fatal(err)
	}
	blk := r.MemoryBlock()
	if !strings.Contains(blk, "Long-term memory") || !strings.Contains(blk, "[#1] User's name is Noki") {
		t.Fatalf("block: %q", blk)
	}
}

func TestMemoryCategoryDisabled(t *testing.T) {
	r, st := newMemoryRegistry(t, []string{"memory"})
	if _, err := st.AddMemory("hidden fact"); err != nil {
		t.Fatal(err)
	}
	if blk := r.MemoryBlock(); blk != "" {
		t.Fatalf("disabled category must hide the block, got %q", blk)
	}
	out, err := r.Call(context.Background(), "memory_list", nil)
	if err != nil || !strings.Contains(out, "disabled") {
		t.Fatalf("call should be rejected by category gate: %q, %v", out, err)
	}
	for _, tool := range r.List() {
		if strings.HasPrefix(tool.Name, "memory_") {
			t.Fatalf("memory tools must not be listed when the category is off")
		}
	}
}
