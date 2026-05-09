package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
)

type eventBus struct {
	mu          sync.RWMutex
	subscribers map[chan []byte]struct{}
}

func newEventBus() *eventBus {
	return &eventBus{subscribers: make(map[chan []byte]struct{})}
}

func (b *eventBus) subscribe() chan []byte {
	ch := make(chan []byte, 16)
	b.mu.Lock()
	b.subscribers[ch] = struct{}{}
	b.mu.Unlock()
	return ch
}

func (b *eventBus) unsubscribe(ch chan []byte) {
	b.mu.Lock()
	if _, ok := b.subscribers[ch]; ok {
		delete(b.subscribers, ch)
		close(ch)
	}
	b.mu.Unlock()
}

func (b *eventBus) broadcast(eventType string, data any) {
	payload, err := json.Marshal(map[string]any{"type": eventType, "data": data})
	if err != nil {
		return
	}
	b.mu.RLock()
	for ch := range b.subscribers {
		select {
		case ch <- payload:
		default:
		}
	}
	b.mu.RUnlock()
}

func (s *Server) handleEvents(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming not supported", http.StatusInternalServerError)
		return
	}

	ch := s.events.subscribe()
	defer s.events.unsubscribe(ch)

	fmt.Fprintf(w, ": connected\n\n")
	flusher.Flush()

	for {
		select {
		case <-r.Context().Done():
			return
		case payload, ok := <-ch:
			if !ok {
				return
			}
			fmt.Fprintf(w, "data: %s\n\n", payload)
			flusher.Flush()
		}
	}
}
