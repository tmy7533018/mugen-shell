package provider

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// Streams chunks, then optionally goes silent with the socket open — the wedge nothing else catches.
func stubOllama(t *testing.T, chunks int, gap time.Duration, thenStall time.Duration) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/x-ndjson")
		w.WriteHeader(http.StatusOK)
		flusher := w.(http.Flusher)
		for i := 0; i < chunks; i++ {
			time.Sleep(gap)
			fmt.Fprintf(w, `{"message":{"content":"chunk%d "},"done":false}`+"\n", i)
			flusher.Flush()
		}
		if thenStall > 0 {
			time.Sleep(thenStall)
			return
		}
		fmt.Fprint(w, `{"message":{"content":""},"done":true}`+"\n")
		flusher.Flush()
	}))
}

// The real window is a minute; tests inject a short one.
func testOllama(url string) *Ollama {
	o := NewOllama(url, 16384, "30m")
	o.stallTimeout = 150 * time.Millisecond
	return o
}

func collect(o *Ollama) (string, error) {
	var got strings.Builder
	err := o.Chat(context.Background(), "stub", []Message{{Role: "user", Content: "hi"}},
		ChatOptions{}, func(c ChatChunk) error {
			got.WriteString(c.Content)
			return nil
		})
	return got.String(), err
}

// A stream slower than the stall window must survive: every chunk rearms it.
func TestSlowButHealthyStreamSurvives(t *testing.T) {
	srv := stubOllama(t, 6, 100*time.Millisecond, 0)
	defer srv.Close()

	o := testOllama(srv.URL)
	got, err := collect(o)
	if err != nil {
		t.Fatalf("healthy stream was killed: %v", err)
	}
	if !strings.Contains(got, "chunk5") {
		t.Fatalf("stream truncated, got %q", got)
	}
	t.Logf("survived 6 chunks spaced 100ms (600ms total) on a %v window", o.stallTimeout)
}

// Silence after a partial answer must end the turn with a diagnosable error,
// not hang until the client gives up.
func TestStallEndsTheTurn(t *testing.T) {
	srv := stubOllama(t, 2, 10*time.Millisecond, time.Second)
	defer srv.Close()

	o := testOllama(srv.URL)
	start := time.Now()
	got, err := collect(o)
	elapsed := time.Since(start)

	if err == nil {
		t.Fatal("a wedged stream returned no error")
	}
	if !strings.Contains(err.Error(), "stopped sending output") {
		t.Fatalf("error is not diagnosable: %v", err)
	}
	if elapsed > 3*o.stallTimeout {
		t.Fatalf("took %v to notice the stall", elapsed)
	}
	if !strings.Contains(got, "chunk1") {
		t.Fatalf("chunks received before the stall were lost, got %q", got)
	}
	t.Logf("noticed after %v on a %v window, err = %v", elapsed, o.stallTimeout, err)
}

// A client that goes away must still read as a cancellation, not as a stall.
func TestClientDisconnectIsNotReportedAsStall(t *testing.T) {
	srv := stubOllama(t, 20, 10*time.Millisecond, 0)
	defer srv.Close()

	o := testOllama(srv.URL)
	ctx, cancel := context.WithCancel(context.Background())
	err := o.Chat(ctx, "stub", []Message{{Role: "user", Content: "hi"}}, ChatOptions{},
		func(c ChatChunk) error {
			cancel()
			return nil
		})
	if err == nil {
		t.Fatal("cancelled request returned no error")
	}
	if strings.Contains(err.Error(), "stopped sending output") {
		t.Fatalf("disconnect misreported as a stall: %v", err)
	}
	t.Logf("disconnect surfaced as: %v", err)
}
