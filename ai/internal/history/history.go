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
	maxTokens    int
}

// New builds the history layer. maxTokens caps the estimated token footprint
// of the messages sent per turn (0 = no token cap); the message-count cap
// applies regardless.
func New(s *store.Store, systemPrompt string, maxTokens int) (*History, error) {
	h := &History{store: s, system: systemPrompt, max: defaultMaxMessages, maxTokens: maxTokens}
	if err := h.loadCurrent(); err != nil {
		return nil, fmt.Errorf("load current conversation: %w", err)
	}
	return h, nil
}

// estimateTokens is a deliberately conservative cross-language guess
// (~1 token per 3 bytes): English runs ~4 bytes/token, Japanese ~3, so
// overshooting keeps us safely inside the model's real window.
func estimateTokens(s string) int {
	return len(s)/3 + 1
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
	h.truncateLocked()
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

// AddAssistantTo persists an assistant reply to a specific conversation,
// regardless of which one is currently loaded, so a long streaming turn lands
// in the conversation it started on even if another request switched the
// current pointer meanwhile. The in-memory cache is only touched when that
// conversation is still the current one.
func (h *History) AddAssistantTo(convID int64, content string) error {
	if convID == 0 {
		return nil
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if err := h.store.AppendMessage(convID, "assistant", content); err != nil {
		return err
	}
	if convID == h.convID {
		h.messages = append(h.messages, provider.Message{Role: "assistant", Content: content})
		h.truncateLocked()
	}
	return nil
}

// RemoveLastFrom drops the most recent message of a specific conversation,
// used to roll back a user message when the turn fails before any side effect.
func (h *History) RemoveLastFrom(convID int64) {
	if convID == 0 {
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if err := h.store.RemoveLastMessage(convID); err != nil {
		return
	}
	if convID == h.convID && len(h.messages) > 0 {
		h.messages = h.messages[:len(h.messages)-1]
	}
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

// DeleteAll removes every conversation and resets the current pointer, so the
// next message starts a fresh conversation.
func (h *History) DeleteAll() error {
	h.mu.Lock()
	defer h.mu.Unlock()
	if err := h.store.DeleteAllConversations(); err != nil {
		return err
	}
	if err := h.switchLocked(0); err != nil {
		return err
	}
	return h.store.ClearCurrentConversationID()
}

func (h *History) truncateLocked() {
	if h.max > 0 && len(h.messages) > h.max {
		h.messages = h.messages[len(h.messages)-h.max:]
	}
	if h.maxTokens <= 0 {
		return
	}
	total := 0
	for i := range h.messages {
		total += estimateTokens(h.messages[i].Content)
	}
	// Keep at least the trailing exchange so a single oversized message
	// can't empty the conversation.
	drop := 0
	for total > h.maxTokens && drop < len(h.messages)-2 {
		total -= estimateTokens(h.messages[drop].Content)
		drop++
	}
	if drop > 0 {
		h.messages = h.messages[drop:]
	}
}
