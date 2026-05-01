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

func (g *Google) Chat(ctx context.Context, model string, messages []Message, fn func(ChatChunk) error) error {
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
		role := m.Role
		if role == "assistant" {
			role = "model"
		}
		contents = append(contents, map[string]any{
			"role":  role,
			"parts": []map[string]string{{"text": m.Content}},
		})
	}

	payload := map[string]any{"contents": contents}
	if system != "" {
		payload["systemInstruction"] = map[string]any{
			"parts": []map[string]string{{"text": system}},
		}
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
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
			FinishReason string `json:"finishReason"`
		} `json:"candidates"`
	}

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
			}
			if c.FinishReason != "" {
				return fn(ChatChunk{Done: true})
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
