package attach

import (
	"encoding/base64"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// 1x1 transparent PNG.
const onePixelPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

func writePNG(t *testing.T, dir, name string) string {
	t.Helper()
	data, err := base64.StdEncoding.DecodeString(onePixelPNG)
	if err != nil {
		t.Fatalf("decode fixture: %v", err)
	}
	path := filepath.Join(dir, name)
	if err := os.WriteFile(path, data, 0o644); err != nil {
		t.Fatalf("write fixture: %v", err)
	}
	return path
}

func TestLoadReadsImage(t *testing.T) {
	path := writePNG(t, t.TempDir(), "shot.png")

	att, err := Load([]string{path})
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if len(att.Images) != 1 || len(att.Documents) != 0 {
		t.Fatalf("want 1 image and no documents, got %+v", att)
	}
	if att.Images[0].MediaType != "image/png" {
		t.Fatalf("media type: %q", att.Images[0].MediaType)
	}
	if att.Images[0].Data != onePixelPNG {
		t.Fatalf("data round-trip mismatch")
	}
}

func TestLoadTreatsNonImageNamedPNGAsText(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "notreally.png")
	if err := os.WriteFile(path, []byte("#!/bin/sh\necho hi\n"), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}

	att, err := Load([]string{path})
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if len(att.Documents) != 1 || len(att.Images) != 0 {
		t.Fatalf("want 1 document, got %+v", att)
	}
	if att.Documents[0].Name != "notreally.png" {
		t.Fatalf("name: %q", att.Documents[0].Name)
	}
}

func TestLoadReadsTextFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "config.toml")
	if err := os.WriteFile(path, []byte("[weather]\nplace = \"Tokyo\"\n"), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}

	att, err := Load([]string{path})
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if len(att.Documents) != 1 {
		t.Fatalf("want 1 document, got %+v", att)
	}
	if att.Documents[0].Truncated {
		t.Fatal("a small file must not report as truncated")
	}
	prompt := att.Prompt("what is this")
	if !strings.Contains(prompt, "what is this") || !strings.Contains(prompt, "place = \"Tokyo\"") {
		t.Fatalf("prompt missing parts: %q", prompt)
	}
}

func TestLoadTruncatesLongText(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "huge.log")
	if err := os.WriteFile(path, []byte(strings.Repeat("a", MaxTextBytes+500)), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}

	att, err := Load([]string{path})
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if len(att.Documents) != 1 || !att.Documents[0].Truncated {
		t.Fatalf("want a truncated document, got %+v", att)
	}
	if len(att.Documents[0].Content) != MaxTextBytes {
		t.Fatalf("content length %d, want %d", len(att.Documents[0].Content), MaxTextBytes)
	}
	if !strings.Contains(att.Prompt(""), "truncated") {
		t.Fatal("the prompt must say the file was cut")
	}
}

func TestLoadRejectsBinary(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "blob.bin")
	if err := os.WriteFile(path, []byte{0x00, 0x01, 0x02, 0xff, 0xfe}, 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}

	if _, err := Load([]string{path}); err == nil {
		t.Fatal("want an error for a binary payload")
	}
}

func TestLoadRejectsRelativePath(t *testing.T) {
	if _, err := Load([]string{"relative/shot.png"}); err == nil {
		t.Fatal("want an error for a relative path")
	}
}

func TestLoadRejectsOversizeFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "big.png")
	if err := os.WriteFile(path, make([]byte, MaxBytes+1), 0o644); err != nil {
		t.Fatalf("write: %v", err)
	}

	_, err := Load([]string{path})
	if err == nil || !strings.Contains(err.Error(), "limit") {
		t.Fatalf("want a size-limit error, got %v", err)
	}
}

func TestLoadRejectsTooMany(t *testing.T) {
	dir := t.TempDir()
	paths := make([]string, 0, MaxPerMessage+1)
	for i := 0; i <= MaxPerMessage; i++ {
		paths = append(paths, writePNG(t, dir, string(rune('a'+i))+".png"))
	}

	if _, err := Load(paths); err == nil {
		t.Fatal("want an error past the per-message cap")
	}
}

func TestLoadBestEffortSkipsMissing(t *testing.T) {
	dir := t.TempDir()
	good := writePNG(t, dir, "good.png")

	att := LoadBestEffort([]string{filepath.Join(dir, "gone.png"), good})
	if len(att.Images) != 1 {
		t.Fatalf("want the readable image only, got %+v", att)
	}
}
