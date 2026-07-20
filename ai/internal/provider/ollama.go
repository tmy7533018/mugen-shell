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
	// Unlike OpenAI, ollama wants tool results as plain {role:"tool", content}
	// with no tool_call_id.
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
		// Safe to always send: models without a thinking channel ignore it.
		"think": opts.Thinking,
	}
	if tw := toolsAsOpenAI(opts.Tools); len(tw) > 0 {
		payload["tools"] = tw
	}
	// Ollama's 4k num_ctx default is under our tools + prompt + history
	// footprint and it truncates the overflow silently. Clamped to model max.
	if o.numCtx > 0 {
		payload["options"] = map[string]any{"num_ctx": o.numCtx}
	}
	// The default 5m unload makes the first reply after an idle stretch pay a
	// multi-second cold load.
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
		// Older / smaller models reject tools with a 400; retry without them so
		// the conversation still works, minus the shell controls.
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

		// Ollama streams tool calls on their own chunks ahead of the done
		// chunk, which carries none. handleChat only harvests ToolCalls from
		// the done chunk, so accumulate and hand the set over there.
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

// Embed returns one embedding vector per input text. Not part of the Provider
// interface.
func (o *Ollama) Embed(ctx context.Context, model string, input []string) ([][]float32, error) {
	body, err := json.Marshal(map[string]any{"model": model, "input": input})
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, o.host+"/api/embed", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := o.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("ollama unreachable: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return nil, fmt.Errorf("ollama embed returned status %d: %s", resp.StatusCode, strings.TrimSpace(string(bodyBytes)))
	}
	var out struct {
		Embeddings [][]float32 `json:"embeddings"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	if len(out.Embeddings) != len(input) {
		return nil, fmt.Errorf("ollama embed returned %d vectors for %d inputs", len(out.Embeddings), len(input))
	}
	return out.Embeddings, nil
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
