package mcp

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
)

// flakyToolServer drops the connection on the first tools/call, after the tool may have run.
type flakyToolServer struct {
	calls atomic.Int32
	tools string
}

func (s *flakyToolServer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var msg struct {
		ID     json.RawMessage `json:"id"`
		Method string          `json:"method"`
	}
	body, _ := io.ReadAll(r.Body)
	_ = json.Unmarshal(body, &msg)
	w.Header().Set("Content-Type", "application/json")
	reply := func(result string) {
		fmt.Fprintf(w, `{"jsonrpc":"2.0","id":%s,"result":%s}`, msg.ID, result)
	}
	switch msg.Method {
	case "initialize":
		reply(`{}`)
	case "tools/list":
		tools := s.tools
		if tools == "" {
			tools = `[
			{"name":"delete_note","inputSchema":{"type":"object"},"annotations":{"destructiveHint":true}},
			{"name":"lookup_note","inputSchema":{"type":"object"},"annotations":{"readOnlyHint":true}}]`
		}
		reply(`{"tools":` + tools + `}`)
	case "tools/call":
		if s.calls.Add(1) == 1 {
			panic(http.ErrAbortHandler)
		}
		reply(`{"content":[{"type":"text","text":"ran"}]}`)
	default:
		w.WriteHeader(http.StatusAccepted)
	}
}

func TestManagerDoesNotRepeatAToolTheServerDiedDuring(t *testing.T) {
	srv := &flakyToolServer{}
	ts := httptest.NewServer(srv)
	defer ts.Close()
	m := Connect(context.Background(), map[string]ServerConfig{"notes": {URL: ts.URL}})
	defer m.Close()

	_, err := m.Call(context.Background(), "notes", "delete_note", nil)
	if err == nil || !strings.Contains(err.Error(), "not repeated") {
		t.Fatalf("err = %v, want one saying the call was not repeated", err)
	}
	if n := srv.calls.Load(); n != 1 {
		t.Fatalf("the tool reached the server %d times, want 1", n)
	}

	out, err := m.Call(context.Background(), "notes", "delete_note", nil)
	if err != nil || out != "ran" {
		t.Fatalf("the next call should re-dial and run: out=%q err=%v", out, err)
	}
}

func TestManagerRepeatsAReadOnlyToolTheServerDiedDuring(t *testing.T) {
	srv := &flakyToolServer{}
	ts := httptest.NewServer(srv)
	defer ts.Close()
	m := Connect(context.Background(), map[string]ServerConfig{"notes": {URL: ts.URL}})
	defer m.Close()

	out, err := m.Call(context.Background(), "notes", "lookup_note", nil)
	if err != nil || out != "ran" {
		t.Fatalf("out=%q err=%v, want the read-only call retried", out, err)
	}
}

func TestManagerDoesNotTrustAReadOnlyHintItRefusedElsewhere(t *testing.T) {
	srv := &flakyToolServer{tools: `[{"name":"delete_note","inputSchema":{"type":"object"},"annotations":{"readOnlyHint":true}}]`}
	ts := httptest.NewServer(srv)
	defer ts.Close()
	m := Connect(context.Background(), map[string]ServerConfig{"notes": {URL: ts.URL}})
	defer m.Close()

	if _, err := m.Call(context.Background(), "notes", "delete_note", nil); err == nil {
		t.Error("an untrusted server's read-only hint let the call repeat")
	}
	if n := srv.calls.Load(); n != 1 {
		t.Errorf("the tool reached the server %d times, want 1", n)
	}
}

// failingTransport never answers and fails with err once told to.
type failingTransport struct {
	sent chan struct{}
	err  chan error
}

func (f *failingTransport) send(context.Context, []byte) error { f.sent <- struct{}{}; return nil }
func (f *failingTransport) recv() ([]byte, error)              { return nil, <-f.err }
func (f *failingTransport) close() error                       { return nil }

func TestARefusalOnlyVouchesForTheCallItAnswered(t *testing.T) {
	tr := &failingTransport{sent: make(chan struct{}, 2), err: make(chan error, 1)}
	c := newClient("notes", tr, false)

	first := make(chan error, 1)
	go func() {
		_, err := c.call(context.Background(), "tools/call", nil)
		first <- err
	}()
	<-tr.sent
	second := make(chan error, 1)
	go func() {
		_, err := c.call(context.Background(), "tools/call", nil)
		second <- err
	}()
	<-tr.sent

	tr.err <- rejectedError{id: json.RawMessage("2"), text: "status 404"}
	if err := <-first; c.repeatIsHarmless("delete_note", err) {
		t.Errorf("the call that was still pending counts as refused: %v", err)
	}
	if err := <-second; !c.repeatIsHarmless("delete_note", err) {
		t.Errorf("the refused call does not count as refused: %v", err)
	}
}

func TestARepeatIsNotVouchedForByAServerError(t *testing.T) {
	c := newClient("notes", &failingTransport{sent: make(chan struct{}, 1), err: make(chan error)}, false)
	var msg rpcMessage
	if err := json.Unmarshal([]byte(`{"error":{"code":-1,"message":"x","refused":true}}`), &msg); err != nil {
		t.Fatal(err)
	}
	if c.repeatIsHarmless("delete_note", msg.Error) {
		t.Error("a field in the server's reply marked the call as refused")
	}
}
