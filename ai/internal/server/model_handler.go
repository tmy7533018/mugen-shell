package server

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"

	"github.com/tmy7533018/mugen-ai/internal/state"
)

func (s *Server) handleModels(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), pollAnswerTimeout)
	defer cancel()
	models, err := s.registry.Models(ctx)
	if err != nil {
		http.Error(w, err.Error(), http.StatusServiceUnavailable)
		return
	}
	writeJSON(w, map[string]any{"models": models})
}

type switchModelRequest struct {
	Model string `json:"model"`
}

func (s *Server) handleSwitchModel(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBody)

	var req switchModelRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Model == "" {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	// Only the default for the next new conversation; existing rows keep their bound model.
	s.registry.SetModel(req.Model)
	if err := state.SaveModel(req.Model); err != nil {
		fmt.Fprintf(os.Stderr, "save model: %v\n", err)
	}

	writeJSON(w, map[string]string{"model": req.Model})
}
