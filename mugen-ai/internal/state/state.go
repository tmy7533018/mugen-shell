package state

import (
	"os"
	"path/filepath"
	"strings"
)

const filename = "last_model"

func dir() string {
	d := os.Getenv("XDG_STATE_HOME")
	if d == "" {
		home, _ := os.UserHomeDir()
		d = filepath.Join(home, ".local", "state")
	}
	return filepath.Join(d, "mugen-ai")
}

func path() string { return filepath.Join(dir(), filename) }

func LoadModel() string {
	b, err := os.ReadFile(path())
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func SaveModel(model string) error {
	if err := os.MkdirAll(dir(), 0755); err != nil {
		return err
	}
	return os.WriteFile(path(), []byte(model+"\n"), 0644)
}
