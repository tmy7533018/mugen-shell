package server

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/tmy7533018/mugen-ai/internal/history"
	"github.com/tmy7533018/mugen-ai/internal/mcp"
	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/state"
	"github.com/tmy7533018/mugen-ai/internal/store"
	"github.com/tmy7533018/mugen-ai/internal/tools"
)

const maxRequestBody = 64 * 1024 // 64KB

type Server struct {
	registry *provider.Registry
	history  *history.History
	store    *store.Store
	tools    *tools.Registry
	mcp      *mcp.Manager
	events   *eventBus
	confirms *confirmRegistry
}

func New(registry *provider.Registry, hist *history.History, st *store.Store, t *tools.Registry, m *mcp.Manager) *Server {
	return &Server{
		registry: registry,
		history:  hist,
		store:    st,
		tools:    t,
		mcp:      m,
		events:   newEventBus(),
		confirms: newConfirmRegistry(),
	}
}

func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /chat", s.handleChat)
	mux.HandleFunc("POST /chat/confirm", s.handleChatConfirm)
	mux.HandleFunc("GET /health", s.handleHealth)
	mux.HandleFunc("GET /models", s.handleModels)
	mux.HandleFunc("PUT /model", s.handleSwitchModel)

	mux.HandleFunc("GET /conversations", s.handleListConversations)
	mux.HandleFunc("POST /conversations", s.handleCreateConversation)
	mux.HandleFunc("GET /conversations/current", s.handleCurrentConversation)
	mux.HandleFunc("GET /conversations/{id}", s.handleGetConversation)
	mux.HandleFunc("DELETE /conversations/{id}", s.handleDeleteConversation)
	mux.HandleFunc("POST /conversations/{id}/select", s.handleSelectConversation)

	mux.HandleFunc("GET /events", s.handleEvents)

	mux.HandleFunc("GET /tools", s.handleListTools)
	mux.HandleFunc("POST /tools/call", s.handleToolCall)

	mux.HandleFunc("GET /mcp/servers", s.handleListMCPServers)

	mux.HandleFunc("GET /config", s.handleGetConfig)
	mux.HandleFunc("PUT /config", s.handlePutConfig)
	mux.HandleFunc("POST /config/restart", s.handleRestart)

	return corsMiddleware(mux)
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

type chatRequest struct {
	Message        string `json:"message"`
	ConversationID int64  `json:"conversation_id"`
	// Used only when ConversationID == 0; existing conversations always run
	// on the model bound to their row.
	Model string `json:"model,omitempty"`
	// Pointer so absent vs. explicit-false are distinguishable. For new
	// conversations it sets the bound value; for existing ones it updates
	// the bound value (per-conversation toggle from the UI).
	Thinking *bool `json:"thinking,omitempty"`
}

