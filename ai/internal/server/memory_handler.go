package server

import (
	"net/http"

	"github.com/tmy7533018/mugen-ai/internal/store"
)

func (s *Server) handleListMemories(w http.ResponseWriter, _ *http.Request) {
	mems, err := s.store.ListMemories()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if mems == nil {
		mems = []store.Memory{}
	}
	writeJSON(w, map[string]any{"memories": mems})
}

func (s *Server) handleDeleteMemory(w http.ResponseWriter, r *http.Request) {
	id, ok := parsePathID(r, "id")
	if !ok {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	existed, err := s.store.DeleteMemory(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if !existed {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	writeJSON(w, map[string]any{"deleted": id})
}

func (s *Server) handleClearMemories(w http.ResponseWriter, _ *http.Request) {
	n, err := s.store.DeleteAllMemories()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]any{"deleted": n})
}
