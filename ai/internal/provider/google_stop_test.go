package provider

import (
	"context"
	"io"
	"net/http"
	"strings"
	"testing"
)

type sseRoundTripper string

func (body sseRoundTripper) RoundTrip(r *http.Request) (*http.Response, error) {
	return &http.Response{
		StatusCode: http.StatusOK,
		Header:     http.Header{"Content-Type": {"text/event-stream"}},
		Body:       io.NopCloser(strings.NewReader(string(body))),
		Request:    r,
	}, nil
}

func googleWithStream(sse string) *Google {
	g := NewGoogle("test-key", nil)
	g.http = &http.Client{Transport: sseRoundTripper(sse)}
	return g
}

// A blocked reply otherwise ends as a silent empty turn or reads like a dropped connection.
func TestGoogleNamesWhyAReplyNeverCame(t *testing.T) {
	cases := []struct {
		name string
		sse  string
		want string
	}{
		{
			name: "prompt blocked",
			sse:  `data: {"promptFeedback":{"blockReason":"SAFETY"}}` + "\n\n",
			want: "google: prompt blocked (SAFETY)",
		},
		{
			name: "reply blocked before any text",
			sse:  `data: {"candidates":[{"content":{"parts":[]},"finishReason":"SAFETY"}]}` + "\n\n",
			want: "google: reply stopped (SAFETY)",
		},
		{
			name: "malformed function call",
			sse:  `data: {"candidates":[{"content":{"parts":[]},"finishReason":"MALFORMED_FUNCTION_CALL"}]}` + "\n\n",
			want: "google: reply stopped (MALFORMED_FUNCTION_CALL)",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var chunks []ChatChunk
			err := googleWithStream(tc.sse).Chat(context.Background(), "gemini-x",
				[]Message{{Role: "user", Content: "hi"}}, ChatOptions{},
				func(c ChatChunk) error {
					chunks = append(chunks, c)
					return nil
				})
			if err == nil || err.Error() != tc.want {
				t.Fatalf("err = %v, want %q (chunks %+v)", err, tc.want, chunks)
			}
		})
	}
}

func TestGoogleUnspecifiedBlockReasonIsNotABlock(t *testing.T) {
	sse := `data: {"promptFeedback":{"blockReason":"BLOCK_REASON_UNSPECIFIED"},"candidates":[{"content":{"parts":[{"text":"hi"}]},"finishReason":"STOP"}]}` + "\n\n"
	var got strings.Builder
	err := googleWithStream(sse).Chat(context.Background(), "gemini-x",
		[]Message{{Role: "user", Content: "hi"}}, ChatOptions{},
		func(c ChatChunk) error {
			got.WriteString(c.Content)
			return nil
		})
	if err != nil || got.String() != "hi" {
		t.Fatalf("err = %v, content %q", err, got.String())
	}
}

func TestGoogleStopWithAFunctionCallStillYieldsTheCall(t *testing.T) {
	sse := `data: {"candidates":[{"content":{"parts":[{"functionCall":{"name":"audio_get_volume","args":{}},"thoughtSignature":"ts-1"}]},"finishReason":"STOP"}]}` + "\n\n"
	var final ChatChunk
	err := googleWithStream(sse).Chat(context.Background(), "gemini-x",
		[]Message{{Role: "user", Content: "what is the volume"}}, ChatOptions{},
		func(c ChatChunk) error {
			if c.Done {
				final = c
			}
			return nil
		})
	if err != nil {
		t.Fatalf("chat: %v", err)
	}
	if len(final.ToolCalls) != 1 || final.ToolCalls[0].Name != "audio_get_volume" || final.ToolCalls[0].ThoughtSignature != "ts-1" {
		t.Fatalf("tool calls = %+v", final.ToolCalls)
	}
}
