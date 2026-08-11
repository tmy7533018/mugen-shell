package mcp

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
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

	if err := tr.send([]byte(`{"jsonrpc":"2.0","id":1,"method":"ping"}`)); err != nil {
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
	if err := tr.send([]byte(`{"jsonrpc":"2.0","method":"notifications/initialized"}`)); err != nil {
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

	if err := tr.send([]byte(`{"jsonrpc":"2.0","id":7,"method":"tools/list"}`)); err != nil {
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

	if err := tr.send([]byte(`{"jsonrpc":"2.0","id":9,"method":"ping"}`)); err != nil {
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

	if err := tr.send([]byte(`{"jsonrpc":"2.0","id":9,"method":"tools/call"}`)); err != nil {
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

	if err := tr.send([]byte(`{"jsonrpc":"2.0","id":9,"method":"ping"}`)); err != nil {
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
	c := newClient("test", tr)
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
