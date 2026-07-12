package server

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/tmy7533018/mugen-ai/internal/config"
	"github.com/tmy7533018/mugen-ai/internal/history"
	"github.com/tmy7533018/mugen-ai/internal/mcp"
	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/state"
	"github.com/tmy7533018/mugen-ai/internal/store"
	"github.com/tmy7533018/mugen-ai/internal/toolfilter"
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

	// ctxCfg gates the live desktop-state snapshot injected into chat turns
	// (config [context]).
	ctxCfg config.Context

	// filter, when non-nil, narrows the tool list per turn (config
	// [tools.context_filter]); filterRemote extends that beyond Ollama.
	// recent feeds it the categories each conversation touched lately.
	filter       *toolfilter.Filter
	filterRemote bool
	recent       *recentCats

	// mcpExpose serves POST /mcp when the user enabled [mcp_expose].
	mcpExpose http.Handler

	// chatSetupMu serializes the resolve-conversation → append-user-message
	// window of /chat so two concurrent requests can't interleave on the
	// shared history pointer and cross-file each other's messages.
	chatSetupMu sync.Mutex
}

func New(registry *provider.Registry, hist *history.History, st *store.Store, t *tools.Registry, m *mcp.Manager, ctxCfg config.Context) *Server {
	return &Server{
		registry: registry,
		history:  hist,
		store:    st,
		tools:    t,
		mcp:      m,
		events:   newEventBus(),
		confirms: newConfirmRegistry(),
		ctxCfg:   ctxCfg,
		recent:   newRecentCats(),
	}
}

// SetToolFilter enables per-turn tool-list narrowing. applyRemote extends it
// to non-Ollama providers — off by default so their prompt caches keep a
// byte-stable tool block.
func (s *Server) SetToolFilter(f *toolfilter.Filter, applyRemote bool) {
	s.filter = f
	s.filterRemote = applyRemote
}

// SetMCPExpose mounts the MCP server handler at POST /mcp. nil (the default)
// keeps the endpoint returning 404.
func (s *Server) SetMCPExpose(h http.Handler) { s.mcpExpose = h }

func (s *Server) handleMCPExpose(w http.ResponseWriter, r *http.Request) {
	if s.mcpExpose == nil {
		http.Error(w, "MCP expose is disabled ([mcp_expose] enabled = false)", http.StatusNotFound)
		return
	}
	s.mcpExpose.ServeHTTP(w, r)
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
	mux.HandleFunc("DELETE /conversations", s.handleClearConversations)
	mux.HandleFunc("GET /conversations/stats", s.handleConversationStats)
	mux.HandleFunc("GET /conversations/export", s.handleExportConversations)
	mux.HandleFunc("GET /conversations/current", s.handleCurrentConversation)
	mux.HandleFunc("GET /conversations/{id}", s.handleGetConversation)
	mux.HandleFunc("DELETE /conversations/{id}", s.handleDeleteConversation)
	mux.HandleFunc("POST /conversations/{id}/select", s.handleSelectConversation)

	mux.HandleFunc("GET /events", s.handleEvents)

	mux.HandleFunc("GET /tools", s.handleListTools)
	mux.HandleFunc("POST /tools/call", s.handleToolCall)

	mux.HandleFunc("GET /mcp/servers", s.handleListMCPServers)
	mux.HandleFunc("GET /mcp/discover", s.handleMCPDiscover)
	mux.HandleFunc("POST /mcp", s.handleMCPExpose)

	mux.HandleFunc("GET /memories", s.handleListMemories)
	mux.HandleFunc("DELETE /memories", s.handleClearMemories)
	mux.HandleFunc("DELETE /memories/{id}", s.handleDeleteMemory)

	mux.HandleFunc("GET /config", s.handleGetConfig)
	mux.HandleFunc("PUT /config", s.handlePutConfig)
	mux.HandleFunc("POST /config/restart", s.handleRestart)

	return guardMiddleware(mux)
}