func (s *Server) handleChat(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBody)

	var req chatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Message == "" {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	// 0 starts a fresh conversation, >0 appends to that one. Explicit per
	// request so two open windows don't race on a shared current pointer.
	if err := s.history.Switch(req.ConversationID); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Bound model wins for existing conversations; new ones fall back
	// req.Model → registry default.
	model := s.history.ConvModel()
	if model == "" {
		model = req.Model
	}
	if model == "" {
		model = s.registry.Model()
	}
	if model == "" {
		http.Error(w, "no model configured", http.StatusServiceUnavailable)
		return
	}

	// Resolve thinking: explicit request wins; otherwise inherit from the
	// bound conversation (or false for a brand-new one).
	thinking := s.history.ConvThinking()
	if req.Thinking != nil {
		thinking = *req.Thinking
		if s.history.ConvID() != 0 {
			if err := s.history.SetConvThinking(thinking); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
		}
	}

	if err := s.history.Add("user", req.Message, model, thinking); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	convID := s.history.ConvID()
	s.events.broadcast("conversations", nil)
	s.events.broadcast("messages", map[string]any{"conversation_id": convID})

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming not supported", http.StatusInternalServerError)
		return
	}

	// Up-front sync: rapid follow-up messages otherwise raced on the
	// not-yet-loaded conversation id.
	idData, _ := json.Marshal(map[string]any{
		"conversation_id": s.history.ConvID(),
		"model":           model,
	})
	fmt.Fprintf(w, "data: %s\n\n", idData)
	flusher.Flush()

	// Tool calls / results stay in-memory only — history persists just the
	// concatenated assistant text.
	const maxIterations = 5
	tools := providerTools(s.tools.List())
	opts := provider.ChatOptions{Tools: tools, Thinking: thinking}
	msgs := s.history.Messages()

	sendEvent := func(payload map[string]any) {
		data, _ := json.Marshal(payload)
		fmt.Fprintf(w, "data: %s\n\n", data)
		flusher.Flush()
	}

	var fullResponse string
	// Once we've streamed any content or fired any tool we can't safely
	// drop the user message on error — the conversation has visible side
	// effects, so persist what we have and surface the error instead.
	var sideEffected bool

	persistOnError := func(errMsg string) {
		if sideEffected {
			if fullResponse != "" {
				_ = s.history.Add("assistant", fullResponse, model, thinking)
				s.events.broadcast("conversations", nil)
				s.events.broadcast("messages", map[string]any{"conversation_id": convID})
			}
		} else {
			s.history.RemoveLast()
		}
		sendEvent(map[string]any{"error": errMsg, "done": true})
	}

	for iteration := 0; iteration < maxIterations; iteration++ {
		var iterContent string
		var iterToolCalls []provider.ToolCall

		err := s.registry.ChatWith(r.Context(), model, msgs, opts, func(chunk provider.ChatChunk) error {
			if chunk.Content != "" {
				iterContent += chunk.Content
				fullResponse += chunk.Content
				sideEffected = true
				sendEvent(map[string]any{"content": chunk.Content})
			}
			if chunk.Done {
				iterToolCalls = chunk.ToolCalls
			}
			return nil
		})

		if err != nil {
			persistOnError(err.Error())
			return
		}

		if len(iterToolCalls) == 0 {
			if fullResponse != "" {
				_ = s.history.Add("assistant", fullResponse, model, thinking)
				s.events.broadcast("conversations", nil)
				s.events.broadcast("messages", map[string]any{"conversation_id": convID})
			}
			sendEvent(map[string]any{"done": true})
			return
		}

		// Transient assistant turn carrying the tool call request.
		msgs = append(msgs, provider.Message{
			Role:      "assistant",
			Content:   iterContent,
			ToolCalls: iterToolCalls,
		})

		sendEvent(map[string]any{"tool_calls": iterToolCalls})

		for _, tc := range iterToolCalls {
			var result string
			var callErr error
			// A confirm-gated tool must be approved out-of-band before it
			// runs; a denial (or timeout) is fed back as a plain result so
			// the model can react without the action ever happening.
			if s.tools.NeedsConfirm(tc.Name) && !s.awaitConfirm(r.Context(), tc, sendEvent) {
				result = "error: the user declined this action. Do not retry it; acknowledge their choice and move on."
				s.tools.Audit(tc.Name, tc.Arguments, result, nil)
			} else {
				result, callErr = s.tools.Call(r.Context(), tc.Name, tc.Arguments)
			}
			sideEffected = true
			resultPayload := result
			if callErr != nil {
				resultPayload = fmt.Sprintf("error: %v (output: %s)", callErr, result)
			}

			sendEvent(map[string]any{
				"tool_result": map[string]any{
					"id":     tc.ID,
					"name":   tc.Name,
					"result": resultPayload,
					"error":  errString(callErr),
				},
			})

			msgs = append(msgs, provider.Message{
				Role:       "tool",
				ToolCallID: tc.ID,
				ToolName:   tc.Name,
				Content:    resultPayload,
			})
		}
	}

	persistOnError("max tool iterations exceeded")
}

// awaitConfirm streams a tool_confirm event for tc and blocks until the user
// answers it via POST /chat/confirm, the wait times out, or the client
// disconnects. It returns whether the action was approved; a timeout or a
// disconnect counts as a denial so an irreversible tool never runs
// unattended.
func (s *Server) awaitConfirm(ctx context.Context, tc provider.ToolCall, send func(map[string]any)) bool {
	id, ch := s.confirms.register()
	defer s.confirms.discard(id)

	send(map[string]any{
		"tool_confirm": map[string]any{
			"confirm_id": id,
			"name":       tc.Name,
			"arguments":  tc.Arguments,
		},
	})

	select {
	case approved := <-ch:
		return approved
	case <-time.After(confirmTimeout):
		return false
	case <-ctx.Done():
		return false
	}
}

