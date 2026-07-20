// Package mcp is a minimal Model Context Protocol client. It speaks
// JSON-RPC 2.0 over stdio or Streamable HTTP so mugen-ai can merge external
// servers' tools into the LLM's tool set alongside the built-in shell tools.
package mcp

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"sync"
)

type transport interface {
	// send writes one message; the implementation adds its own framing.
	send(data []byte) error
	// recv blocks until the next message arrives, returning io.EOF once the
	// server has exited.
	recv() ([]byte, error)
	close() error
}

// Runs an MCP server as a child process. Its stderr is forwarded to
// mugen-ai's with a per-server prefix so a misbehaving one stays debuggable.
type stdioTransport struct {
	cmd    *exec.Cmd
	stdin  io.WriteCloser
	stdout *bufio.Reader
	mu     sync.Mutex // serialises writes; recv runs on one goroutine only
}

func newStdioTransport(name, command string, args []string, env map[string]string) (*stdioTransport, error) {
	cmd := exec.Command(command, args...)
	cmd.Env = os.Environ()
	for k, v := range env {
		cmd.Env = append(cmd.Env, k+"="+v)
	}
	cmd.Stderr = &prefixWriter{prefix: fmt.Sprintf("mcp[%s]: ", name)}

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("start %q: %w", command, err)
	}
	return &stdioTransport{
		cmd:    cmd,
		stdin:  stdin,
		stdout: bufio.NewReaderSize(stdout, 64*1024),
	}, nil
}

func (t *stdioTransport) send(data []byte) error {
	t.mu.Lock()
	defer t.mu.Unlock()
	_, err := t.stdin.Write(append(data, '\n'))
	return err
}

func (t *stdioTransport) recv() ([]byte, error) {
	// ReadBytes has no size cap (unlike bufio.Scanner's token limit) so a
	// large tool result can't truncate mid-message.
	line, err := t.stdout.ReadBytes('\n')
	if err != nil && len(line) == 0 {
		return nil, err
	}
	return line, nil
}

func (t *stdioTransport) close() error {
	_ = t.stdin.Close()
	// Closing stdin only asks the server to exit; Kill makes sure it does,
	// and Wait reaps the process plus the stderr-copying goroutine.
	if t.cmd.Process != nil {
		_ = t.cmd.Process.Kill()
	}
	return t.cmd.Wait()
}

// Tags every complete line before forwarding to os.Stderr, so several
// servers' diagnostics stay readable when interleaved.
type prefixWriter struct {
	prefix string
	buf    []byte
}

func (w *prefixWriter) Write(p []byte) (int, error) {
	w.buf = append(w.buf, p...)
	for {
		i := bytes.IndexByte(w.buf, '\n')
		if i < 0 {
			break
		}
		fmt.Fprintf(os.Stderr, "%s%s\n", w.prefix, w.buf[:i])
		w.buf = w.buf[i+1:]
	}
	return len(p), nil
}