// guardMiddleware keeps the loopback-only API unreachable from a browser. It
// refuses non-loopback Host headers (DNS-rebinding) and any request that
// carries a non-local Origin — a webpage the user is visiting can otherwise
// POST to 127.0.0.1 and drive tools. No wildcard CORS is emitted, so a
// cross-origin page can't read responses either.
func guardMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !isLoopbackHost(r.Host) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		if origin := r.Header.Get("Origin"); origin != "" && !isLoopbackOrigin(origin) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func isLoopbackHost(host string) bool {
	h := host
	if i := strings.LastIndex(h, ":"); i >= 0 && !strings.Contains(h[i:], "]") {
		h = h[:i]
	}
	h = strings.Trim(h, "[]")
	return h == "127.0.0.1" || h == "localhost" || h == "::1"
}

func isLoopbackOrigin(origin string) bool {
	u, err := url.Parse(origin)
	if err != nil {
		return false
	}
	return isLoopbackHost(u.Host)
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
	// Voice turns are heard, not read; a transient style hint keeps the
	// reply speakable. Set by yurad, never persisted.
	Voice bool `json:"voice,omitempty"`
}

const voiceStyleHint = "This is a voice conversation. Answer in short spoken-style sentences: no markdown, no bullet or numbered lists, no headings, no code blocks, no emoji. When the user asks you to do something a tool can do, emit the tool call NOW, in this same turn — a reply that only promises to act (\"やっておくね\", \"変えておくね\") with no tool call does nothing and is a failure."

// beginChatTurn resolves the conversation, model, and thinking flag and
// appends the user message under chatSetupMu, then snapshots the message list.
// Everything downstream works off the returned request-local copies, so a
// concurrent /chat switching the shared current pointer can't retarget this
// turn. A non-nil error carries the HTTP status to report.
func (s *Server) beginChatTurn(req chatRequest) (convID int64, model string, thinking bool, msgs []provider.Message, status int, err error) {
	s.chatSetupMu.Lock()
	defer s.chatSetupMu.Unlock()

	if err = s.history.Switch(req.ConversationID); err != nil {
		return 0, "", false, nil, http.StatusBadRequest, err
	}

	// Bound model wins for existing conversations; new ones fall back
	// req.Model → registry default.
	model = s.history.ConvModel()
	if model == "" {
		model = req.Model
	}
	if model == "" {
		model = s.registry.Model()
	}
	if model == "" {
		return 0, "", false, nil, http.StatusServiceUnavailable, fmt.Errorf("no model configured")
	}

	// Resolve thinking: explicit request wins; otherwise inherit from the
	// bound conversation (or false for a brand-new one).
	thinking = s.history.ConvThinking()
	if req.Thinking != nil {
		thinking = *req.Thinking
		if s.history.ConvID() != 0 {
			if err = s.history.SetConvThinking(thinking); err != nil {
				return 0, "", false, nil, http.StatusInternalServerError, err
			}
		}
	}

	if err = s.history.Add("user", req.Message, model, thinking); err != nil {
		return 0, "", false, nil, http.StatusInternalServerError, err
	}

	return s.history.ConvID(), model, thinking, s.history.Messages(), 0, nil
}

