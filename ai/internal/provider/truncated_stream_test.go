package provider

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// Streams content and then hangs up cleanly, without ever sending the terminal
// event. Reported as success, the caller would store the fragment as a
// finished answer.
func stubTruncated(t *testing.T, body string) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, body)
		w.(http.Flusher).Flush()
	}))
}

func TestOllamaReportsATruncatedStream(t *testing.T) {
	srv := stubTruncated(t, `{"message":{"content":"half an ans"},"done":false}`+"\n")
	defer srv.Close()

	var got strings.Builder
	err := testOllama(srv.URL).Chat(context.Background(), "stub",
		[]Message{{Role: "user", Content: "hi"}}, ChatOptions{},
		func(c ChatChunk) error {
			got.WriteString(c.Content)
			return nil
		})
	if err == nil {
		t.Fatalf("a stream that never finished was reported as success (content %q)", got.String())
	}
	if got.String() != "half an ans" {
		t.Errorf("partial content should still reach the caller, got %q", got.String())
	}
}

func TestOpenAIReportsATruncatedStream(t *testing.T) {
	srv := stubTruncated(t,
		`data: {"choices":[{"delta":{"content":"half an ans"}}]}`+"\n\n")
	defer srv.Close()

	err := NewOpenAI(srv.URL, "test-key", []string{"stub"}).Chat(context.Background(), "stub",
		[]Message{{Role: "user", Content: "hi"}}, ChatOptions{},
		func(ChatChunk) error { return nil })
	if err == nil {
		t.Fatal("a stream that never sent finish_reason was reported as success")
	}
}

// A stream that does finish must stay a success — the guard must not fire on
// the normal path.
func TestOllamaCompleteStreamIsStillSuccess(t *testing.T) {
	srv := stubTruncated(t,
		`{"message":{"content":"done"},"done":false}`+"\n"+
			`{"message":{"content":""},"done":true}`+"\n")
	defer srv.Close()

	if err := testOllama(srv.URL).Chat(context.Background(), "stub",
		[]Message{{Role: "user", Content: "hi"}}, ChatOptions{},
		func(ChatChunk) error { return nil }); err != nil {
		t.Fatalf("complete stream reported an error: %v", err)
	}
}
