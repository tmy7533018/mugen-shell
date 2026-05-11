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

type Google struct {
	apiKey string
	http   *http.Client
	models []string
}

func NewGoogle(apiKey, model string) *Google {
	return &Google{
		apiKey: apiKey,
		http:   &http.Client{Timeout: 120 * time.Second},
		models: []string{model},
	}
}

func (g *Google) Name() string { return "google" }

func (g *Google) Ping(_ context.Context) bool {
	return g.apiKey != ""
}

func (g *Google) Models(_ context.Context) ([]string, error) {
	if g.apiKey == "" {
		return nil, nil
	}
	return g.models, nil
}

func (g *Google) Chat(ctx context.Context, model string, messages []Message, opts ChatOptions, fn func(ChatChunk) error) error {
	if g.apiKey == "" {
		return fmt.Errorf("GEMINI_API_KEY is not set")
	}

	var system string
	contents := make([]map[string]any, 0, len(messages))
	for _, m := range messages {
		if m.Role == "system" {
			if system != "" {
				system += "\n\n"
			}
			system += m.Content
			continue
		}
		if m.Role == "tool" {
			// Gemini doesn't have a "tool" role; tool results ride back on a
			// user-role part with functionResponse. response must be an
			// object, so wrap non-JSON output.
			var responseObj any
			if err := json.Unmarshal([]byte(m.Content), &responseObj); err != nil {
				responseObj = map[string]any{"result": m.Content}
			}
			if _, isMap := responseObj.(map[string]any); !isMap {
				responseObj = map[string]any{"result": responseObj}
			}
			contents = append(contents, map[string]any{
				"role": "user",
				"parts": []map[string]any{{
					"functionResponse": map[string]any{
						"name":     m.ToolName,
						"response": responseObj,
					},
				}},
			})
			continue
		}

		role := m.Role
		if role == "assistant" {
			role = "model"
		}

		parts := make([]map[string]any, 0, 1+len(m.ToolCalls))
		if m.Content != "" {
			parts = append(parts, map[string]any{"text": m.Content})
		}
		for _, tc := range m.ToolCalls {
			args := tc.Arguments
			if args == nil {
				args = map[string]any{}
			}
			parts = append(parts, map[string]any{
				"functionCall": map[string]any{
					"name": tc.Name,
					"args": args,
				},
			})
		}
		if len(parts) > 0 {
			contents = append(contents, map[string]any{
				"role":  role,
				"parts": parts,
			})
		}
	}

	payload := map[string]any{"contents": contents}
	if system != "" {
		payload["systemInstruction"] = map[string]any{
			"parts": []map[string]string{{"text": system}},
		}
	}
	if tg := toolsAsGemini(opts.Tools); len(tg) > 0 {
		payload["tools"] = tg
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	url := fmt.Sprintf("https://generativelanguage.googleapis.com/v1beta/models/%s:streamGenerateContent?alt=sse&key=%s", model, g.apiKey)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := g.http.Do(req)
	if err != nil {
		return fmt.Errorf("google unreachable: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return fmt.Errorf("gemini: %s", parseGoogleError(b, resp.StatusCode))
	}

	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)

	var chunk struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text         string `json:"text"`
					FunctionCall struct {
						Name string         `json:"name"`
						Args map[string]any `json:"args"`
					} `json:"functionCall"`
				} `json:"parts"`
			} `json:"content"`
			FinishReason string `json:"finishReason"`
		} `json:"candidates"`
	}

	// Accumulate function calls across stream chunks so a single final
	// ChatChunk surfaces them with Done=true.
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

		chunk.Candidates = nil
		if err := json.Unmarshal([]byte(data), &chunk); err != nil {
			continue
		}

		for _, c := range chunk.Candidates {
			for _, p := range c.Content.Parts {
				if p.Text != "" {
					if err := fn(ChatChunk{Content: p.Text}); err != nil {
						return err
					}
				}
				if p.FunctionCall.Name != "" {
					accumulated = append(accumulated, ToolCall{
						ID:        fmt.Sprintf("call_%d_%d", time.Now().UnixNano(), len(accumulated)),
						Name:      p.FunctionCall.Name,
						Arguments: p.FunctionCall.Args,
					})
				}
			}
			if c.FinishReason != "" {
				final := ChatChunk{Done: true}
				if len(accumulated) > 0 {
					final.ToolCalls = accumulated
				}
				return fn(final)
			}
		}
	}
	return scanner.Err()
}

func parseGoogleError(body []byte, status int) string {
	var e struct {
		Error struct {
			Message string `json:"message"`
			Status  string `json:"status"`
		} `json:"error"`
	}
	if err := json.Unmarshal(body, &e); err == nil && e.Error.Message != "" {
		msg := strings.SplitN(e.Error.Message, "\n", 2)[0]
		if e.Error.Status != "" {
			return fmt.Sprintf("%s (%s)", msg, e.Error.Status)
		}
		return msg
	}
	return fmt.Sprintf("HTTP %d", status)
}
