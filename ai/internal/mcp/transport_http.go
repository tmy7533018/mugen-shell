package mcp

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

// Streamable HTTP; a single POSTing worker keeps initialize → initialized → tools/list ordered.
type httpTransport struct {
	name   string
	url    string
	client *http.Client

	ctx    context.Context
	cancel context.CancelFunc

	mu      sync.Mutex
	session string // Mcp-Session-Id, when the server issues one
	failErr error

	outbound  chan []byte
	queue     chan []byte
	done      chan struct{}
	broken    chan struct{}
	closeOnce sync.Once
	breakOnce sync.Once
}

func newHTTPTransport(name, rawURL string) (*httpTransport, error) {
	u, err := url.Parse(rawURL)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") {
		return nil, fmt.Errorf("invalid MCP server url %q (need http:// or https://)", rawURL)
	}
	ctx, cancel := context.WithCancel(context.Background())
	t := &httpTransport{
		name:   name,
		url:    rawURL,
		ctx:    ctx,
		cancel: cancel,
		// Bounds a single hung POST; close() cancels ctx to abort an in-flight SSE read.
		client:   &http.Client{Timeout: 5 * time.Minute},
		outbound: make(chan []byte, 32),
		queue:    make(chan []byte, 32),
		done:     make(chan struct{}),
		broken:   make(chan struct{}),
	}
	go t.sendLoop()
	return t, nil
}

// send enqueues a message for the worker; it never blocks on the network.
func (t *httpTransport) send(data []byte) error {
	msg := append([]byte(nil), data...)
	select {
	case t.outbound <- msg:
		return nil
	case <-t.done:
		return errors.New("transport closed")
	}
}

func (t *httpTransport) sendLoop() {
	for {
		select {
		case msg := <-t.outbound:
			t.post(msg)
		case <-t.done:
			return
		}
	}
}

func (t *httpTransport) post(data []byte) {
	var probe struct {
		ID json.RawMessage `json:"id"`
	}
	_ = json.Unmarshal(data, &probe)
	hasID := len(probe.ID) > 0 && string(probe.ID) != "null"

	req, err := http.NewRequestWithContext(t.ctx, http.MethodPost, t.url, bytes.NewReader(data))
	if err != nil {
		t.deliverError(probe.ID, hasID, err.Error())
		return
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json, text/event-stream")
	t.mu.Lock()
	if t.session != "" {
		req.Header.Set("Mcp-Session-Id", t.session)
	}
	t.mu.Unlock()

	resp, err := t.client.Do(req)
	if err != nil {
		t.fail(fmt.Errorf("http transport: %w", err))
		return
	}
	defer resp.Body.Close()

	if sid := resp.Header.Get("Mcp-Session-Id"); sid != "" {
		t.mu.Lock()
		t.session = sid
		t.mu.Unlock()
	}

	switch {
	case resp.StatusCode == http.StatusAccepted:
		return // notification/response accepted, nothing comes back
	case resp.StatusCode >= 400:
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		text := fmt.Sprintf("http transport: server returned status %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
		// A rejected session cannot be re-initialized in place, so hand the whole transport back to re-dial.
		if resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusUnauthorized {
			t.fail(errors.New(text))
			return
		}
		t.deliverError(probe.ID, hasID, text)
		return
	}

	if strings.HasPrefix(resp.Header.Get("Content-Type"), "text/event-stream") {
		t.pumpSSE(resp.Body, probe.ID, hasID)
		return
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 32<<20))
	if err != nil {
		t.deliverError(probe.ID, hasID, fmt.Sprintf("http transport: reading response: %v", err))
		return
	}
	if b := bytes.TrimSpace(body); len(b) > 0 {
		t.deliver(b)
	}
}

// A scanner error surfaces as a JSON-RPC error rather than a truncated fragment.
func (t *httpTransport) pumpSSE(r io.Reader, id json.RawMessage, hasID bool) {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 64*1024), 32<<20)
	var data []byte
	flush := func() {
		if len(data) > 0 {
			t.deliver(data)
			data = nil
		}
	}
	for sc.Scan() {
		line := sc.Text()
		if line == "" {
			flush()
			continue
		}
		if v, ok := strings.CutPrefix(line, "data:"); ok {
			v = strings.TrimPrefix(v, " ")
			if len(data) > 0 {
				data = append(data, '\n')
			}
			data = append(data, v...)
		}
	}
	if err := sc.Err(); err != nil {
		t.deliverError(id, hasID, fmt.Sprintf("http transport: SSE stream error: %v", err))
		return
	}
	flush()
}

func (t *httpTransport) deliver(msg []byte) {
	select {
	case t.queue <- append([]byte(nil), msg...):
	case <-t.done:
	}
}

// Without a synthesized error, a failed POST leaves the caller hanging until its context expires.
func (t *httpTransport) deliverError(id json.RawMessage, hasID bool, text string) {
	if !hasID {
		fmt.Fprintf(os.Stderr, "mcp[%s]: %s\n", t.name, text)
		return
	}
	out, err := json.Marshal(map[string]any{
		"jsonrpc": "2.0",
		"id":      id,
		"error":   map[string]any{"code": -32000, "message": text},
	})
	if err != nil {
		return
	}
	t.deliver(out)
}

// Only a dropped connection makes Closed() report the break that Manager.Call re-dials on.
func (t *httpTransport) fail(err error) {
	t.breakOnce.Do(func() {
		t.mu.Lock()
		t.failErr = err
		t.mu.Unlock()
		close(t.broken)
	})
}

func (t *httpTransport) recv() ([]byte, error) {
	select {
	case msg := <-t.queue:
		return msg, nil
	case <-t.broken:
		t.mu.Lock()
		defer t.mu.Unlock()
		return nil, t.failErr
	case <-t.done:
		return nil, io.EOF
	}
}

func (t *httpTransport) close() error {
	t.closeOnce.Do(func() {
		close(t.done)
		t.cancel() // abort any in-flight POST / open SSE read
	})
	return nil
}
