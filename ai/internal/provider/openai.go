package provider

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"sort"
	"strings"
	"time"
)

type OpenAI struct {
	baseURL     string
	apiKey      string
	fixedModels []string
	http        *http.Client
}

func NewOpenAI(baseURL, apiKey string, fixedModels []string) *OpenAI {
	if baseURL == "" {
		baseURL = "https://api.openai.com/v1"
	}
	return &OpenAI{
		baseURL:     strings.TrimRight(baseURL, "/"),
		apiKey:      apiKey,
		fixedModels: fixedModels,
		http:        &http.Client{Timeout: 120 * time.Second},
	}
}

func (o *OpenAI) Name() string { return "openai" }

func (o *OpenAI) Ping(_ context.Context) bool {
	if o.apiKey != "" {
		return true
	}
	// Local servers (LM Studio / vLLM) often skip the key.
	return strings.HasPrefix(o.baseURL, "http://localhost") ||
		strings.HasPrefix(o.baseURL, "http://127.")
}

func (o *OpenAI) Models(ctx context.Context) ([]string, error) {
	if len(o.fixedModels) > 0 {
		return o.fixedModels, nil
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, o.baseURL+"/models", nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "mugen-ai/0.1")
	if o.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+o.apiKey)
	}
	resp, err := o.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("openai unreachable: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("openai /models: HTTP %d", resp.StatusCode)
	}
	var result struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	models := make([]string, len(result.Data))
	for i, m := range result.Data {
		models[i] = m.ID
	}
	return models, nil
}

func (o *OpenAI) Chat(ctx context.Context, model string, messages []Message, opts ChatOptions, fn func(ChatChunk) error) error {
	msgs, err := openAIMessages(messages)
	if err != nil {
		return err
	}

	payload := map[string]any{
		"model":    model,
		"messages": msgs,
		"stream":   true,
	}
	if tw := toolsAsOpenAI(opts.Tools); len(tw) > 0 {
		payload["tools"] = tw
	}
	if opts.Thinking {
		// OpenAI / OpenRouter accept reasoning_effort for o-series and a few
		// other reasoning-capable models; non-reasoning models silently
		// ignore the field on the official API. We still retry without it
		// below if a strict server returns 400.
		payload["reasoning_effort"] = "medium"
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, o.baseURL+"/chat/completions", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "mugen-ai/0.1")
	if o.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+o.apiKey)
	}

	resp, err := o.http.Do(req)
	if err != nil {
		return fmt.Errorf("openai unreachable: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		// Some OpenAI-compat servers strictly reject reasoning_effort on
		// non-reasoning models; retry without it instead of failing.
		if resp.StatusCode == http.StatusBadRequest && opts.Thinking &&
			strings.Contains(strings.ToLower(string(b)), "reasoning") {
			retry := opts
			retry.Thinking = false
			return o.Chat(ctx, model, messages, retry, fn)
		}
		return fmt.Errorf("openai: %s", parseOpenAIError(b, resp.StatusCode))
	}

	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)

	// Streaming tool calls arrive as deltas indexed by `index`; assemble
	// per-index buffers until finish_reason fires.
	type pending struct {
		ID   string
		Name string
		Args strings.Builder
	}
	calls := map[int]*pending{}

	var chunk struct {
		Choices []struct {
			Delta struct {
				Content   string `json:"content"`
				ToolCalls []struct {
					Index    int    `json:"index"`
					ID       string `json:"id"`
					Function struct {
						Name      string `json:"name"`
						Arguments string `json:"arguments"`
					} `json:"function"`
				} `json:"tool_calls"`
			} `json:"delta"`
			FinishReason string `json:"finish_reason"`
		} `json:"choices"`
	}

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if !strings.HasPrefix(line, "data:") {
			continue
		}
		data := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
		if data == "" || data == "[DONE]" {
			continue
		}

		chunk.Choices = nil
		if err := json.Unmarshal([]byte(data), &chunk); err != nil {
			continue
		}

		for _, c := range chunk.Choices {
			if c.Delta.Content != "" {
				if err := fn(ChatChunk{Content: c.Delta.Content}); err != nil {
					return err
				}
			}
			for _, tc := range c.Delta.ToolCalls {
				p, ok := calls[tc.Index]
				if !ok {
					p = &pending{}
					calls[tc.Index] = p
				}
				if tc.ID != "" {
					p.ID = tc.ID
				}
				if tc.Function.Name != "" {
					p.Name = tc.Function.Name
				}
				if tc.Function.Arguments != "" {
					p.Args.WriteString(tc.Function.Arguments)
				}
			}
			if c.FinishReason != "" {
				final := ChatChunk{Done: true}
				if len(calls) > 0 {
					indices := make([]int, 0, len(calls))
					for i := range calls {
						indices = append(indices, i)
					}
					sort.Ints(indices)
					for _, idx := range indices {
						p := calls[idx]
						args := map[string]any{}
						if p.Args.Len() > 0 {
							if err := json.Unmarshal([]byte(p.Args.String()), &args); err != nil {
								args = map[string]any{"_raw": p.Args.String()}
							}
						}
						final.ToolCalls = append(final.ToolCalls, ToolCall{
							ID:        p.ID,
							Name:      p.Name,
							Arguments: args,
						})
					}
				}
				return fn(final)
			}
		}
	}
	return scanner.Err()
}

// openAIMessages converts internal Message → OpenAI's chat schema.
func openAIMessages(messages []Message) ([]map[string]any, error) {
	out := make([]map[string]any, 0, len(messages))
	for _, m := range messages {
		switch m.Role {
		case "tool":
			out = append(out, map[string]any{
				"role":         "tool",
				"tool_call_id": m.ToolCallID,
				"content":      m.Content,
			})
		default:
			msg := map[string]any{
				"role":    m.Role,
				"content": m.Content,
			}
			if len(m.ToolCalls) > 0 {
				calls := make([]map[string]any, 0, len(m.ToolCalls))
				for _, tc := range m.ToolCalls {
					argsJSON, err := json.Marshal(tc.Arguments)
					if err != nil {
						return nil, err
					}
					calls = append(calls, map[string]any{
						"id":   tc.ID,
						"type": "function",
						"function": map[string]any{
							"name":      tc.Name,
							"arguments": string(argsJSON),
						},
					})
				}
				msg["tool_calls"] = calls
			}
			out = append(out, msg)
		}
	}
	return out, nil
}

func parseOpenAIError(body []byte, status int) string {
	var e struct {
		Error struct {
			Message string `json:"message"`
			Code    string `json:"code"`
			Type    string `json:"type"`
		} `json:"error"`
	}
	if err := json.Unmarshal(body, &e); err == nil && e.Error.Message != "" {
		msg := strings.SplitN(e.Error.Message, "\n", 2)[0]
		if e.Error.Code != "" {
			return fmt.Sprintf("%s (%s)", msg, e.Error.Code)
		}
		return msg
	}
	return fmt.Sprintf("HTTP %d", status)
}
