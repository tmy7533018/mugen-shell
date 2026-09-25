package provider

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"sync/atomic"
	"time"
)

// Adaptive thinking spends from max_tokens, so each depth needs its own headroom on top of the reply cap.
var effortHeadroom = map[string]int{
	"low":    4096,
	"medium": 8192,
	"high":   16384,
	"xhigh":  32768,
	"max":    65536,
}

// Deny-listing the pre-4.6 tiers keeps models released after this code on the adaptive path.
func usesLegacyThinking(model string) bool {
	for _, p := range []string{"claude-haiku-4-5", "claude-sonnet-4-5", "claude-opus-4-5", "claude-3"} {
		if strings.HasPrefix(model, p) {
			return true
		}
	}
	return false
}

// These think unconditionally, and an explicit "disabled" is a 400.
func thinkingAlwaysOn(model string) bool {
	for _, p := range []string{"claude-fable-", "claude-mythos-", "claude-opus-5-5"} {
		if strings.HasPrefix(model, p) {
			return true
		}
	}
	return false
}

const lowestEffort = "low"

const thinkingSummaryBreak = "\n\n"

// Per the preserved-thinking docs, Mythos 5.1 and every model before Fable 5.1 skip the check.
func checksThinkingPrefix(model string) bool {
	for _, p := range []string{"claude-3", "claude-haiku-4", "claude-sonnet-4", "claude-opus-4"} {
		if strings.HasPrefix(model, p) {
			return false
		}
	}
	for _, id := range []string{"claude-opus-5", "claude-sonnet-5", "claude-fable-5", "claude-mythos-5", "claude-mythos-5-1", "claude-mythos-preview"} {
		if isModelOrSnapshot(model, id) {
			return false
		}
	}
	return true
}