func (s *Server) handleChat(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBody)

	var req chatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Message == "" {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	convID, model, thinking, msgs, status, err := s.beginChatTurn(req)
	if err != nil {
		http.Error(w, err.Error(), status)
		return
	}
	// [system, user] and nothing else = this turn opened the conversation;
	// its close is when the LLM title gets generated.
	isFirstExchange := len(msgs) == 2

	// Long-term memories ride inside the system message: they change
	// rarely, so provider prompt caches stay warm across turns.
	if blk := s.tools.MemoryBlock(); blk != "" && len(msgs) > 0 && msgs[0].Role == "system" {
		msgs[0].Content += "\n\n" + blk
	}

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
		"conversation_id": convID,
		"model":           model,
	})
	fmt.Fprintf(w, "data: %s\n\n", idData)
	flusher.Flush()

	providerName := s.registry.ProviderNameFor(r.Context(), model)

	// Desktop-state snapshot rides in as a transient system message just
	// before the newest user message: it is never persisted, so stale
	// snapshots don't pile up in history, and the earlier message prefix
	// stays byte-stable for providers' prompt caches. Gathered after the
	// sync event above so a slow shell IPC can't delay the UI's stream
	// setup. Cloud providers only see it when desktop_state_remote allows.
	if s.ctxCfg.DesktopState && len(msgs) > 0 &&
		(s.ctxCfg.DesktopStateRemote || providerName == "ollama") {
		if blk := s.tools.DesktopContext(r.Context()); blk != "" {
			userMsg := msgs[len(msgs)-1]
			msgs = append(msgs[:len(msgs)-1:len(msgs)-1],
				provider.Message{Role: "system", Content: blk}, userMsg)
		}
	}

	// Same transient-rider trick as the desktop snapshot: the hint sits
	// before the newest user message and is never persisted, so typed
	// follow-ups in the panel get normal markdown again.
	if req.Voice && len(msgs) > 0 {
		userMsg := msgs[len(msgs)-1]
		msgs = append(msgs[:len(msgs)-1:len(msgs)-1],
			provider.Message{Role: "system", Content: voiceStyleHint}, userMsg)
	}

	// Tool calls / results stay in-memory only — history persists just the
	// concatenated assistant text.
	const maxIterations = 5
	allTools := s.tools.List()
	selTools := allTools
	if s.filter != nil && (providerName == "ollama" || s.filterRemote) {
		var reason string
		selTools, reason = s.filter.Select(r.Context(), req.Message, s.recent.get(convID), allTools)
		if len(selTools) != len(allTools) {
			fmt.Fprintf(os.Stderr, "toolfilter: %d/%d tools (%s)\n", len(selTools), len(allTools), reason)
		}
	}
	// The filtered list rides the first request; once the model has actually
	// engaged a tool and we loop, a chain step may need any category the
	// opening message didn't hint at, so later iterations see the full list.
	firstTools := providerTools(selTools)
	fullTools := firstTools
	if len(selTools) != len(allTools) {
		fullTools = providerTools(allTools)
	}
	opts := provider.ChatOptions{Tools: firstTools, Thinking: thinking}

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
				_ = s.history.AddAssistantTo(convID, fullResponse)
				s.events.broadcast("conversations", nil)
				s.events.broadcast("messages", map[string]any{"conversation_id": convID})
			}
		} else {
			s.history.RemoveLastFrom(convID)
		}
		sendEvent(map[string]any{"error": errMsg, "done": true})
	}

	for iteration := 0; iteration < maxIterations; iteration++ {
		if iteration == 1 {
			opts.Tools = fullTools
		}
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
				_ = s.history.AddAssistantTo(convID, fullResponse)
				s.events.broadcast("conversations", nil)
				s.events.broadcast("messages", map[string]any{"conversation_id": convID})
				if isFirstExchange {
					go s.generateTitle(convID, model, req.Message, fullResponse)
				}
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
			// Even a denied or failed call marks its category as in play for
			// this conversation, so follow-ups keep the same tools visible.
			s.recent.note(convID, tools.CategoryOf(tc.Name))

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

// generateTitle asks the conversation's model for a short title once the
// first exchange completes. Best-effort and async: any failure keeps the
// fallback title (the first message's prefix).
func (s *Server) generateTitle(convID int64, model, userMsg, reply string) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	prompt := "Write a title for this conversation: 2-5 words, in the same language as the exchange. Reply with ONLY the title — no quotes, no trailing punctuation.\n\nUser: " +
		firstN(userMsg, 400) + "\nAssistant: " + firstN(reply, 400)
	var title string
	err := s.registry.ChatWith(ctx, model, []provider.Message{{Role: "user", Content: prompt}},
		provider.ChatOptions{}, func(c provider.ChatChunk) error {
			title += c.Content
			return nil
		})
	if err != nil {
		return
	}
	// Some local models leak a reasoning block despite think=false.
	if i := strings.Index(title, "</think>"); i >= 0 {
		title = title[i+len("</think>"):]
	}
	if i := strings.IndexByte(title, '\n'); i >= 0 {
		title = title[:i]
	}
	title = strings.Trim(strings.TrimSpace(title), `"'「」『』.。`)
	if title == "" {
		return
	}
	if err := s.store.UpdateConversationTitle(convID, store.DeriveTitle(title)); err == nil {
		s.events.broadcast("conversations", nil)
	}
}

