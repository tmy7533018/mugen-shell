package mcp

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"
)

func TestHTTPTransportFollowsARedirectOnTheSameOrigin(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("/mcp", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/mcp/", http.StatusTemporaryRedirect)
	})
	mux.HandleFunc("/mcp/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, `{"jsonrpc":"2.0","id":1,"result":{}}`)
	})
	ts := httptest.NewServer(mux)
	defer ts.Close()

	tr, err := newHTTPTransport("test", ts.URL+"/mcp")
	if err != nil {
		t.Fatal(err)
	}
	defer tr.close()
	if err := tr.send(context.Background(), []byte(`{"jsonrpc":"2.0","id":1,"method":"initialize"}`)); err != nil {
		t.Fatal(err)
	}
	if _, err := recvResult(t, tr); err != nil {
		t.Fatalf("redirect was not followed: %v", err)
	}
}

func TestHTTPTransportRefusesARedirectToAnotherOrigin(t *testing.T) {
	var reached atomic.Bool
	other := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		reached.Store(true)
	}))
	defer other.Close()
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Mcp-Session-Id") == "" {
			w.Header().Set("Mcp-Session-Id", "secret-session")
			w.Header().Set("Content-Type", "application/json")
			_, _ = io.WriteString(w, `{"jsonrpc":"2.0","id":1,"result":{}}`)
			return
		}
		http.Redirect(w, r, other.URL, http.StatusTemporaryRedirect)
	}))
	defer ts.Close()

	tr, err := newHTTPTransport("test", ts.URL)
	if err != nil {
		t.Fatal(err)
	}
	client := newClient("test", tr, false)
	defer client.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if _, err := client.call(ctx, "initialize", nil); err != nil {
		t.Fatal(err)
	}
	_, err = client.call(ctx, "tools/call", nil)
	if err == nil || ctx.Err() != nil {
		t.Fatalf("err = %v (ctx %v), want the refusal reported before the deadline", err, ctx.Err())
	}
	if reached.Load() {
		t.Error("the session header followed a redirect to another origin")
	}
}
