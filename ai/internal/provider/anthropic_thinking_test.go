package provider

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func stubAnthropic(t *testing.T, sse string, capture *[]byte) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if capture != nil {
			b, _ := io.ReadAll(r.Body)
			*capture = b
		}
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)
		io.WriteString(w, sse)
		w.(http.Flusher).Flush()
	}))
}

func testAnthropic(url string) *Anthropic {
	a := NewAnthropic("test-key", nil, 2048, 1024)
	a.baseURL = url
	return a
}

func thinkingThenToolCall() string {
	return strings.Join([]string{
		`data: {"type":"content_block_start","index":0,"content_block":{"type":"thinking"}}`,
		`data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"check the mixer "}}`,
		`data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"before answering"}}`,
		`data: {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"sig-abc"}}`,
		`data: {"type":"content_block_stop","index":0}`,
		`data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"tu_1","name":"audio_get_volume"}}`,
		`data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{}"}}`,
		`data: {"type":"content_block_stop","index":1}`,
		`data: {"type":"message_stop"}`,
		"",
	}, "\n")
}

// Without the signed block the next round is rejected, so it has to survive
// the stream alongside the tool call it justifies.
func TestThinkingReachesTheFinalChunk(t *testing.T) {
	srv := stubAnthropic(t, thinkingThenToolCall(), nil)
	defer srv.Close()

	var final ChatChunk
	err := testAnthropic(srv.URL).Chat(context.Background(), "claude-x",
		[]Message{{Role: "user", Content: "what is the volume"}},
		ChatOptions{Thinking: true},
		func(c ChatChunk) error {
			if c.Done {
				final = c
			}
			return nil
		})
	if err != nil {
		t.Fatalf("chat: %v", err)
	}
	if final.Thinking != "check the mixer before answering" {
		t.Errorf("thinking = %q", final.Thinking)
	}
	if final.ThinkingSignature != "sig-abc" {
		t.Errorf("signature = %q", final.ThinkingSignature)
	}
	if len(final.ToolCalls) != 1 || final.ToolCalls[0].ID != "tu_1" {
		t.Errorf("tool calls = %+v", final.ToolCalls)
	}
}

func assistantContent(t *testing.T, body []byte) []map[string]any {
	t.Helper()
	var payload struct {
		Messages []struct {
			Role    string           `json:"role"`
			Content []map[string]any `json:"content"`
		} `json:"messages"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		t.Fatalf("request body: %v", err)
	}
	for _, m := range payload.Messages {
		if m.Role == "assistant" {
			return m.Content
		}
	}
	t.Fatal("no assistant message in the request")
	return nil
}

func toolRoundMessages() []Message {
	return []Message{
		{Role: "user", Content: "what is the volume"},
		{
			Role:              "assistant",
			Thinking:          "check the mixer",
			ThinkingSignature: "sig-abc",
			ToolCalls:         []ToolCall{{ID: "tu_1", Name: "audio_get_volume"}},
		},
		{Role: "tool", ToolCallID: "tu_1", Content: "54"},
	}
}

func TestThinkingIsReplayedAheadOfTheToolCall(t *testing.T) {
	var body []byte
	srv := stubAnthropic(t, "data: {\"type\":\"message_stop\"}\n", &body)
	defer srv.Close()

	err := testAnthropic(srv.URL).Chat(context.Background(), "claude-x",
		toolRoundMessages(), ChatOptions{Thinking: true},
		func(ChatChunk) error { return nil })
	if err != nil {
		t.Fatalf("chat: %v", err)
	}

	content := assistantContent(t, body)
	if len(content) == 0 || content[0]["type"] != "thinking" {
		t.Fatalf("thinking must lead the assistant turn, got %+v", content)
	}
	if content[0]["signature"] != "sig-abc" {
		t.Errorf("signature = %v", content[0]["signature"])
	}
	if content[len(content)-1]["type"] != "tool_use" {
		t.Errorf("tool_use must still be present, got %+v", content)
	}
}

// Replaying a thinking block into a request that never asked for thinking is
// itself a 400, so the guard has to hold in both directions.
func TestThinkingIsNotReplayedWhenDisabled(t *testing.T) {
	var body []byte
	srv := stubAnthropic(t, "data: {\"type\":\"message_stop\"}\n", &body)
	defer srv.Close()

	err := testAnthropic(srv.URL).Chat(context.Background(), "claude-x",
		toolRoundMessages(), ChatOptions{Thinking: false},
		func(ChatChunk) error { return nil })
	if err != nil {
		t.Fatalf("chat: %v", err)
	}

	for _, block := range assistantContent(t, body) {
		if block["type"] == "thinking" {
			t.Fatalf("thinking block leaked into a non-thinking request: %+v", block)
		}
	}
}