type chatConfirmRequest struct {
	ConfirmID string `json:"confirm_id"`
	Approved  bool   `json:"approved"`
}

// handleChatConfirm resolves a pending tool-approval prompt. The blocked
// chat turn picks the answer up and either runs the tool or feeds the model
// a decline. A 404 means the prompt already lapsed (answered or timed out).
func (s *Server) handleChatConfirm(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBody)
	var req chatConfirmRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.ConfirmID == "" {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}
	if !s.confirms.resolve(req.ConfirmID, req.Approved) {
		http.Error(w, "no such pending confirmation", http.StatusNotFound)
		return
	}
	writeJSON(w, map[string]any{"resolved": true})
}

func errString(err error) string {
	if err == nil {
		return ""
	}
	return err.Error()
}

func (s *Server) handleModels(w http.ResponseWriter, r *http.Request) {
	models, err := s.registry.Models(r.Context())
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

	// Only updates the default for the *next* new conversation; existing
	// rows keep their bound model.
	s.registry.SetModel(req.Model)
	_ = state.SaveModel(req.Model)

	writeJSON(w, map[string]string{"model": req.Model})
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	model := s.registry.Model()
	status := "ok"
	if model == "" {
		status = "no_model"
	} else if !s.registry.Ping(r.Context()) {
		status = "provider_unavailable"
	}

	writeJSON(w, map[string]any{
		"status": status,
		"model":  model,
	})
}

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
	id, err := s.history.NewConversation(s.registry.Model(), false)
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
	writeJSON(w, map[string]any{
		"id":         conv.ID,
		"title":      conv.Title,
		"model":      conv.Model,
		"thinking":   conv.Thinking,
		"created_at": conv.CreatedAt,
		"updated_at": conv.UpdatedAt,
		"messages":   msgs,
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
	writeJSON(w, map[string]any{
		"id":         conv.ID,
		"title":      conv.Title,
		"model":      conv.Model,
		"thinking":   conv.Thinking,
		"created_at": conv.CreatedAt,
		"updated_at": conv.UpdatedAt,
		"messages":   msgs,
	})
}

func (s *Server) handleDeleteConversation(w http.ResponseWriter, r *http.Request) {
	id, ok := parsePathID(r, "id")
	if !ok {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	if err := s.history.DeleteConversation(id); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	s.events.broadcast("conversations", nil)
	writeJSON(w, map[string]any{"current_id": s.history.ConvID()})
}

func (s *Server) handleSelectConversation(w http.ResponseWriter, r *http.Request) {
	id, ok := parsePathID(r, "id")
	if !ok {
		http.Error(w, "invalid id", http.StatusBadRequest)
		return
	}
	if err := s.history.Switch(id); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]any{"id": id})
}

func parsePathID(r *http.Request, name string) (int64, bool) {
	raw := r.PathValue(name)
	id, err := strconv.ParseInt(raw, 10, 64)
	if err != nil || id <= 0 {
		return 0, false
	}
	return id, true
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}

func (s *Server) handleListTools(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, map[string]any{"tools": s.tools.List()})
}

// handleListMCPServers reports the startup outcome of each configured MCP
// server (connected / failed / disabled) so the Settings GUI can show it.
func (s *Server) handleListMCPServers(w http.ResponseWriter, _ *http.Request) {
	var statuses []mcp.ServerStatus
	if s.mcp != nil {
		statuses = s.mcp.Statuses()
	}
	if statuses == nil {
		statuses = []mcp.ServerStatus{}
	}
	writeJSON(w, map[string]any{"servers": statuses})
}

func providerTools(in []tools.Tool) []provider.Tool {
	out := make([]provider.Tool, len(in))
	for i, t := range in {
		out[i] = provider.Tool{
			Name:        t.Name,
			Description: t.Description,
			Parameters:  t.Parameters,
		}
	}
	return out
}

type toolCallRequest struct {
	Name string         `json:"name"`
	Args map[string]any `json:"args"`
}

// handleToolCall is a thin debug/test path: invoke a tool by name with no
// LLM involvement.
func (s *Server) handleToolCall(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBody)
	var req toolCallRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Name == "" {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}
	result, err := s.tools.Call(r.Context(), req.Name, req.Args)
	resp := map[string]any{"result": result}
	if err != nil {
		resp["error"] = err.Error()
	}
	writeJSON(w, resp)
}
