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

func stubAnthropicRounds(t *testing.T, bodies *[][]byte, streams ...string) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		*bodies = append(*bodies, b)
		sse := "data: {\"type\":\"message_stop\"}\n"
		if n := len(*bodies); n <= len(streams) {
			sse = streams[n-1]
		}
		w.Header().Set("Content-Type", "text/event-stream")
		io.WriteString(w, sse)
	}))
}

func sseLines(lines ...string) string {
	return strings.Join(append(lines, ""), "\n")
}

func requestShape(t *testing.T, body []byte) (thinking, output map[string]any, maxTokens int) {
	t.Helper()
	var payload struct {
		Thinking     map[string]any `json:"thinking"`
		OutputConfig map[string]any `json:"output_config"`
		MaxTokens    int            `json:"max_tokens"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		t.Fatalf("request body: %v", err)
	}
	return payload.Thinking, payload.OutputConfig, payload.MaxTokens
}

func toolRound(t *testing.T, model string, first, second ChatOptions, sse string) (final ChatChunk, replayed []map[string]any) {
	t.Helper()
	var bodies [][]byte
	srv := stubAnthropicRounds(t, &bodies, sse)
	defer srv.Close()
	a := testAnthropic(srv.URL)

	msgs := []Message{{Role: "system", Content: "persona"}, {Role: "user", Content: "volume and brightness?"}}
	var text string
	err := a.Chat(context.Background(), model, msgs, first, func(c ChatChunk) error {
		text += c.Content
		if c.Done {
			final = c
		}
		return nil
	})
	if err != nil {
		t.Fatalf("first round: %v", err)
	}
	msgs = append(msgs, Message{
		Role:              "assistant",
		Content:           text,
		ToolCalls:         final.ToolCalls,
		Thinking:          final.Thinking,
		ThinkingSignature: final.ThinkingSignature,
	})
	for _, tc := range final.ToolCalls {
		msgs = append(msgs, Message{Role: "tool", ToolCallID: tc.ID, ToolName: tc.Name, Content: "ok"})
	}
	if err := a.Chat(context.Background(), model, msgs, second, func(ChatChunk) error { return nil }); err != nil {
		t.Fatalf("second round: %v", err)
	}
	if len(bodies) != 2 {
		t.Fatalf("want 2 requests, got %d", len(bodies))
	}
	return final, assistantContent(t, bodies[1])
}

func blockTypes(content []map[string]any) []string {
	var types []string
	for _, b := range content {
		types = append(types, b["type"].(string))
	}
	return types
}

func interleavedReply() string {
	return sseLines(
		`data: {"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"","signature":""}}`,
		`data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"weigh "}}`,
		`data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"both"}}`,
		`data: {"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"s1"}}`,
		`data: {"type":"content_block_stop","index":0}`,
		`data: {"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}`,
		`data: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"Checking."}}`,
		`data: {"type":"content_block_stop","index":1}`,
		`data: {"type":"content_block_start","index":2,"content_block":{"type":"thinking","thinking":"","signature":""}}`,
		`data: {"type":"content_block_delta","index":2,"delta":{"type":"thinking_delta","thinking":""}}`,
		`data: {"type":"content_block_delta","index":2,"delta":{"type":"signature_delta","signature":"s2"}}`,
		`data: {"type":"content_block_stop","index":2}`,
		`data: {"type":"content_block_start","index":3,"content_block":{"type":"tool_use","id":"tu_1","name":"audio_get_volume","input":{}}}`,
		`data: {"type":"content_block_delta","index":3,"delta":{"type":"input_json_delta","partial_json":"{}"}}`,
		`data: {"type":"content_block_stop","index":3}`,
		`data: {"type":"content_block_start","index":4,"content_block":{"type":"thinking","thinking":"","signature":""}}`,
		`data: {"type":"content_block_delta","index":4,"delta":{"type":"thinking_delta","thinking":"then the screen"}}`,
		`data: {"type":"content_block_delta","index":4,"delta":{"type":"signature_delta","signature":"s3"}}`,
		`data: {"type":"content_block_stop","index":4}`,
		`data: {"type":"content_block_start","index":5,"content_block":{"type":"tool_use","id":"tu_2","name":"brightness_get","input":{}}}`,
		`data: {"type":"content_block_delta","index":5,"delta":{"type":"input_json_delta","partial_json":"{}"}}`,
		`data: {"type":"content_block_stop","index":5}`,
		`data: {"type":"message_delta","delta":{"stop_reason":"tool_use"}}`,
	)
}

// Merging, reordering or dropping any of several signed blocks per reply is a 400.
func TestInterleavedThinkingRoundTripsBlockByBlock(t *testing.T) {
	final, content := toolRound(t, "claude-sonnet-4-6", ChatOptions{Thinking: true}, ChatOptions{Thinking: true}, interleavedReply())

	if final.Thinking != "weigh both\n\nthen the screen" || final.ThinkingSignature != "s3" {
		t.Errorf("final chunk thinking = %q / %q", final.Thinking, final.ThinkingSignature)
	}

	want := []string{"thinking", "text", "thinking", "tool_use", "thinking", "tool_use"}
	if got := blockTypes(content); strings.Join(got, ",") != strings.Join(want, ",") {
		t.Fatalf("assistant blocks = %v, want %v", got, want)
	}
	for i, w := range []struct {
		idx       int
		text, sig string
	}{{0, "weigh both", "s1"}, {2, "", "s2"}, {4, "then the screen", "s3"}} {
		b := content[w.idx]
		text, present := b["thinking"]
		if !present || text != w.text || b["signature"] != w.sig {
			t.Errorf("thinking block %d = %+v, want text %q sig %q", i, b, w.text, w.sig)
		}
	}
	if content[1]["text"] != "Checking." || content[3]["id"] != "tu_1" || content[5]["id"] != "tu_2" {
		t.Errorf("text/tool_use out of place: %+v", content)
	}
}

func TestThinkingDeltasCarryTheSummaryBreak(t *testing.T) {
	var bodies [][]byte
	srv := stubAnthropicRounds(t, &bodies, interleavedReply())
	defer srv.Close()
	a := testAnthropic(srv.URL)

	var deltas []string
	msgs := []Message{{Role: "user", Content: "volume and brightness?"}}
	err := a.Chat(context.Background(), "claude-sonnet-4-6", msgs, ChatOptions{Thinking: true}, func(c ChatChunk) error {
		if c.ThinkingDelta != "" {
			deltas = append(deltas, c.ThinkingDelta)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if got := strings.Join(deltas, ""); got != "weigh both\n\nthen the screen" {
		t.Fatalf("streamed thinking = %q", got)
	}
}

func TestRedactedThinkingRoundTrips(t *testing.T) {
	sse := sseLines(
		`data: {"type":"content_block_start","index":0,"content_block":{"type":"redacted_thinking","data":"enc-1"}}`,
		`data: {"type":"content_block_stop","index":0}`,
		`data: {"type":"content_block_start","index":1,"content_block":{"type":"thinking","thinking":"","signature":""}}`,
		`data: {"type":"content_block_delta","index":1,"delta":{"type":"signature_delta","signature":"s1"}}`,
		`data: {"type":"content_block_stop","index":1}`,
		`data: {"type":"content_block_start","index":2,"content_block":{"type":"tool_use","id":"tu_1","name":"audio_get_volume","input":{}}}`,
		`data: {"type":"content_block_stop","index":2}`,
		`data: {"type":"message_stop"}`,
	)
	_, content := toolRound(t, "claude-opus-4-7", ChatOptions{Thinking: true}, ChatOptions{Thinking: true}, sse)

	if got := strings.Join(blockTypes(content), ","); got != "redacted_thinking,thinking,tool_use" {
		t.Fatalf("assistant blocks = %s", got)
	}
	if content[0]["data"] != "enc-1" || content[1]["signature"] != "s1" {
		t.Errorf("blocks altered: %+v", content)
	}
}

// Manual-budget tiers insist the last assistant turn opens with its thinking block.
func TestLegacyModelStillLeadsWithItsThinkingBlock(t *testing.T) {
	first := ChatOptions{Thinking: true, Tools: []Tool{{Name: "audio_get_volume"}}}
	second := ChatOptions{Thinking: true, Tools: []Tool{{Name: "audio_get_volume"}, {Name: "brightness_get"}}}
	_, content := toolRound(t, "claude-haiku-4-5", first, second, thinkingThenToolCall())

	if got := strings.Join(blockTypes(content), ","); got != "thinking,tool_use" {
		t.Fatalf("assistant blocks = %s", got)
	}
	if content[0]["thinking"] != "check the mixer before answering" || content[0]["signature"] != "sig-abc" {
		t.Errorf("thinking block = %+v", content[0])
	}
}

// A narrowed first request is widened on the next one, which the prefix check rejects.
func TestThinkingIsNotReplayedAcrossAToolChange(t *testing.T) {
	first := ChatOptions{Thinking: true, Tools: []Tool{{Name: "audio_get_volume"}}}
	second := ChatOptions{Thinking: true, Tools: []Tool{{Name: "audio_get_volume"}, {Name: "brightness_get"}}}
	for _, model := range []string{"claude-opus-5-5", "claude-fable-5-1", "claude-opus-6"} {
		_, content := toolRound(t, model, first, second, interleavedReply())

		if got := strings.Join(blockTypes(content), ","); got != "text,tool_use,tool_use" {
			t.Errorf("%s: assistant blocks = %s, want thinking stripped and the rest in order", model, got)
		}
	}
}

func TestThinkingIsReplayedAcrossAToolChangeWhereNoPrefixIsChecked(t *testing.T) {
	first := ChatOptions{Thinking: true, Tools: []Tool{{Name: "audio_get_volume"}}}
	second := ChatOptions{Thinking: true, Tools: []Tool{{Name: "audio_get_volume"}, {Name: "brightness_get"}}}
	for _, model := range []string{"claude-sonnet-4-6", "claude-opus-4-7", "claude-opus-5", "claude-mythos-5-1"} {
		_, content := toolRound(t, model, first, second, interleavedReply())

		if got := strings.Join(blockTypes(content), ","); got != "thinking,text,thinking,tool_use,thinking,tool_use" {
			t.Errorf("%s: assistant blocks = %s", model, got)
			continue
		}
		for i, sig := range map[int]string{0: "s1", 2: "s2", 4: "s3"} {
			if content[i]["signature"] != sig {
				t.Errorf("%s: block %d = %+v, want signature %s", model, i, content[i], sig)
			}
		}
	}
}

func TestPrefixCheckTellsSnapshotsFromLaterVersions(t *testing.T) {
	for model, want := range map[string]bool{
		"claude-opus-5":          false,
		"claude-opus-5-20260401": false,
		"claude-opus-5-5":        true,
		"claude-fable-5":         false,
		"claude-fable-5-1":       true,
		"claude-mythos-5-1":      false,
		"claude-haiku-4-5":       false,
		"claude-sonnet-5-5":      true,
	} {
		if got := checksThinkingPrefix(model); got != want {
			t.Errorf("checksThinkingPrefix(%q) = %v, want %v", model, got, want)
		}
	}
}

// These models think with the toggle off too, and a tool round still needs the blocks back.
func TestAlwaysOnModelReplaysWithTheToggleOff(t *testing.T) {
	_, content := toolRound(t, "claude-fable-5-1", ChatOptions{}, ChatOptions{}, interleavedReply())

	if got := strings.Join(blockTypes(content), ","); got != "thinking,text,thinking,tool_use,thinking,tool_use" {
		t.Fatalf("assistant blocks = %s", got)
	}
}

func TestRoundTripIsNotReplayedIntoARequestWithoutThinking(t *testing.T) {
	_, content := toolRound(t, "claude-x", ChatOptions{Thinking: true}, ChatOptions{}, interleavedReply())

	if got := strings.Join(blockTypes(content), ","); got != "text,tool_use,tool_use" {
		t.Fatalf("assistant blocks = %s", got)
	}
}

// Without an explicit display these models stream every thinking block empty.
func TestThinkingAsksForReadableSummariesWhereAccepted(t *testing.T) {
	cases := []struct {
		model       string
		wantDisplay any
	}{
		{"claude-opus-4-7", "summarized"},
		{"claude-sonnet-4-6", "summarized"},
		{"claude-fable-5-1", "summarized"},
		{"claude-haiku-4-5", nil},
	}
	for _, tc := range cases {
		var body []byte
		srv := stubAnthropic(t, "data: {\"type\":\"message_stop\"}\n", &body)
		err := testAnthropic(srv.URL).Chat(context.Background(), tc.model,
			[]Message{{Role: "user", Content: "hi"}}, ChatOptions{Thinking: true},
			func(ChatChunk) error { return nil })
		srv.Close()
		if err != nil {
			t.Fatalf("%s: chat: %v", tc.model, err)
		}
		thinking, _, _ := requestShape(t, body)
		if thinking["display"] != tc.wantDisplay {
			t.Errorf("%s: display = %v, want %v", tc.model, thinking["display"], tc.wantDisplay)
		}
	}
}

// Thinking still spends from max_tokens when it cannot be switched off.
func TestAlwaysOnModelsTurnThinkingDownWhenOff(t *testing.T) {
	for _, model := range []string{"claude-opus-5-5", "claude-fable-5-1"} {
		var body []byte
		srv := stubAnthropic(t, "data: {\"type\":\"message_stop\"}\n", &body)
		err := testAnthropic(srv.URL).Chat(context.Background(), model,
			[]Message{{Role: "user", Content: "hi"}}, ChatOptions{},
			func(ChatChunk) error { return nil })
		srv.Close()
		if err != nil {
			t.Fatalf("%s: chat: %v", model, err)
		}
		thinking, output, maxTokens := requestShape(t, body)
		if thinking != nil {
			t.Errorf("%s: thinking = %+v, want the field omitted", model, thinking)
		}
		if output["effort"] != "low" {
			t.Errorf("%s: effort = %v, want low", model, output["effort"])
		}
		if want := 2048 + effortHeadroom["low"]; maxTokens != want {
			t.Errorf("%s: max_tokens = %d, want %d", model, maxTokens, want)
		}
	}
}

// A model missing from thinkingAlwaysOn would otherwise fail every turn with the toggle off.
func TestDisabledRejectionRetriesWithThinkingLeftOn(t *testing.T) {
	var bodies [][]byte
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		bodies = append(bodies, b)
		if len(bodies) == 1 {
			w.WriteHeader(http.StatusBadRequest)
			io.WriteString(w, `{"error":{"type":"invalid_request_error","message":"\"thinking.type.disabled\" is not supported for this model."}}`)
			return
		}
		w.Header().Set("Content-Type", "text/event-stream")
		io.WriteString(w, "data: {\"type\":\"message_stop\"}\n")
	}))
	defer srv.Close()

	err := testAnthropic(srv.URL).Chat(context.Background(), "claude-x",
		[]Message{{Role: "user", Content: "hi"}}, ChatOptions{},
		func(ChatChunk) error { return nil })
	if err != nil {
		t.Fatalf("chat: %v", err)
	}
	if len(bodies) != 2 {
		t.Fatalf("want one retry, got %d request(s)", len(bodies))
	}
	if thinking, _, _ := requestShape(t, bodies[0]); thinking["type"] != "disabled" {
		t.Fatalf("first request thinking = %+v, want disabled", thinking)
	}
	thinking, output, maxTokens := requestShape(t, bodies[1])
	if thinking != nil {
		t.Errorf("retry thinking = %+v, want the field omitted", thinking)
	}
	if output["effort"] != "low" || maxTokens != 2048+effortHeadroom["low"] {
		t.Errorf("retry effort = %v, max_tokens = %d", output["effort"], maxTokens)
	}
}