func firstN(s string, n int) string {
	rs := []rune(s)
	if len(rs) <= n {
		return s
	}
	return string(rs[:n]) + "…"
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

// handleConversationStats reports where the history database lives, how many
// conversations it holds, and its on-disk size — for the Settings GUI.
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

// handleExportConversations returns every conversation with its messages as
// one JSON document — the Settings GUI saves the response to a file.
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

// handleClearConversations deletes every conversation. The chat UIs refresh
// off the broadcast; the next message starts a fresh conversation.
func (s *Server) handleClearConversations(w http.ResponseWriter, _ *http.Request) {
	if err := s.history.DeleteAll(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	s.events.broadcast("conversations", nil)
	writeJSON(w, map[string]any{"cleared": true})
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

// handleMCPDiscover lists MCP servers already installed on this machine so
// the Settings GUI can offer them as one-tap config entries.
func (s *Server) handleMCPDiscover(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]any{"candidates": mcp.Discover(r.Context())})
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

// recentCats remembers which tool categories each conversation touched
// recently. The context filter unions them into every turn's selection so a
// keyword-less follow-up ("もう少し上げて") keeps the tools it refers to.
type recentCats struct {
	mu        sync.Mutex
	m         map[int64]map[string]time.Time
	lastSweep time.Time
}

const recentCatTTL = 15 * time.Minute

func newRecentCats() *recentCats {
	return &recentCats{m: map[int64]map[string]time.Time{}}
}

func (rc *recentCats) note(conv int64, cat string) {
	rc.mu.Lock()
	defer rc.mu.Unlock()
	rc.sweepLocked()
	if rc.m[conv] == nil {
		rc.m[conv] = map[string]time.Time{}
	}
	rc.m[conv][cat] = time.Now()
}

// sweepLocked drops every expired entry across all conversations at most once
// per TTL window. get() only prunes the conversation it is queried with, so
// without this an abandoned conversation (never read again) would leak its
// category map forever on a long-running daemon.
func (rc *recentCats) sweepLocked() {
	now := time.Now()
	if now.Sub(rc.lastSweep) < recentCatTTL {
		return
	}
	rc.lastSweep = now
	cutoff := now.Add(-recentCatTTL)
	for conv, cats := range rc.m {
		for cat, at := range cats {
			if at.Before(cutoff) {
				delete(cats, cat)
			}
		}
		if len(cats) == 0 {
			delete(rc.m, conv)
		}
	}
}

func (rc *recentCats) get(conv int64) []string {
	rc.mu.Lock()
	defer rc.mu.Unlock()
	cutoff := time.Now().Add(-recentCatTTL)
	var out []string
	for cat, at := range rc.m[conv] {
		if at.Before(cutoff) {
			delete(rc.m[conv], cat)
			continue
		}
		out = append(out, cat)
	}
	if len(rc.m[conv]) == 0 {
		delete(rc.m, conv)
	}
	sort.Strings(out)
	return out
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
	// This debug path has no user in the loop, so it must not be a way around
	// the confirmation gate — those tools are only runnable via /chat.
	if s.tools.NeedsConfirm(req.Name) {
		http.Error(w, "tool requires confirmation; invoke via /chat", http.StatusForbidden)
		return
	}
	result, err := s.tools.Call(r.Context(), req.Name, req.Args)
	resp := map[string]any{"result": result}
	if err != nil {
		resp["error"] = err.Error()
	}
	writeJSON(w, resp)
}
