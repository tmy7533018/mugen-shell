package provider

import "context"

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`

	ToolCalls []ToolCall `json:"tool_calls,omitempty"`

	// Must match the ToolCall.ID the provider assigned in the prior assistant
	// message.
	ToolCallID string `json:"tool_call_id,omitempty"`
	ToolName   string `json:"tool_name,omitempty"`
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
}

type Provider interface {
	Name() string
	Chat(ctx context.Context, model string, messages []Message, opts ChatOptions, fn func(ChatChunk) error) error
	Models(ctx context.Context) ([]string, error)
	Ping(ctx context.Context) bool
}
