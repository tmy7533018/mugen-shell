package server

import (
	"errors"
	"net/http"
	"time"

	"github.com/tmy7533018/mugen-ai/internal/store"
)

func (s *Server) handleListConversations(w http.ResponseWriter, _ *http.Request) {
	convs, err := s.store.ListConversations()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if convs == nil {
		convs = []store.Conversation{}
	}
	writeJSON(w, map[string]any{"conversations": convs})
}

func (s *Server) handleCreateConversation(w http.ResponseWriter, _ *http.Request) {
	s.chatSetupMu.Lock()
	id, err := s.history.NewConversation(s.registry.Model(), false)
	s.chatSetupMu.Unlock()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	conv, _ := s.store.GetConversation(id)
	s.events.broadcast("conversations", nil)
	writeJSON(w, conv)
}

func (s *Server) handleCurrentConversation(w http.ResponseWriter, _ *http.Request) {
	id := s.history.ConvID()
	if id == 0 {
		writeJSON(w, map[string]any{"id": 0, "messages": []any{}})
		return
	}
	conv, err := s.store.GetConversation(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if conv == nil {
		writeJSON(w, map[string]any{"id": 0, "messages": []any{}})
		return
	}
	msgs, err := s.store.ListMessages(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if msgs == nil {
		msgs = []store.Message{}
	}
	dropped, err := s.history.ContextDropped(conv.ID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]any{
		"id":              conv.ID,
		"title":           conv.Title,
		"model":           conv.Model,
		"thinking":        conv.Thinking,
		"created_at":      conv.CreatedAt,
		"updated_at":      conv.UpdatedAt,
		"context_dropped": dropped,
		"messages":        msgs,
	})
}

func (s *Server) handleGetConversation(w http.ResponseWriter, r *http.Request) {
	id, ok := parsePathID(r, "id")
	if !ok {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	conv, err := s.store.GetConversation(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if conv == nil {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	msgs, err := s.store.ListMessages(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if msgs == nil {
		msgs = []store.Message{}
	}
	dropped, err := s.history.ContextDropped(conv.ID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]any{
		"id":              conv.ID,
		"title":           conv.Title,
		"model":           conv.Model,
		"thinking":        conv.Thinking,
		"created_at":      conv.CreatedAt,
		"updated_at":      conv.UpdatedAt,
		"context_dropped": dropped,
		"messages":        msgs,
	})
}

func (s *Server) handleDeleteConversation(w http.ResponseWriter, r *http.Request) {
	id, ok := parsePathID(r, "id")
	if !ok {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	s.chatSetupMu.Lock()
	before := s.history.ConvID()
	deleted, err := s.history.DeleteConversation(id)
	after := s.history.ConvID()
	s.chatSetupMu.Unlock()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if deleted || after != before {
		s.events.broadcast("conversations", nil)
	}
	writeJSON(w, map[string]any{"current_id": after})
}

// Retry and edit are the same operation here: truncate, then POST /chat as usual.
func (s *Server) handleTruncateConversation(w http.ResponseWriter, r *http.Request) {
	id, ok := parsePathID(r, "id")
	if !ok {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	msgID, ok := parsePathID(r, "msgId")
	if !ok {
		http.Error(w, "invalid message id", http.StatusBadRequest)
		return
	}
	conv, err := s.store.GetConversation(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if conv == nil {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	removed, err := s.history.TruncateFrom(id, msgID)
	if errors.Is(err, store.ErrMessageNotInConversation) {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	msgs, err := s.store.ListMessages(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if msgs == nil {
		msgs = []store.Message{}
	}
	s.events.broadcast("conversations", nil)
	writeJSON(w, map[string]any{"removed": removed, "messages": msgs})
}

func (s *Server) handleSelectConversation(w http.ResponseWriter, r *http.Request) {
	id, ok := parsePathID(r, "id")
	if !ok {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	s.chatSetupMu.Lock()
	err := s.history.Switch(id)
	s.chatSetupMu.Unlock()
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]any{"id": id})
}

func (s *Server) handleConversationStats(w http.ResponseWriter, _ *http.Request) {
	count, err := s.store.ConversationCount()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]any{
		"path":       s.store.Path(),
		"count":      count,
		"size_bytes": s.store.SizeBytes(),
	})
}

func (s *Server) handleExportConversations(w http.ResponseWriter, _ *http.Request) {
	convs, err := s.store.ListConversations()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	type exportConv struct {
		store.Conversation
		Messages []store.Message `json:"messages"`
	}
	out := make([]exportConv, 0, len(convs))
	for _, c := range convs {
		msgs, err := s.store.ListMessages(c.ID)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		if msgs == nil {
			msgs = []store.Message{}
		}
		out = append(out, exportConv{Conversation: c, Messages: msgs})
	}
	writeJSON(w, map[string]any{
		"exported_at":   time.Now().Unix(),
		"conversations": out,
	})
}

func (s *Server) handleClearConversations(w http.ResponseWriter, _ *http.Request) {
	s.chatSetupMu.Lock()
	err := s.history.DeleteAll()
	s.chatSetupMu.Unlock()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	s.events.broadcast("conversations", nil)
	writeJSON(w, map[string]any{"cleared": true})
}
