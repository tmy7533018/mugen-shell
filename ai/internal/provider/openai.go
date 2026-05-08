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

func (o *OpenAI) Chat(ctx context.Context, model string, messages []Message, fn func(ChatChunk) error) error {
	body, err := json.Marshal(map[string]any{
		"model":    model,
		"messages": messages,
		"stream":   true,
	})
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, o.baseURL+"/chat/completions", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
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
		return fmt.Errorf("openai: %s", parseOpenAIError(b, resp.StatusCode))
	}

	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)

	var chunk struct {
		Choices []struct {
			Delta struct {
				Content string `json:"content"`
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
			if c.FinishReason != "" {
				return fn(ChatChunk{Done: true})
			}
		}
	}
	return scanner.Err()
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
