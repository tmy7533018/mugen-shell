package provider

import (
	"context"
	"strings"
	"testing"
)

// Anthropic reports overloads and rate limits mid-stream as an `error` event
// and then closes; the reason has to reach the caller, not just "truncated".
func TestAnthropicStreamErrorEventIsReported(t *testing.T) {
	srv := stubTruncated(t,
		`data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"half an ans"}}`+"\n\n"+
			`data: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}`+"\n\n")
	defer srv.Close()

	var got strings.Builder
	err := testAnthropic(srv.URL).Chat(context.Background(), "stub",
		[]Message{{Role: "user", Content: "hi"}}, ChatOptions{},
		func(c ChatChunk) error {
			got.WriteString(c.Content)
			return nil
		})
	if err == nil {
		t.Fatal("an error event was reported as success")
	}
	if !strings.Contains(err.Error(), "Overloaded") || !strings.Contains(err.Error(), "overloaded_error") {
		t.Errorf("error should carry the provider's message and type, got %q", err)
	}
	if got.String() != "half an ans" {
		t.Errorf("partial content should still reach the caller, got %q", got.String())
	}
}

func TestAnthropicCutOffStopReasonsAreNotADone(t *testing.T) {
	for reason, want := range map[string]string{
		"refusal":                       "anthropic: reply refused",
		"model_context_window_exceeded": "anthropic: the stream ended before the reply was complete",
	} {
		t.Run(reason, func(t *testing.T) {
			srv := stubTruncated(t,
				`data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"half an ans"}}`+"\n\n"+
					`data: {"type":"message_delta","delta":{"stop_reason":"`+reason+`"}}`+"\n\n")
			defer srv.Close()

			var sawDone bool
			err := testAnthropic(srv.URL).Chat(context.Background(), "stub",
				[]Message{{Role: "user", Content: "hi"}}, ChatOptions{},
				func(c ChatChunk) error {
					if c.Done {
						sawDone = true
					}
					return nil
				})
			if err == nil || err.Error() != want {
				t.Fatalf("err = %v, want %q", err, want)
			}
			if sawDone {
				t.Errorf("stop_reason %s must not deliver a Done chunk", reason)
			}
		})
	}
}
