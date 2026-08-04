package provider

import (
	"context"
	"fmt"
)

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`

	Images []Image `json:"images,omitempty"`

	ToolCalls []ToolCall `json:"tool_calls,omitempty"`

	// Anthropic rejects a tool result whose assistant turn dropped the
	// thinking block that produced the call, so the signed block has to be
	// handed back verbatim.
	Thinking          string `json:"thinking,omitempty"`
	ThinkingSignature string `json:"thinking_signature,omitempty"`

	// Must match the ToolCall.ID the provider assigned in the prior assistant
	// message.
	ToolCallID string `json:"tool_call_id,omitempty"`
	ToolName   string `json:"tool_name,omitempty"`
}

// Image is one attachment, already base64-encoded.
type Image struct {
	MediaType string `json:"media_type"`
	Data      string `json:"data"`
}

type Tool struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Parameters  map[string]any `json:"parameters"`
}

type ToolCall struct {
	ID        string         `json:"id"`
	Name      string         `json:"name"`
	Arguments map[string]any `json:"arguments"`
}

type ChatOptions struct {
	Tools []Tool
	// Thinking enables the model's reasoning channel; models without one
	// ignore it.
	Thinking bool
}

type ChatChunk struct {
	Content   string
	ToolCalls []ToolCall
	Done      bool
	Error     string

	// Set on the final chunk only, for replay alongside ToolCalls.
	Thinking          string
	ThinkingSignature string
}

// A stream that stops before its terminal event has produced a partial reply
// and, possibly, half of a tool call. Reporting that as success would persist
// the fragment as a finished answer and silently drop the call.
func truncatedStream(name string) error {
	return fmt.Errorf("%s: the stream ended before the reply was complete", name)
}

type Provider interface {
	Name() string
	Chat(ctx context.Context, model string, messages []Message, opts ChatOptions, fn func(ChatChunk) error) error
	Models(ctx context.Context) ([]string, error)
	Ping(ctx context.Context) bool
}
