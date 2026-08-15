// Package hypr talks to the running Hyprland instance: the event stream the
// shell's workspace indicator follows, and focus-or-launch for notifications.
package hypr

import (
	"bufio"
	"errors"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
)

// Substrings, not names: "activewindowv2" has to match through "window".
var relevantEvents = []string{
	"workspace", "window", "move", "focus", "monitor",
	"movewindow", "moveworkspace", "focusedmon", "focusedmonv2",
	"workspacev2", "windowtitle", "activewindow", "activewindowv2",
}

// SocketPath locates .socket2.sock for the current instance, falling back to the
// first present. No /tmp/hypr fallback: anyone can plant a socket there.
func SocketPath() (string, error) {
	runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if runtimeDir == "" {
		return "", errors.New("XDG_RUNTIME_DIR is unset")
	}

	if sig := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE"); sig != "" {
		path := filepath.Join(runtimeDir, "hypr", sig, ".socket2.sock")
		if _, err := os.Stat(path); err == nil {
			return path, nil
		}
	}

	entries, err := os.ReadDir(filepath.Join(runtimeDir, "hypr"))
	if err != nil {
		return "", errors.New("Hyprland IPC socket not found")
	}
	for _, entry := range entries {
		path := filepath.Join(runtimeDir, "hypr", entry.Name(), ".socket2.sock")
		if _, err := os.Stat(path); err == nil {
			return path, nil
		}
	}
	return "", errors.New("Hyprland IPC socket not found")
}

// Monitor streams the events the shell cares about to out, one per line, until
// the socket closes.
func Monitor(out io.Writer) error {
	path, err := SocketPath()
	if err != nil {
		return err
	}

	conn, err := net.Dial("unix", path)
	if err != nil {
		return err
	}
	defer conn.Close()

	scanner := bufio.NewScanner(conn)
	for scanner.Scan() {
		line := scanner.Text()
		name, _, found := strings.Cut(line, ">>")
		if !found || line == "" {
			continue
		}
		if !isRelevant(strings.ToLower(name)) {
			continue
		}
		if _, err := io.WriteString(out, line+"\n"); err != nil {
			return err
		}
	}
	return scanner.Err()
}

func isRelevant(eventType string) bool {
	for _, keyword := range relevantEvents {
		if strings.Contains(eventType, keyword) {
			return true
		}
	}
	return false
}
