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
	a := NewAnthropic("test-key", nil, 2048, "high")
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

func thinkingField(t *testing.T, body []byte) (map[string]any, map[string]any) {
	t.Helper()
	var payload struct {
		Thinking     map[string]any `json:"thinking"`
		OutputConfig map[string]any `json:"output_config"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		t.Fatalf("request body: %v", err)
	}
	return payload.Thinking, payload.OutputConfig
}

// budget_tokens was removed from the API and now 400s, so the shape of this
// field is the whole feature working or not working.
func TestThinkingAsksForAdaptiveDepth(t *testing.T) {
	var body []byte
	srv := stubAnthropic(t, "data: {\"type\":\"message_stop\"}\n", &body)
	defer srv.Close()

	err := testAnthropic(srv.URL).Chat(context.Background(), "claude-x",
		[]Message{{Role: "user", Content: "hi"}}, ChatOptions{Thinking: true},
		func(ChatChunk) error { return nil })
	if err != nil {
		t.Fatalf("chat: %v", err)
	}

	thinking, output := thinkingField(t, body)
	if thinking["type"] != "adaptive" {
		t.Errorf("thinking = %+v, want type adaptive", thinking)
	}
	if _, ok := thinking["budget_tokens"]; ok {
		t.Errorf("budget_tokens is rejected by the API: %+v", thinking)
	}
	if output["effort"] != "high" {
		t.Errorf("effort = %v, want high", output["effort"])
	}
}

// Leaving the field out reads as adaptive on newer models, so off has to be explicit.
func TestThinkingOffIsStatedExplicitly(t *testing.T) {
	var body []byte
	srv := stubAnthropic(t, "data: {\"type\":\"message_stop\"}\n", &body)
	defer srv.Close()

	err := testAnthropic(srv.URL).Chat(context.Background(), "claude-x",
		[]Message{{Role: "user", Content: "hi"}}, ChatOptions{Thinking: false},
		func(ChatChunk) error { return nil })
	if err != nil {
		t.Fatalf("chat: %v", err)
	}

	thinking, _ := thinkingField(t, body)
	if thinking["type"] != "disabled" {
		t.Errorf("thinking = %+v, want type disabled", thinking)
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

// Adaptive and output_config both 400 on pre-4.6 tiers, and claude-haiku-4-5 is
// the default fallback model, so this path is the common one, not the exotic one.
func TestLegacyModelAsksForABudget(t *testing.T) {
	var body []byte
	srv := stubAnthropic(t, "data: {\"type\":\"message_stop\"}\n", &body)
	defer srv.Close()

	err := testAnthropic(srv.URL).Chat(context.Background(), "claude-haiku-4-5",
		[]Message{{Role: "user", Content: "hi"}}, ChatOptions{Thinking: true},
		func(ChatChunk) error { return nil })
	if err != nil {
		t.Fatalf("chat: %v", err)
	}

	thinking, output := thinkingField(t, body)
	if thinking["type"] != "enabled" {
		t.Errorf("thinking = %+v, want type enabled", thinking)
	}
	if thinking["budget_tokens"] == nil {
		t.Errorf("legacy tiers need budget_tokens: %+v", thinking)
	}
	if output != nil {
		t.Errorf("output_config is rejected on legacy tiers: %+v", output)
	}
}

func TestThinkingOffIsOmittedWhereItCannotBeSaid(t *testing.T) {
	for _, model := range []string{"claude-fable-5", "claude-haiku-4-5"} {
		var body []byte
		srv := stubAnthropic(t, "data: {\"type\":\"message_stop\"}\n", &body)

		err := testAnthropic(srv.URL).Chat(context.Background(), model,
			[]Message{{Role: "user", Content: "hi"}}, ChatOptions{Thinking: false},
			func(ChatChunk) error { return nil })
		srv.Close()
		if err != nil {
			t.Fatalf("%s: chat: %v", model, err)
		}

		if thinking, _ := thinkingField(t, body); thinking != nil {
			t.Errorf("%s: sending thinking at all is a 400 here, got %+v", model, thinking)
		}
	}
}

// The rescue used to match the word "thinking" only, so an output_config
// rejection failed the turn outright instead of retrying without thinking.
func TestEffortRejectionFallsBackToNoThinking(t *testing.T) {
	var bodies [][]byte
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		bodies = append(bodies, b)
		if len(bodies) == 1 {
			w.WriteHeader(http.StatusBadRequest)
			io.WriteString(w, `{"error":{"type":"invalid_request_error","message":"output_config.effort: unsupported"}}`)
			return
		}
		w.Header().Set("Content-Type", "text/event-stream")
		io.WriteString(w, "data: {\"type\":\"message_stop\"}\n")
	}))
	defer srv.Close()

	err := testAnthropic(srv.URL).Chat(context.Background(), "claude-x",
		[]Message{{Role: "user", Content: "hi"}}, ChatOptions{Thinking: true},
		func(ChatChunk) error { return nil })
	if err != nil {
		t.Fatalf("chat: %v", err)
	}
	if len(bodies) != 2 {
		t.Fatalf("want one retry, got %d request(s)", len(bodies))
	}

	thinking, output := thinkingField(t, bodies[1])
	if thinking["type"] != "disabled" {
		t.Errorf("retry thinking = %+v, want disabled", thinking)
	}
	if output != nil {
		t.Errorf("retry must drop output_config: %+v", output)
	}
}
