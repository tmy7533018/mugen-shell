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
	"time"
)

type Ollama struct {
	host      string
	numCtx    int
	keepAlive string
	http      *http.Client
}

func NewOllama(host string, numCtx int, keepAlive string) *Ollama {
	return &Ollama{host: host, numCtx: numCtx, keepAlive: keepAlive, http: &http.Client{}}
}

func (o *Ollama) Name() string { return "ollama" }

func (o *Ollama) Ping(ctx context.Context) bool {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, o.host+"/api/tags", nil)
	if err != nil {
		return false
	}
	resp, err := o.http.Do(req)
	if err != nil {
		return false
	}
	resp.Body.Close()
	return resp.StatusCode == http.StatusOK
}

type ollamaToolCall struct {
	Function struct {
		Name      string         `json:"name"`
		Arguments map[string]any `json:"arguments"`
	} `json:"function"`
}

func (o *Ollama) Chat(ctx context.Context, model string, messages []Message, opts ChatOptions, fn func(ChatChunk) error) error {
	// Map Message → ollama wire shape. role="tool" carries the result of a
	// previous tool call; ollama wants {role:"tool", content:"..."} with no
	// tool_call_id.
	msgs := make([]map[string]any, 0, len(messages))
	for _, m := range messages {
		msg := map[string]any{
			"role":    m.Role,
			"content": m.Content,
		}
		if len(m.ToolCalls) > 0 {
			calls := make([]map[string]any, 0, len(m.ToolCalls))
			for _, tc := range m.ToolCalls {
				calls = append(calls, map[string]any{
					"function": map[string]any{
						"name":      tc.Name,
						"arguments": tc.Arguments,
					},
				})
			}
			msg["tool_calls"] = calls
		}
		msgs = append(msgs, msg)
	}

	payload := map[string]any{
		"model":    model,
		"messages": msgs,
		"stream":   true,
		// Thinking models (qwen3 etc.) stream reasoning on a separate
		// `thinking` field. Caller decides per-conversation; models without
		// thinking ignore this field.
		"think": opts.Thinking,
	}
	if tw := toolsAsOpenAI(opts.Tools); len(tw) > 0 {
		payload["tools"] = tw
	}
	// Ollama's own num_ctx default (4k) is smaller than our tools + system
	// prompt + history footprint and it truncates the overflow silently, so
	// always request an explicit window. Ollama clamps to the model's max.
	if o.numCtx > 0 {
		payload["options"] = map[string]any{"num_ctx": o.numCtx}
	}
	// Keep the model resident between chats; the default 5m unload makes
	// the first reply after an idle stretch pay a multi-second cold load.
	if o.keepAlive != "" {
		payload["keep_alive"] = o.keepAlive
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, o.host+"/api/chat", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := o.http.Do(req)
	if err != nil {
		return fmt.Errorf("ollama unreachable: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		bodyStr := string(bodyBytes)
		// Older / smaller models (gemma3, etc.) reject tools with a 400 and
		// "does not support tools". Retry without tools so the conversation
		// keeps working — the user can still ask, just without the shell
		// controls until they switch to a tool-capable model.
		if resp.StatusCode == http.StatusBadRequest &&
			strings.Contains(bodyStr, "does not support tools") &&
			len(opts.Tools) > 0 {
			retry := opts
			retry.Tools = nil
			return o.Chat(ctx, model, messages, retry, fn)
		}
		return fmt.Errorf("ollama returned status %d: %s", resp.StatusCode, strings.TrimSpace(bodyStr))
	}

	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 64*1024), 10*1024*1024)

	var toolCalls []ToolCall
	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}
		var raw struct {
			Message struct {
				Content   string           `json:"content"`
				ToolCalls []ollamaToolCall `json:"tool_calls,omitempty"`
			} `json:"message"`
			Done bool `json:"done"`
		}
		if err := json.Unmarshal(line, &raw); err != nil {
			continue
		}

		// Ollama streams a tool call on its own chunk ahead of the final
		// done chunk, which carries none — so accumulate calls and hand
		// the whole set over on the done chunk, where handleChat harvests
		// ToolCalls. Emitting them on the streaming chunk would drop them.
		for _, tc := range raw.Message.ToolCalls {
			toolCalls = append(toolCalls, ToolCall{
				ID:        fmt.Sprintf("call_%d_%d", time.Now().UnixNano(), len(toolCalls)),
				Name:      tc.Function.Name,
				Arguments: tc.Function.Arguments,
			})
		}

		chunk := ChatChunk{Content: raw.Message.Content, Done: raw.Done}
		if raw.Done {
			chunk.ToolCalls = toolCalls
		}
		if err := fn(chunk); err != nil {
			return err
		}
		if raw.Done {
			break
		}
	}
	return scanner.Err()
}

func (o *Ollama) Models(ctx context.Context) ([]string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, o.host+"/api/tags", nil)
	if err != nil {
		return nil, err
	}

	resp, err := o.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("ollama unreachable: %w", err)
	}
	defer resp.Body.Close()

	var result struct {
		Models []struct {
			Name string `json:"name"`
		} `json:"models"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	names := make([]string, len(result.Models))
	for i, m := range result.Models {
		names[i] = m.Name
	}
	return names, nil
}
