package mcp

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func recvResult(t *testing.T, tr *httpTransport) ([]byte, error) {
	t.Helper()
	type res struct {
		data []byte
		err  error
	}
	ch := make(chan res, 1)
	go func() {
		d, e := tr.recv()
		ch <- res{d, e}
	}()
	select {
	case r := <-ch:
		return r.data, r.err
	case <-time.After(2 * time.Second):
		t.Fatal("recv timed out")
		return nil, nil
	}
}

func recvWithTimeout(t *testing.T, tr *httpTransport) []byte {
	t.Helper()
	data, err := recvResult(t, tr)
	if err != nil {
		t.Fatalf("recv failed: %v", err)
	}
	return data
}

func TestHTTPTransportJSONResponse(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		if !strings.Contains(string(body), `"ping"`) {
			t.Errorf("unexpected request body: %s", body)
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Mcp-Session-Id", "sess-1")
		w.Write([]byte(`{"jsonrpc":"2.0","id":1,"result":{}}`))
	}))
	defer ts.Close()

	tr, err := newHTTPTransport("test", ts.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer tr.close()

	if err := tr.send(context.Background(), []byte(`{"jsonrpc":"2.0","id":1,"method":"ping"}`)); err != nil {
		t.Fatal(err)
	}
	got := recvWithTimeout(t, tr)
	if !strings.Contains(string(got), `"result"`) {
		t.Errorf("unexpected response: %s", got)
	}
	// The captured session id must ride on the next request.
	done := make(chan string, 1)
	ts2 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		done <- r.Header.Get("Mcp-Session-Id")
		w.WriteHeader(http.StatusAccepted)
	}))
	defer ts2.Close()
	tr.url = ts2.URL
	if err := tr.send(context.Background(), []byte(`{"jsonrpc":"2.0","method":"notifications/initialized"}`)); err != nil {
		t.Fatal(err)
	}
	select {
	case sid := <-done:
		if sid != "sess-1" {
			t.Errorf("expected session header sess-1, got %q", sid)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("second request never arrived")
	}
}

func TestHTTPTransportSSEResponse(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.Write([]byte("event: message\ndata: {\"jsonrpc\":\"2.0\",\"id\":7,\"result\":{\"ok\":true}}\n\n"))
	}))
	defer ts.Close()

	tr, err := newHTTPTransport("test", ts.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer tr.close()

	if err := tr.send(context.Background(), []byte(`{"jsonrpc":"2.0","id":7,"method":"tools/list"}`)); err != nil {
		t.Fatal(err)
	}
	got := recvWithTimeout(t, tr)
	if !strings.Contains(string(got), `"ok":true`) {
		t.Errorf("SSE data not delivered: %s", got)
	}
}

func TestHTTPTransportBreaksOnDialFailure(t *testing.T) {
	tr, err := newHTTPTransport("test", "http://127.0.0.1:1") // nothing listens
	if err != nil {
		t.Fatal(err)
	}
	defer tr.close()

	if err := tr.send(context.Background(), []byte(`{"jsonrpc":"2.0","id":9,"method":"ping"}`)); err != nil {
		t.Fatal(err)
	}
	if _, err := recvResult(t, tr); err == nil {
		t.Error("expected recv to report the dead connection")
	}
}

func TestHTTPTransportBreaksOnRejectedSession(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "session expired", http.StatusNotFound)
	}))
	defer ts.Close()

	tr, err := newHTTPTransport("test", ts.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer tr.close()

	if err := tr.send(context.Background(), []byte(`{"jsonrpc":"2.0","id":9,"method":"tools/call"}`)); err != nil {
		t.Fatal(err)
	}
	if _, err := recvResult(t, tr); err == nil {
		t.Error("expected recv to report the rejected session")
	}
}

// A per-call server error leaves the session usable, so only that call fails.
func TestHTTPTransportSynthesizesErrorOnServerError(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "boom", http.StatusInternalServerError)
	}))
	defer ts.Close()

	tr, err := newHTTPTransport("test", ts.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer tr.close()

	if err := tr.send(context.Background(), []byte(`{"jsonrpc":"2.0","id":9,"method":"ping"}`)); err != nil {
		t.Fatal(err)
	}
	got := recvWithTimeout(t, tr)
	if !strings.Contains(string(got), `"error"`) || !strings.Contains(string(got), `"id":9`) {
		t.Errorf("expected synthesized JSON-RPC error for id 9, got: %s", got)
	}
}

// Manager.Call re-dials on Closed(), so the break has to have arrived by the time the call returns.
func TestClientClosedAfterHTTPBreak(t *testing.T) {
	tr, err := newHTTPTransport("test", "http://127.0.0.1:1")
	if err != nil {
		t.Fatal(err)
	}
	c := newClient("test", tr, false)
	defer c.Close()

	if _, err := c.CallTool(context.Background(), "anything", nil); err == nil {
		t.Error("expected the call to fail")
	}
	if !c.Closed() {
		t.Error("expected the client to report closed so Manager.Call re-dials")
	}
}

func TestHTTPTransportRejectsBadURL(t *testing.T) {
	if _, err := newHTTPTransport("test", "ftp://nope"); err == nil {
		t.Error("expected error for non-http scheme")
	}
}

