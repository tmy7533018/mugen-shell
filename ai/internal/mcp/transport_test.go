package mcp

import (
	"io"
	"os"
	"strings"
	"syscall"
	"testing"
	"time"
)

func TestStdioTransportRecvCapsUnterminatedLine(t *testing.T) {
	old := recvCap
	recvCap = 200
	defer func() { recvCap = old }()

	tr, err := newStdioTransport("test", "sh", []string{"-c", "head -c 100000 /dev/zero | tr '\\0' A"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer tr.close()

	_, err = tr.recv()
	if err == nil {
		t.Fatal("expected recv to error on an over-cap message")
	}
	if !strings.Contains(err.Error(), "exceeds") {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestStdioTransportRecvReassemblesALineLongerThanTheReadBuffer(t *testing.T) {
	tr, err := newStdioTransport("test", "sh", []string{"-c", "head -c 200000 /dev/zero | tr '\\0' A; echo; sleep 5"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer tr.close()

	msg, err := tr.recv()
	if err != nil {
		t.Fatal(err)
	}
	if len(msg) != 200001 {
		t.Fatalf("recv returned %d bytes, want the whole 200001-byte line", len(msg))
	}
}

func TestClientStopsStdioServerWhoseMessageExceedsTheCap(t *testing.T) {
	old := recvCap
	recvCap = 200
	defer func() { recvCap = old }()

	tr, err := newStdioTransport("test", "sh", []string{"-c", "head -c 100000 /dev/zero | tr '\\0' A; sleep 30"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	pid := tr.cmd.Process.Pid
	c := newClient("test", tr, false)
	defer c.Close()

	deadline := time.Now().Add(5 * time.Second)
	for !c.Closed() || syscall.Kill(pid, 0) == nil {
		if time.Now().After(deadline) {
			t.Fatalf("server still running after its message exceeded the cap (client closed: %v)", c.Closed())
		}
		time.Sleep(10 * time.Millisecond)
	}
}

func TestStdioTransportCloseIsIdempotent(t *testing.T) {
	tr, err := newStdioTransport("test", "sleep", []string{"30"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	first := tr.close()
	if second := tr.close(); second != first {
		t.Errorf("second close returned %v, want the first close's %v", second, first)
	}
}

func TestPrefixWriterBoundsUnterminatedLine(t *testing.T) {
	realStderr := os.Stderr
	r, w, _ := os.Pipe()
	os.Stderr = w
	defer func() { os.Stderr = realStderr; w.Close() }()
	go io.Copy(io.Discard, r)

	pw := &prefixWriter{prefix: "test: "}
	chunk := strings.Repeat("A", 8<<10)
	for i := 0; i < 20; i++ {
		pw.Write([]byte(chunk))
	}
	if len(pw.buf) > maxPrefixBufBytes {
		t.Errorf("prefixWriter buffer grew to %d bytes, want <= %d", len(pw.buf), maxPrefixBufBytes)
	}
}
