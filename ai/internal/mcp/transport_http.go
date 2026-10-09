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

const sseDrainWait = 500 * time.Millisecond

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

	outbound  chan outMsg
	queue     chan []byte
	done      chan struct{}
	broken    chan struct{}
	closeOnce sync.Once
	breakOnce sync.Once
}

func newHTTPTransport(name, rawURL string) (*httpTransport, error) {
	u, err := url.Parse(rawURL)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") {
		return nil, errors.New("invalid MCP server url (need http:// or https://)")
	}
	ctx, cancel := context.WithCancel(context.Background())
	t := &httpTransport{
		name:   name,
		url:    rawURL,
		ctx:    ctx,
		cancel: cancel,
		// Bounds a single hung POST; close() cancels ctx to abort an in-flight SSE read.
		client:   &http.Client{Timeout: 5 * time.Minute},
		outbound: make(chan outMsg, 32),
		queue:    make(chan []byte, 32),
		done:     make(chan struct{}),
		broken:   make(chan struct{}),
	}
	go t.sendLoop()
	return t, nil
}

type outMsg struct {
	ctx  context.Context
	data []byte
}

// send enqueues a message for the worker; it never blocks on the network.
func (t *httpTransport) send(ctx context.Context, data []byte) error {
	msg := outMsg{ctx, append([]byte(nil), data...)}
	select {
	case t.outbound <- msg:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	case <-t.done:
		return errors.New("transport closed")
	}
}

func (t *httpTransport) sendLoop() {
	for {
		select {
		case msg := <-t.outbound:
			// The caller already gave up; posting now would only be a stale side effect.
			if msg.ctx.Err() != nil {
				continue
			}
			t.post(msg.ctx, msg.data)
		case <-t.done:
			return
		}
	}
}

func (t *httpTransport) post(callCtx context.Context, data []byte) {
	// t.ctx bounds the request too, so close() still aborts it once callCtx outlives the transport.
	reqCtx, cancel := context.WithCancel(callCtx)
	defer cancel()
	stop := context.AfterFunc(t.ctx, cancel)
	defer stop()

	var probe struct {
		ID json.RawMessage `json:"id"`
	}
	_ = json.Unmarshal(data, &probe)
	hasID := len(probe.ID) > 0 && string(probe.ID) != "null"

	req, err := http.NewRequestWithContext(reqCtx, http.MethodPost, t.url, bytes.NewReader(data))
	if err != nil {
		t.deliverError(probe.ID, hasID, withoutURL(err).Error())
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
		// A caller-side timeout, not a broken connection: aborting the request must not force a redial.
		if callCtx.Err() != nil {
			return
		}
		t.fail(fmt.Errorf("http transport: %w", withoutURL(err)))
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
		text := fmt.Sprintf("http transport: server returned status %d: %s", resp.StatusCode, t.redactURL(strings.TrimSpace(string(body))))
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
		// Reading on to the server's end of stream keeps an HTTP/1.1 connection reusable.
		drain := time.AfterFunc(sseDrainWait, cancel)
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 64<<10))
		drain.Stop()
		return
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxMessageBytes))
	if err != nil {
		t.deliverError(probe.ID, hasID, fmt.Sprintf("http transport: reading response: %v", err))
		return
	}
	if b := bytes.TrimSpace(body); len(b) > 0 {
		t.deliver(b)
	}
}

// net/http's *url.Error prints the full URL, and a hosted server's secret often rides in its path or query.
func withoutURL(err error) error {
	var ue *url.Error
	if errors.As(err, &ue) {
		return fmt.Errorf("%s: %w", ue.Op, ue.Err)
	}
	return err
}

// Error pages often echo the request path (Express: "Cannot POST /s/<secret>/mcp").
func (t *httpTransport) redactURL(s string) string {
	u, err := url.Parse(t.url)
	if err != nil {
		return s
	}
	for _, part := range []string{u.RawQuery, u.Query().Encode(), u.EscapedPath(), u.Path} {
		if len(part) > 1 {
			s = strings.ReplaceAll(s, part, "<redacted>")
		}
	}
	return s
}

// A scanner error surfaces as a JSON-RPC error rather than a truncated fragment.
func (t *httpTransport) pumpSSE(r io.Reader, id json.RawMessage, hasID bool) {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 64*1024), maxMessageBytes)
	var data []byte
	for sc.Scan() {
		line := sc.Text()
		if line == "" {
			if len(data) == 0 {
				continue
			}
			t.deliver(data)
			// The spec only says a server SHOULD close the stream after the response; one that doesn't would stall the worker.
			if hasID && isResponseTo(data, id) {
				return
			}
			data = nil
			continue
		}
		if v, ok := strings.CutPrefix(line, "data:"); ok {
			v = strings.TrimPrefix(v, " ")
			if len(data) > 0 {
				data = append(data, '\n')
			}
			if int64(len(data)+len(v)) > recvCap {
				t.deliverError(id, hasID, fmt.Sprintf("http transport: SSE event exceeds %d bytes", recvCap))
				return
			}
			data = append(data, v...)
		}
	}
	if err := sc.Err(); err != nil {
		t.deliverError(id, hasID, fmt.Sprintf("http transport: SSE stream error: %v", err))
		return
	}
	if len(data) > 0 {
		t.deliver(data)
	}
}

// A server request on the stream carries its own id space, so a matching number alone is not the reply.
func isResponseTo(frame, id json.RawMessage) bool {
	var probe struct {
		ID     json.RawMessage `json:"id"`
		Method string          `json:"method"`
	}
	return json.Unmarshal(frame, &probe) == nil && probe.Method == "" && bytes.Equal(probe.ID, id)
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