func TestHTTPTransportCloseUnblocksRecv(t *testing.T) {
	tr, err := newHTTPTransport("test", "http://127.0.0.1:1")
	if err != nil {
		t.Fatal(err)
	}
	errs := make(chan error, 1)
	go func() {
		_, e := tr.recv()
		errs <- e
	}()
	tr.close()
	select {
	case e := <-errs:
		if e != io.EOF {
			t.Errorf("expected io.EOF after close, got %v", e)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("recv did not unblock on close")
	}
}

// A hung tools/call must not hold the single POSTing worker for later callers.
func TestHTTPTransportAbandonedCallDoesNotBlockOrPostStale(t *testing.T) {
	start := time.Now()
	events := make(chan string, 8)
	record := func(s string) { events <- time.Since(start).Round(time.Millisecond).String() + " " + s }

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var m struct {
			ID     *int64 `json:"id"`
			Method string `json:"method"`
			Params struct {
				Name string `json:"name"`
			} `json:"params"`
		}
		json.Unmarshal(body, &m)
		if m.ID == nil {
			w.WriteHeader(http.StatusAccepted)
			return
		}
		if m.Method == "tools/call" && m.Params.Name == "slow" {
			select {
			case <-r.Context().Done():
				record("server: slow aborted")
				return
			case <-time.After(2 * time.Second):
				record("server: slow finished (should not happen)")
			}
		}
		record("server: " + m.Method + " " + m.Params.Name)
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"jsonrpc":"2.0","id":` + itoa(*m.ID) + `,"result":{"content":[{"type":"text","text":"ok"}]}}`))
	}))
	defer ts.Close()

	tr, err := newHTTPTransport("test", ts.URL)
	if err != nil {
		t.Fatal(err)
	}
	tr.client.Timeout = 2 * time.Second // backstop only; the per-call ctx should abort well before this
	c := newClient("test", tr, true)
	defer c.Close()

	if err := c.Initialize(context.Background()); err != nil {
		t.Fatal(err)
	}

	slowCtx, cancel := context.WithTimeout(context.Background(), 150*time.Millisecond)
	defer cancel()
	if _, err := c.CallTool(slowCtx, "slow", nil); err == nil {
		t.Fatal("expected the slow call to time out")
	}
	record("caller: slow gave up")

	for i := 0; i < 2; i++ {
		fastCtx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
		callStart := time.Now()
		out, err := c.CallTool(fastCtx, "fast", nil)
		cancel()
		if err != nil {
			t.Fatalf("fast call %d: %v", i, err)
		}
		if out != "ok" {
			t.Fatalf("fast call %d: got %q", i, out)
		}
		if d := time.Since(callStart); d > 200*time.Millisecond {
			t.Errorf("fast call %d took %v, was queued behind the abandoned slow POST", i, d)
		}
	}

	if c.Closed() {
		t.Error("a caller giving up must not be treated as a broken connection")
	}

	time.Sleep(300 * time.Millisecond) // give a wrongly-unaborted slow POST time to land
	close(events)
	var sawAbort bool
	for e := range events {
		t.Log(e)
		if strings.Contains(e, "slow aborted") {
			sawAbort = true
		}
		if strings.Contains(e, "slow finished") || strings.Contains(e, "server: tools/call slow") {
			t.Error("the abandoned slow call reached the server as a completed POST")
		}
	}
	if !sawAbort {
		t.Error("expected the slow POST to be aborted server-side")
	}
}

func TestHTTPTransportCloseAbortsInFlightPOST(t *testing.T) {
	started := make(chan struct{})
	aborted := make(chan struct{})
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.ReadAll(r.Body) // drain first: the server only tracks client disconnect once the body's read
		close(started)
		select {
		case <-r.Context().Done():
			close(aborted)
		case <-time.After(5 * time.Second):
		}
	}))
	defer ts.Close()

	tr, err := newHTTPTransport("test", ts.URL)
	if err != nil {
		t.Fatal(err)
	}
	c := newClient("test", tr, true)

	go c.CallTool(context.Background(), "slow", nil)

	select {
	case <-started:
	case <-time.After(time.Second):
		t.Fatal("request never reached the server")
	}

	c.Close()

	select {
	case <-aborted:
	case <-time.After(time.Second):
		t.Fatal("Close did not abort the in-flight POST")
	}
}

func TestHTTPTransportSkipsQueuedCallWhoseCtxExpiredWaiting(t *testing.T) {
	var queuedReached int32
	hungDone := make(chan struct{})
	hungStarted := make(chan struct{})
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var m struct {
			ID     *int64 `json:"id"`
			Params struct {
				Name string `json:"name"`
			} `json:"params"`
		}
		json.Unmarshal(body, &m)
		if m.ID == nil {
			w.WriteHeader(http.StatusAccepted)
			return
		}
		switch m.Params.Name {
		case "hung":
			close(hungStarted)
			time.Sleep(250 * time.Millisecond)
			close(hungDone)
		case "queued":
			atomic.StoreInt32(&queuedReached, 1)
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"jsonrpc":"2.0","id":` + itoa(*m.ID) + `,"result":{"content":[{"type":"text","text":"ok"}]}}`))
	}))
	defer ts.Close()

	tr, err := newHTTPTransport("test", ts.URL)
	if err != nil {
		t.Fatal(err)
	}
	c := newClient("test", tr, true)
	defer c.Close()
	if err := c.Initialize(context.Background()); err != nil {
		t.Fatal(err)
	}

	go c.CallTool(context.Background(), "hung", nil)
	<-hungStarted

	queuedCtx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	if _, err := c.CallTool(queuedCtx, "queued", nil); err == nil {
		t.Fatal("expected the queued call to time out")
	}

	fastCtx, cancel2 := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel2()
	out, err := c.CallTool(fastCtx, "fast", nil)
	if err != nil {
		t.Fatalf("fast call failed: %v", err)
	}
	if out != "ok" {
		t.Fatalf("fast call: got %q", out)
	}

	select {
	case <-hungDone:
	case <-time.After(time.Second):
		t.Fatal("hung call never completed server-side")
	}

	if atomic.LoadInt32(&queuedReached) != 0 {
		t.Error("the expired queued call reached the server")
	}
}

func itoa(n int64) string { b, _ := json.Marshal(n); return string(b) }
