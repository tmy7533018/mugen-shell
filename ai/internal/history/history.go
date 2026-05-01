package history

import (
	"sync"

	"github.com/tmy7533018/mugen-ai/internal/provider"
)

const defaultMaxMessages = 100

type History struct {
	mu          sync.Mutex
	messages    []provider.Message
	system      string
	max         int
	ContextFunc func() string
}

func New(systemPrompt string) *History {
	return &History{system: systemPrompt, max: defaultMaxMessages}
}

func (h *History) Add(role, content string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.messages = append(h.messages, provider.Message{Role: role, Content: content})
	h.truncateLocked()
}

func (h *History) RemoveLast() {
	h.mu.Lock()
	defer h.mu.Unlock()
	if len(h.messages) > 0 {
		h.messages = h.messages[:len(h.messages)-1]
	}
}

func (h *History) Messages() []provider.Message {
	h.mu.Lock()
	defer h.mu.Unlock()

	result := make([]provider.Message, 0, len(h.messages)+1)
	if h.system != "" {
		prompt := h.system
		if h.ContextFunc != nil {
			prompt += h.ContextFunc()
		}
		result = append(result, provider.Message{Role: "system", Content: prompt})
	}
	return append(result, h.messages...)
}

func (h *History) SetSystem(prompt string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.system = prompt
}

func (h *History) Clear() {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.messages = nil
}

func (h *History) truncateLocked() {
	if h.max <= 0 || len(h.messages) <= h.max {
		return
	}
	h.messages = h.messages[len(h.messages)-h.max:]
}
