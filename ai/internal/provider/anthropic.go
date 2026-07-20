package provider

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
)

type Anthropic struct {
	apiKey         string
	http           *http.Client
	models         []string
	maxTokens      int
	thinkingBudget int
}

func NewAnthropic(apiKey string, models []string, maxTokens, thinkingBudget int) *Anthropic {
	if len(models) == 0 {
		models = []string{"claude-haiku-4-5"}
	}
	if maxTokens <= 0 {
		maxTokens = 2048
	}
	// The API rejects budgets under 1024 tokens.
	if thinkingBudget < 1024 {
		thinkingBudget = 1024
	}
	return &Anthropic{
		apiKey:         apiKey,
		http:           streamingHTTPClient(),
		models:         models,
		maxTokens:      maxTokens,
		thinkingBudget: thinkingBudget,
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

func (a *Anthropic) Chat(ctx context.Context, model string, messages []Message, opts ChatOptions, fn func(ChatChunk) error) error {
	if a.apiKey == "" {
		return fmt.Errorf("ANTHROPIC_API_KEY is not set")
	}

	var systemBlocks []map[string]any
	msgs := make([]map[string]any, 0, len(messages))

	for _, m := range messages {
		if m.Role == "system" {
			systemBlocks = append(systemBlocks, map[string]any{
				"type": "text",
				"text": m.Content,
			})
			continue
		}
		if m.Role == "tool" {
			// Anthropic has no tool role: results ride on a user-role message
			// whose tool_result block references the prior tool_use id.
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

		var content []map[string]any
		if m.Content != "" {
			content = append(content, map[string]any{"type": "text", "text": m.Content})
		}
		for _, tc := range m.ToolCalls {
			args := tc.Arguments
			if args == nil {
				args = map[string]any{}
			}
			content = append(content, map[string]any{
				"type":  "tool_use",
				"id":    tc.ID,
				"name":  tc.Name,
				"input": args,
			})
		}
		if len(content) == 0 {
			continue
		}
		msgs = append(msgs, map[string]any{"role": role, "content": content})
	}

	var toolsPayload []map[string]any
	for _, t := range opts.Tools {
		toolsPayload = append(toolsPayload, map[string]any{
			"name":         t.Name,
			"description":  t.Description,
			"input_schema": t.Parameters,
		})
	}

	maxTokens := a.maxTokens
	if opts.Thinking && maxTokens < a.thinkingBudget+2048 {
		// budget_tokens must be < max_tokens, and the model still needs room
		// to answer after spending the reasoning budget.
		maxTokens = a.thinkingBudget + 2048
	}
	payload := map[string]any{
		"model":      model,
		"messages":   msgs,
		"max_tokens": maxTokens,
		"stream":     true,
	}
	if len(systemBlocks) > 0 {
		// The breakpoint goes on the first block (persona + memories, stable
		// across turns); the per-turn desktop snapshot sits after it so its
		// churn can't invalidate the cached prefix.
		systemBlocks[0]["cache_control"] = map[string]any{"type": "ephemeral"}
		payload["system"] = systemBlocks
	}
	if opts.Thinking {
		payload["thinking"] = map[string]any{
			"type":          "enabled",
			"budget_tokens": a.thinkingBudget,
		}
	}
	if len(toolsPayload) > 0 {
		// cache_control on the last tool covers the entire preceding tools
		// block, dropping input-token cost on cache hits to ~10%.
		toolsPayload[len(toolsPayload)-1]["cache_control"] = map[string]any{"type": "ephemeral"}
		payload["tools"] = toolsPayload
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.anthropic.com/v1/messages", bytes.NewReader(body))
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
		// Not all Claude tiers support extended thinking, so a rejection is
		// re-issued without it rather than failing the conversation.
		if resp.StatusCode == http.StatusBadRequest && opts.Thinking &&
			strings.Contains(strings.ToLower(string(b)), "thinking") {
			retry := opts
			retry.Thinking = false
			return a.Chat(ctx, model, messages, retry, fn)
		}
		return fmt.Errorf("anthropic: %s", parseAnthropicError(b, resp.StatusCode))
	}

	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 64*1024), 10*1024*1024)

	// tool_use blocks stream their args as input_json_delta, so they must be
	// accumulated per content_block index until content_block_stop.
	type pendingTool struct {
		ID      string
		Name    string
		JSONBuf strings.Builder
	}
	pending := map[int]*pendingTool{}
	var accumulated []ToolCall

	for scanner.Scan() {
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
				Type  string         `json:"type"`
				Text  string         `json:"text"`
				ID    string         `json:"id"`
				Name  string         `json:"name"`
				Input map[string]any `json:"input"`
			} `json:"content_block"`
			Delta struct {
				Type        string `json:"type"`
				Text        string `json:"text"`
				PartialJSON string `json:"partial_json"`
				StopReason  string `json:"stop_reason"`
			} `json:"delta"`
		}
		if err := json.Unmarshal([]byte(data), &evt); err != nil {
			continue
		}

		switch evt.Type {
		case "content_block_start":
			if evt.ContentBlock.Type == "tool_use" {
				pending[evt.Index] = &pendingTool{
					ID:   evt.ContentBlock.ID,
					Name: evt.ContentBlock.Name,
				}
			}
		case "content_block_delta":
			if evt.Delta.Type == "text_delta" && evt.Delta.Text != "" {
				if err := fn(ChatChunk{Content: evt.Delta.Text}); err != nil {
					return err
				}
			}
			if evt.Delta.Type == "input_json_delta" {
				if p, ok := pending[evt.Index]; ok {
					p.JSONBuf.WriteString(evt.Delta.PartialJSON)
				}
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
			if evt.Delta.StopReason != "" {
				final := ChatChunk{Done: true}
				if len(accumulated) > 0 {
					final.ToolCalls = accumulated
				}
				return fn(final)
			}
		case "message_stop":
			final := ChatChunk{Done: true}
			if len(accumulated) > 0 {
				final.ToolCalls = accumulated
			}
			return fn(final)
		}
	}
	return scanner.Err()
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
