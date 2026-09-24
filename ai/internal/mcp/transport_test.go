package mcp

import (
	"io"
	"os"
	"strings"
	"testing"
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
