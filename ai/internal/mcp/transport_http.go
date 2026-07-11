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

// httpTransport speaks Streamable HTTP: every message is POSTed to the
// server's MCP endpoint, and whatever comes back — a JSON body or an SSE
// stream — is fed into recv()'s queue. The JSON-RPC client on top stays
// transport-agnostic: it just sees messages in and messages out. Outbound
// messages are POSTed by a single worker in the order send() was called, so
// the initialize → initialized → tools/list handshake can't reorder on the
// wire the way one-goroutine-per-message would.
type httpTransport struct {
	name   string
	url    string
	client *http.Client

	ctx    context.Context
	cancel context.CancelFunc

	mu      sync.Mutex
	session string // Mcp-Session-Id, when the server issues one

	outbound  chan []byte
	queue     chan []byte
	done      chan struct{}
	closeOnce sync.Once
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
		// Timeout bounds a single hung POST; close() also cancels ctx to abort
		// an in-flight request (e.g. an open SSE read) immediately.
		client:   &http.Client{Timeout: 5 * time.Minute},
		outbound: make(chan []byte, 32),
		queue:    make(chan []byte, 32),
		done:     make(chan struct{}),
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

// sendLoop POSTs queued messages one at a time so their wire order matches the
// order send() was called in.
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
		t.deliverError(probe.ID, hasID, fmt.Sprintf("http transport: %v", err))
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
		// Drop a stale session so a server that restarted (and now rejects the
		// old id) gets a fresh Mcp-Session-Id on the next request instead of
		// being wedged behind a dead session forever.
		if resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusUnauthorized {
			t.mu.Lock()
			t.session = ""
			t.mu.Unlock()
		}
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		t.deliverError(probe.ID, hasID, fmt.Sprintf("http transport: server returned status %d: %s", resp.StatusCode, strings.TrimSpace(string(body))))
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

// pumpSSE forwards every event's data payload as one message until the stream
// ends. A scanner error (e.g. a data line exceeding the buffer cap) is
// surfaced as a JSON-RPC error for the pending request rather than silently
// delivering a truncated fragment that would fail to parse downstream.
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

// deliverError surfaces a failed POST to the waiting caller as a JSON-RPC
// error response — without one, a request would hang until its context
// expires. Failures of id-less messages (notifications) only get logged.
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

func (t *httpTransport) recv() ([]byte, error) {
	select {
	case msg := <-t.queue:
		return msg, nil
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
