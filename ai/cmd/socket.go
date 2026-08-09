package cmd

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"syscall"
	"time"
)

// SocketPath is where the daemon listens and every client dials — a unix socket, not a
// loopback port, since the API is unauthenticated. No fallback: a guess would split the two.
func SocketPath() string {
	if v := os.Getenv("MUGEN_AI_SOCKET"); v != "" {
		return v
	}
	if dir := os.Getenv("XDG_RUNTIME_DIR"); dir != "" {
		return filepath.Join(dir, "mugen-ai", "mugen-ai.sock")
	}
	return ""
}

// 0600 at bind time: chmod after bind leaves a window open at the umask's mode.
func listenSocket(path string) (net.Listener, error) {
	if path == "" {
		return nil, fmt.Errorf("no socket path: set XDG_RUNTIME_DIR or MUGEN_AI_SOCKET")
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return nil, err
	}
	if err := clearStaleSocket(path); err != nil {
		return nil, err
	}

	old := syscall.Umask(0o177)
	ln, err := net.Listen("unix", path)
	syscall.Umask(old)
	if err != nil {
		return nil, err
	}
	return ln, nil
}

// A leftover socket must go, but one that still answers belongs to a live instance.
func clearStaleSocket(path string) error {
	if _, err := os.Stat(path); err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	conn, err := net.DialTimeout("unix", path, 500*time.Millisecond)
	if err == nil {
		conn.Close()
		return fmt.Errorf("another mugen-ai is already listening on %s", path)
	}
	return os.Remove(path)
}

// The host in the URL is ignored by the dialer but still has to be present, hence "localhost".
func socketClient(path string, timeout time.Duration) *http.Client {
	return &http.Client{
		Timeout: timeout,
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
				var d net.Dialer
				return d.DialContext(ctx, "unix", path)
			},
		},
	}
}
