package provider

import "context"

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`

	// Set on assistant messages that requested tool calls.
	ToolCalls []ToolCall `json:"tool_calls,omitempty"`

	// Set on role="tool" messages that report a tool result back. The id
	// must match the ToolCall.ID assigned by the provider in the prior
	// assistant message.
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
	// Thinking enables thinking models' reasoning channel (qwen3 etc.).
	// Currently honored by ollama; other providers ignore it.
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