// A dated snapshot extends the ID with eight digits, where a later minor version adds one or two.
func isModelOrSnapshot(model, id string) bool {
	rest, ok := strings.CutPrefix(model, id)
	if !ok || rest == "" {
		return ok
	}
	date, ok := strings.CutPrefix(rest, "-")
	if !ok || len(date) != 8 {
		return false
	}
	for _, r := range date {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}

func rejectedThinkingField(body []byte) bool {
	s := strings.ToLower(string(body))
	for _, k := range []string{"thinking", "output_config", "effort", "budget_tokens"} {
		if strings.Contains(s, k) {
			return true
		}
	}
	return false
}

type Anthropic struct {
	apiKey    string
	http      *http.Client
	models    []string
	maxTokens int
	effort    string
	baseURL   string
}

func NewAnthropic(apiKey string, models []string, maxTokens int, effort string) *Anthropic {
	if len(models) == 0 {
		models = []string{"claude-haiku-4-5"}
	}
	if maxTokens <= 0 {
		maxTokens = 2048
	}
	if _, ok := effortHeadroom[effort]; !ok {
		effort = "high"
	}
	return &Anthropic{
		apiKey:    apiKey,
		http:      streamingHTTPClient(),
		models:    models,
		maxTokens: maxTokens,
		effort:    effort,
		baseURL:   "https://api.anthropic.com",
	}
}

func (a *Anthropic) Name() string { return "anthropic" }

func (a *Anthropic) Ping(_ context.Context) bool {
	return a.apiKey != ""
}

func (a *Anthropic) Models(_ context.Context) ([]string, error) {
	if a.apiKey == "" {
		return nil, nil
	}
	return a.models, nil
}

// A reply as it streamed, block by block, so a tool round can send the turn back unaltered.
type anthropicTurn struct {
	blocks []anthropicBlock
	prefix string
}

type anthropicBlock struct {
	kind      string
	text      string
	thinking  string
	signature string
	data      string
	toolUseID string
}

func (t *anthropicTurn) signed() bool {
	for _, b := range t.blocks {
		if (b.kind == "thinking" && b.signature != "") || (b.kind == "redacted_thinking" && b.data != "") {
			return true
		}
	}
	return false
}

func (t *anthropicTurn) content(calls []ToolCall, withThinking bool) []map[string]any {
	unsent := make(map[string]ToolCall, len(calls))
	for _, tc := range calls {
		unsent[tc.ID] = tc
	}
	var out []map[string]any
	for _, b := range t.blocks {
		switch b.kind {
		case "thinking":
			if withThinking && b.signature != "" {
				out = append(out, map[string]any{"type": "thinking", "thinking": b.thinking, "signature": b.signature})
			}
		case "redacted_thinking":
			if withThinking && b.data != "" {
				out = append(out, map[string]any{"type": "redacted_thinking", "data": b.data})
			}
		case "text":
			if b.text != "" {
				out = append(out, map[string]any{"type": "text", "text": b.text})
			}
		case "tool_use":
			if tc, ok := unsent[b.toolUseID]; ok {
				out = append(out, toolUseBlock(tc))
				delete(unsent, b.toolUseID)
			}
		}
	}
	for _, tc := range calls {
		if _, ok := unsent[tc.ID]; ok {
			out = append(out, toolUseBlock(tc))
		}
	}
	return out
}

func toolUseBlock(tc ToolCall) map[string]any {
	args := tc.Arguments
	if args == nil {
		args = map[string]any{}
	}
	return map[string]any{
		"type":  "tool_use",
		"id":    tc.ID,
		"name":  tc.Name,
		"input": args,
	}
}

// Preserved thinking is bound to the system prompt and tools it was produced under.
func prefixKey(system, tools []map[string]any) string {
	b, _ := json.Marshal([]any{system, tools})
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

func (a *Anthropic) Chat(ctx context.Context, model string, messages []Message, opts ChatOptions, fn func(ChatChunk) error) error {
	return a.chat(ctx, model, messages, opts, thinkingAlwaysOn(model), fn)
}

func (a *Anthropic) chat(ctx context.Context, model string, messages []Message, opts ChatOptions, alwaysOn bool, fn func(ChatChunk) error) error {
	if a.apiKey == "" {
		return fmt.Errorf("ANTHROPIC_API_KEY is not set")
	}

	var systemBlocks []map[string]any
	for _, m := range messages {
		if m.Role == "system" {
			systemBlocks = append(systemBlocks, map[string]any{
				"type": "text",
				"text": m.Content,
			})
		}
	}
	if len(systemBlocks) > 0 {
		// Persona + memories are stable, so the per-turn snapshot must sit after the breakpoint.
		systemBlocks[0]["cache_control"] = map[string]any{"type": "ephemeral"}
	}

	var toolsPayload []map[string]any
	for _, t := range opts.Tools {
		toolsPayload = append(toolsPayload, map[string]any{
			"name":         t.Name,
			"description":  t.Description,
			"input_schema": t.Parameters,
		})
	}
	if len(toolsPayload) > 0 {
		// cache_control on the last tool covers the whole preceding block: ~10% input cost on hits.
		toolsPayload[len(toolsPayload)-1]["cache_control"] = map[string]any{"type": "ephemeral"}
	}

	prefix := prefixKey(systemBlocks, toolsPayload)
	thinkingOn := opts.Thinking || alwaysOn
	msgs := make([]map[string]any, 0, len(messages))

	for _, m := range messages {
		if m.Role == "system" {
			continue
		}
		if m.Role == "tool" {
			// Anthropic has no tool role: results ride on a user message referencing the tool_use id.
			msgs = append(msgs, map[string]any{
				"role": "user",
				"content": []map[string]any{{
					"type":        "tool_result",
					"tool_use_id": m.ToolCallID,
					"content":     m.Content,
				}},
			})
			continue
		}

		role := m.Role
		if role != "user" && role != "assistant" {
			continue
		}

		if len(m.ToolCalls) > 0 && m.ToolCalls[0].anthropic != nil {
			turn := m.ToolCalls[0].anthropic
			replay := thinkingOn && turn.signed() && (!checksThinkingPrefix(model) || turn.prefix == prefix)
			msgs = append(msgs, map[string]any{"role": role, "content": turn.content(m.ToolCalls, replay)})
			continue
		}

		var content []map[string]any
		for _, img := range m.Images {
			content = append(content, map[string]any{
				"type": "image",
				"source": map[string]any{
					"type":       "base64",
					"media_type": img.MediaType,
					"data":       img.Data,
				},
			})
		}
		if m.Content != "" {
			content = append(content, map[string]any{"type": "text", "text": m.Content})
		}
		for _, tc := range m.ToolCalls {
			content = append(content, toolUseBlock(tc))
		}
		if len(content) == 0 {
			continue
		}
		msgs = append(msgs, map[string]any{"role": role, "content": content})
	}

	maxTokens := a.maxTokens
	switch {
	case opts.Thinking:
		maxTokens += effortHeadroom[a.effort]
	case alwaysOn:
		maxTokens += effortHeadroom[lowestEffort]
	}
	payload := map[string]any{
		"model":      model,
		"messages":   msgs,
		"max_tokens": maxTokens,
		"stream":     true,
	}
	if len(systemBlocks) > 0 {
		payload["system"] = systemBlocks
	}
	if opts.Thinking {
		if usesLegacyThinking(model) {
			payload["thinking"] = map[string]any{"type": "enabled", "budget_tokens": effortHeadroom[a.effort]}
		} else {
			// Newer models default to "omitted", which streams every thinking block empty.
			payload["thinking"] = map[string]any{"type": "adaptive", "display": "summarized"}
			payload["output_config"] = map[string]any{"effort": a.effort}
		}
	} else if alwaysOn {
		// Thinking cannot be switched off here, so "off" is the least of it the model allows.
		payload["output_config"] = map[string]any{"effort": lowestEffort}
	} else if !usesLegacyThinking(model) {
		// Omitting the field leaves thinking on for newer models, so "off" has to be said out loud.
		payload["thinking"] = map[string]any{"type": "disabled"}
	}
	if len(toolsPayload) > 0 {
		payload["tools"] = toolsPayload
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, a.baseURL+"/v1/messages", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-api-key", a.apiKey)
	req.Header.Set("anthropic-version", "2023-06-01")

	resp, err := a.http.Do(req)
	if err != nil {
		return fmt.Errorf("anthropic unreachable: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		if resp.StatusCode == http.StatusBadRequest && rejectedThinkingField(b) {
			switch {
			// Not all Claude tiers support extended thinking, so a rejection is re-issued without it.
			case opts.Thinking:
				// Silently dropping it turns a hard failure into thinking that never runs.
				fmt.Fprintf(os.Stderr, "anthropic: %s rejected the thinking request, retrying without it: %s\n",
					model, parseAnthropicError(b, resp.StatusCode))
				retry := opts
				retry.Thinking = false
				return a.chat(ctx, model, messages, retry, alwaysOn, fn)
			// A model missing from thinkingAlwaysOn rejects "disabled" the same way.
			case !alwaysOn && !usesLegacyThinking(model):
				fmt.Fprintf(os.Stderr, "anthropic: %s rejected disabling thinking, retrying with it left on: %s\n",
					model, parseAnthropicError(b, resp.StatusCode))
				return a.chat(ctx, model, messages, opts, true, fn)
			}
		}
		return fmt.Errorf("anthropic: %s", parseAnthropicError(b, resp.StatusCode))
	}

	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 64*1024), 10*1024*1024)

	var stalled atomic.Bool
	stall := time.AfterFunc(streamStallTimeout, func() {
		stalled.Store(true)
		cancel()
	})
	defer stall.Stop()

	// tool_use args stream as input_json_delta, so accumulate per index until content_block_stop.
	type pendingTool struct {
		ID      string
		Name    string
		JSONBuf strings.Builder
	}
	pending := map[int]*pendingTool{}
	var accumulated []ToolCall
	var thinkingBuf strings.Builder
	var blocks []*anthropicBlock
	blockAt := map[int]*anthropicBlock{}
	var shownThinking *anthropicBlock

	finalChunk := func() ChatChunk {
		c := ChatChunk{Done: true, Thinking: thinkingBuf.String()}
		if len(accumulated) > 0 {
			turn := &anthropicTurn{prefix: prefix}
			for _, b := range blocks {
				turn.blocks = append(turn.blocks, *b)
			}
			for i := range accumulated {
				accumulated[i].anthropic = turn
			}
			c.ToolCalls = accumulated
		}
		return c
	}

	for scanner.Scan() {
		stall.Reset(streamStallTimeout)
		line := strings.TrimSpace(scanner.Text())
		if !strings.HasPrefix(line, "data:") {
			continue
		}
		data := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
		if data == "" {
			continue
		}

		var evt struct {
			Type         string `json:"type"`
			Index        int    `json:"index"`
			ContentBlock struct {
				Type      string         `json:"type"`
				Text      string         `json:"text"`
				Thinking  string         `json:"thinking"`
				Signature string         `json:"signature"`
				Data      string         `json:"data"`
				ID        string         `json:"id"`
				Name      string         `json:"name"`
				Input     map[string]any `json:"input"`
			} `json:"content_block"`
			Delta struct {
				Type        string `json:"type"`
				Text        string `json:"text"`
				PartialJSON string `json:"partial_json"`
				StopReason  string `json:"stop_reason"`
				Thinking    string `json:"thinking"`
				Signature   string `json:"signature"`
			} `json:"delta"`
		}
		if err := json.Unmarshal([]byte(data), &evt); err != nil {
			continue
		}

		switch evt.Type {
		case "error":
			return fmt.Errorf("anthropic: %s", parseAnthropicError([]byte(data), resp.StatusCode))
		case "content_block_start":
			b := &anthropicBlock{
				kind:      evt.ContentBlock.Type,
				text:      evt.ContentBlock.Text,
				thinking:  evt.ContentBlock.Thinking,
				signature: evt.ContentBlock.Signature,
				data:      evt.ContentBlock.Data,
				toolUseID: evt.ContentBlock.ID,
			}
			blocks = append(blocks, b)
			blockAt[evt.Index] = b
			if evt.ContentBlock.Type == "tool_use" {
				pending[evt.Index] = &pendingTool{
					ID:   evt.ContentBlock.ID,
					Name: evt.ContentBlock.Name,
				}
			}
		case "content_block_delta":
			b := blockAt[evt.Index]
			if b == nil {
				b = &anthropicBlock{}
				blockAt[evt.Index] = b
			}
			if evt.Delta.Type == "text_delta" && evt.Delta.Text != "" {
				b.text += evt.Delta.Text
				if err := fn(ChatChunk{Content: evt.Delta.Text}); err != nil {
					return err
				}
			}
			if evt.Delta.Type == "input_json_delta" {
				if p, ok := pending[evt.Index]; ok {
					p.JSONBuf.WriteString(evt.Delta.PartialJSON)
				}
			}
			if evt.Delta.Type == "thinking_delta" && evt.Delta.Thinking != "" {
				b.thinking += evt.Delta.Thinking
				shown := evt.Delta.Thinking
				if shownThinking != b && thinkingBuf.Len() > 0 {
					shown = thinkingSummaryBreak + shown
				}
				shownThinking = b
				thinkingBuf.WriteString(shown)
				if err := fn(ChatChunk{ThinkingDelta: shown}); err != nil {
					return err
				}
			}
			if evt.Delta.Type == "signature_delta" {
				b.signature = evt.Delta.Signature
			}
		case "content_block_stop":
			if p, ok := pending[evt.Index]; ok {
				args := map[string]any{}
				if p.JSONBuf.Len() > 0 {
					if err := json.Unmarshal([]byte(p.JSONBuf.String()), &args); err != nil {
						args = map[string]any{"_raw": p.JSONBuf.String()}
					}
				}
				accumulated = append(accumulated, ToolCall{
					ID:        p.ID,
					Name:      p.Name,
					Arguments: args,
				})
				delete(pending, evt.Index)
			}
		case "message_delta":
			if evt.Delta.StopReason == "max_tokens" {
				return truncatedStream("anthropic")
			}
			if evt.Delta.StopReason != "" {
				return fn(finalChunk())
			}
		case "message_stop":
			return fn(finalChunk())
		}
	}
	if err := scanner.Err(); err != nil {
		if stalled.Load() {
			return fmt.Errorf("anthropic stopped sending output for %s", streamStallTimeout)
		}
		return err
	}
	return truncatedStream("anthropic")
}

func parseAnthropicError(body []byte, status int) string {
	var e struct {
		Error struct {
			Type    string `json:"type"`
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.Unmarshal(body, &e); err == nil && e.Error.Message != "" {
		msg := strings.SplitN(e.Error.Message, "\n", 2)[0]
		if e.Error.Type != "" {
			return fmt.Sprintf("%s (%s)", msg, e.Error.Type)
		}
		return msg
	}
	return fmt.Sprintf("HTTP %d", status)
}
