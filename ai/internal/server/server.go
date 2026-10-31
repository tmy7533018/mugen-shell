package server

import (
	"context"
	"encoding/json"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/tmy7533018/mugen-ai/internal/config"
	"github.com/tmy7533018/mugen-ai/internal/history"
	"github.com/tmy7533018/mugen-ai/internal/mcp"
	"github.com/tmy7533018/mugen-ai/internal/provider"
	"github.com/tmy7533018/mugen-ai/internal/store"
	"github.com/tmy7533018/mugen-ai/internal/toolfilter"
	"github.com/tmy7533018/mugen-ai/internal/tools"
)

const maxRequestBody = 64 * 1024

// Yura's polls give up after 2 s, so a provider that hangs must not hold the answer past it.
const pollAnswerTimeout = time.Second

type Server struct {
	registry *provider.Registry
	history  *history.History
	store    *store.Store
	tools    *tools.Registry
	mcp      *mcp.Manager
	events   *eventBus
	confirms *confirmRegistry

	ctxCfg config.Context

	filter       *toolfilter.Filter
	filterRemote bool
	recent       *recentCats

	mcpExpose http.Handler

	// Serializes /chat's resolve → append window so concurrent turns can't cross messages.
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

// SetToolFilter enables per-turn tool-list narrowing. applyRemote extends it to non-Ollama
// providers, off by default so their prompt caches keep a byte-stable tool block.
func (s *Server) SetToolFilter(f *toolfilter.Filter, applyRemote bool) {
	s.filter = f
	s.filterRemote = applyRemote
}

// SetMCPExpose mounts the MCP server handler at POST /mcp. nil keeps the
// endpoint returning 404.
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
	mux.HandleFunc("DELETE /conversations/{id}/messages/{msgId}", s.handleTruncateConversation)

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

// NewHTTPServer serves Routes and ends the /events streams as soon as Shutdown starts.
func (s *Server) NewHTTPServer() *http.Server {
	hs := &http.Server{Handler: s.Routes()}
	// Shutdown waits for handlers without cancelling them, so an open /events stream would hold it to the deadline.
	hs.RegisterOnShutdown(s.events.closeAll)
	return hs
}

// Host (DNS-rebinding) and Origin checks keep the loopback API unreachable from a browser page.
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

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), pollAnswerTimeout)
	defer cancel()
	model := s.registry.EnsureModel(ctx)
	status := "ok"
	if model == "" {
		status = "no_model"
	} else if !s.registry.Ping(ctx) {
		status = "provider_unavailable"
	}

	writeJSON(w, map[string]any{
		"status": status,
		"model":  model,
	})
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
