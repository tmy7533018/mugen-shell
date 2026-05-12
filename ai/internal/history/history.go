package history

import (
	"fmt"
	"sync"

	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/store"
)

const defaultMaxMessages = 100

type History struct {
	mu           sync.Mutex
	store        *store.Store
	convID       int64
	convModel    string
	convThinking bool
	messages     []provider.Message
	system       string
	max          int
}

func New(s *store.Store, systemPrompt string) (*History, error) {
	h := &History{store: s, system: systemPrompt, max: defaultMaxMessages}
	if err := h.loadCurrent(); err != nil {
		return nil, fmt.Errorf("load current conversation: %w", err)
	}
	return h, nil
}

func (h *History) loadCurrent() error {
	id, err := h.store.GetCurrentConversationID()
	if err != nil {
		return err
	}
	if id == 0 {
		return nil
	}
	conv, err := h.store.GetConversation(id)
	if err != nil {
		return err
	}
	if conv == nil {
		// Stale pointer to a deleted conversation.
		return h.store.ClearCurrentConversationID()
	}
	return h.switchLocked(id)
}

func (h *History) switchLocked(id int64) error {
	if id == 0 {
		h.convID = 0
		h.convModel = ""
		h.convThinking = false
		h.messages = nil
		return nil
	}
	conv, err := h.store.GetConversation(id)
	if err != nil {
		return err
	}
	msgs, err := h.store.ListMessages(id)
	if err != nil {
		return err
	}
	if h.max > 0 && len(msgs) > h.max {
		msgs = msgs[len(msgs)-h.max:]
	}
	h.convID = id
	if conv != nil {
		h.convModel = conv.Model
		h.convThinking = conv.Thinking
	} else {
		h.convModel = ""
		h.convThinking = false
	}
	h.messages = h.messages[:0]
	for _, m := range msgs {
		h.messages = append(h.messages, provider.Message{Role: m.Role, Content: m.Content})
	}
	return nil
}

func (h *History) ConvID() int64 {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.convID
}

// ConvModel returns the model bound to the current conversation, or "".
func (h *History) ConvModel() string {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.convModel
}

// ConvThinking returns the thinking flag bound to the current conversation.
func (h *History) ConvThinking() bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.convThinking
}

// SetConvThinking updates the thinking flag for the current conversation.
func (h *History) SetConvThinking(thinking bool) error {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.convID == 0 {
		h.convThinking = thinking
		return nil
	}
	if err := h.store.UpdateConversationThinking(h.convID, thinking); err != nil {
		return err
	}
	h.convThinking = thinking
	return nil
}

func (h *History) Switch(id int64) error {
	h.mu.Lock()
	defer h.mu.Unlock()
	if id == h.convID {
		return nil
	}
	if id != 0 {
		conv, err := h.store.GetConversation(id)
		if err != nil {
			return err
		}
		if conv == nil {
			return fmt.Errorf("conversation %d not found", id)
		}
	}
	if err := h.switchLocked(id); err != nil {
		return err
	}
	if id == 0 {
		return h.store.ClearCurrentConversationID()
	}
	return h.store.SetCurrentConversationID(id)
}

func (h *History) Add(role, content, model string, thinking bool) error {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.convID == 0 {
		title := ""
		if role == "user" {
			title = store.DeriveTitle(content)
		}
		id, err := h.store.CreateConversation(title, model, thinking)
		if err != nil {
			return err
		}
		if err := h.store.SetCurrentConversationID(id); err != nil {
			return err
		}
		h.convID = id
		h.convModel = model
		h.convThinking = thinking
	} else if role == "user" {
		conv, err := h.store.GetConversation(h.convID)
		if err == nil && conv != nil && conv.Title == "" {
			_ = h.store.UpdateConversationTitle(h.convID, store.DeriveTitle(content))
		}
	}
	if err := h.store.AppendMessage(h.convID, role, content); err != nil {
		return err
	}
	h.messages = append(h.messages, provider.Message{Role: role, Content: content})
	h.truncateLocked()
	return nil
}

// RemoveLast drops the most recent message (called when a chat fails post-Add).
func (h *History) RemoveLast() {
	h.mu.Lock()
	defer h.mu.Unlock()
	if len(h.messages) == 0 || h.convID == 0 {
		return
	}
	h.messages = h.messages[:len(h.messages)-1]
	_ = h.store.RemoveLastMessage(h.convID)
}

func (h *History) Messages() []provider.Message {
	h.mu.Lock()
	defer h.mu.Unlock()
	result := make([]provider.Message, 0, len(h.messages)+1)
	if h.system != "" {
		result = append(result, provider.Message{Role: "system", Content: h.system})
	}
	return append(result, h.messages...)
}

func (h *History) SetSystem(prompt string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.system = prompt
}

// NewConversation creates a fresh conversation, makes it current, and clears the cache.
func (h *History) NewConversation(model string, thinking bool) (int64, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	id, err := h.store.CreateConversation("", model, thinking)
	if err != nil {
		return 0, err
	}
	if err := h.store.SetCurrentConversationID(id); err != nil {
		return 0, err
	}
	h.convID = id
	h.convModel = model
	h.convThinking = thinking
	h.messages = h.messages[:0]
	return id, nil
}

// DeleteConversation removes a conversation; if it was current, falls back
// to the most recent remaining one (or no current at all).
func (h *History) DeleteConversation(id int64) error {
	h.mu.Lock()
	defer h.mu.Unlock()
	if err := h.store.DeleteConversation(id); err != nil {
		return err
	}
	if h.convID != id {
		return nil
	}
	convs, err := h.store.ListConversations()
	if err != nil {
		return err
	}
	var newID int64
	if len(convs) > 0 {
		newID = convs[0].ID
	}
	if err := h.switchLocked(newID); err != nil {
		return err
	}
	if newID == 0 {
		return h.store.ClearCurrentConversationID()
	}
	return h.store.SetCurrentConversationID(newID)
}

func (h *History) truncateLocked() {
	if h.max <= 0 || len(h.messages) <= h.max {
		return
	}
	h.messages = h.messages[len(h.messages)-h.max:]
}
