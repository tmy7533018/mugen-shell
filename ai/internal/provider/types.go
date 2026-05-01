package provider

import "context"

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ChatChunk struct {
	Content string
	Done    bool
	Error   string
}

type Provider interface {
	Name() string
	Chat(ctx context.Context, model string, messages []Message, fn func(ChatChunk) error) error
	Models(ctx context.Context) ([]string, error)
	Ping(ctx context.Context) bool
}
