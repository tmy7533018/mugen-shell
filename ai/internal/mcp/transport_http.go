package mcp

import (
	"bufio"
	"bytes"
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
// transport-agnostic: it just sees messages in and messages out.
type httpTransport struct {
	name   string
	url    string
	client *http.Client

	mu      sync.Mutex
	session string // Mcp-Session-Id, when the server issues one
	closed  bool

	queue     chan []byte
	done      chan struct{}
	closeOnce sync.Once
}

func newHTTPTransport(name, rawURL string) (*httpTransport, error) {
	u, err := url.Parse(rawURL)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") {
		return nil, fmt.Errorf("invalid MCP server url %q (need http:// or https://)", rawURL)
	}
	return &httpTransport{
		name: name,
		url:  rawURL,
		// Bounds the goroutine a hung server would otherwise hold forever;
		// per-request deadlines still come from the caller's context in the
		// client layer.
		client: &http.Client{Timeout: 5 * time.Minute},
		queue:  make(chan []byte, 32),
		done:   make(chan struct{}),
	}, nil
}

// send never blocks on the network: the POST runs in its own goroutine and
// its outcome (response body, SSE events, or a synthesized error) arrives
// through recv() like any other message.
func (t *httpTransport) send(data []byte) error {
	t.mu.Lock()
	closed := t.closed
	t.mu.Unlock()
	if closed {
		return errors.New("transport closed")
	}
	msg := append([]byte(nil), data...)
	go t.post(msg)
	return nil
}

func (t *httpTransport) post(data []byte) {
	var probe struct {
		ID json.RawMessage `json:"id"`
	}
	_ = json.Unmarshal(data, &probe)
	hasID := len(probe.ID) > 0 && string(probe.ID) != "null"

	req, err := http.NewRequest(http.MethodPost, t.url, bytes.NewReader(data))
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
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		t.deliverError(probe.ID, hasID, fmt.Sprintf("http transport: server returned status %d: %s", resp.StatusCode, strings.TrimSpace(string(body))))
		return
	}

	if strings.HasPrefix(resp.Header.Get("Content-Type"), "text/event-stream") {
		t.pumpSSE(resp.Body)
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

// pumpSSE forwards every event's data payload as one message until the
// stream ends. Multi-line data fields are joined with newlines per the SSE
// spec, though JSON-RPC messages are single-line in practice.
func (t *httpTransport) pumpSSE(r io.Reader) {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 64*1024), 10*1024*1024)
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
	t.mu.Lock()
	t.closed = true
	t.mu.Unlock()
	t.closeOnce.Do(func() { close(t.done) })
	return nil
}
