// Package mcpserver publishes mugen-ai's own tools as a Model Context
// Protocol server. It implements only the subset a tools-only server needs —
// initialize / ping / tools/list / tools/call — over stateless Streamable
// HTTP: one JSON-RPC message per POST, no sessions, no server-initiated
// streams.
package mcpserver

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/tmy7533018/mugen-ai/internal/tools"
)

// Only a fallback: the shapes served here are identical across recent
// revisions, so the client's requested revision is echoed back instead.
const protocolVersion = "2025-06-18"

const maxMessageBytes = 1 << 20 // tool args are small, this is headroom

// ToolSource is the slice of tools.Registry the server needs, an interface
// so tests can fake tool execution instead of exec'ing real commands.
type ToolSource interface {
	ExposedTools(readonly bool, categories []string) []tools.Tool
	Call(ctx context.Context, name string, args map[string]any) (string, error)
}

// Handler answers MCP JSON-RPC messages against the exposed tool subset.
type Handler struct {
	src        ToolSource
	readonly   bool
	categories []string
	version    string
}

func New(src ToolSource, readonly bool, categories []string, version string) *Handler {
	if version == "" {
		version = "dev"
	}
	return &Handler{src: src, readonly: readonly, categories: categories, version: version}
}

// Exposed returns the currently publishable tools.
func (h *Handler) Exposed() []tools.Tool {
	return h.src.ExposedTools(h.readonly, h.categories)
}

type rpcMessage struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
}

type rpcResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id"`
	Result  any             `json:"result,omitempty"`
	Error   *rpcError       `json:"error,omitempty"`
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

const (
	codeParse          = -32700
	codeInvalidRequest = -32600
	codeMethodNotFound = -32601
	codeInvalidParams  = -32602
)

// HandleMessage processes one JSON-RPC message and returns the encoded
// response, or nil when none is due (notifications, responses).
func (h *Handler) HandleMessage(ctx context.Context, raw []byte) []byte {
	trimmed := []byte(strings.TrimSpace(string(raw)))
	if len(trimmed) > 0 && trimmed[0] == '[' {
		// JSON-RPC batching was removed from MCP; refuse rather than guess.
		return marshalResponse(rpcResponse{JSONRPC: "2.0", ID: nullID(), Error: &rpcError{codeInvalidRequest, "batch messages are not supported"}})
	}

	var msg rpcMessage
	if err := json.Unmarshal(trimmed, &msg); err != nil {
		return marshalResponse(rpcResponse{JSONRPC: "2.0", ID: nullID(), Error: &rpcError{codeParse, "parse error: " + err.Error()}})
	}
	// A message without a method is a response to a server request, and this
	// server never sends any.
	if msg.Method == "" {
		return nil
	}
	// Only notifications/* are legal without an id; anything else — notably a
	// tools/call missing its id — must not run its side effects fire-and-
	// forget. This gates execution, not just the reply.
	if len(msg.ID) == 0 || string(msg.ID) == "null" {
		if strings.HasPrefix(msg.Method, "notifications/") {
			h.dispatch(ctx, msg)
		}
		return nil
	}

	result, rerr := h.dispatch(ctx, msg)
	resp := rpcResponse{JSONRPC: "2.0", ID: msg.ID, Result: result, Error: rerr}
	return marshalResponse(resp)
}

func (h *Handler) dispatch(ctx context.Context, msg rpcMessage) (any, *rpcError) {
	switch msg.Method {
	case "initialize":
		return h.initialize(msg.Params), nil
	case "ping":
		return map[string]any{}, nil
	case "tools/list":
		return h.listTools(), nil
	case "tools/call":
		return h.callTool(ctx, msg.Params)
	default:
		if strings.HasPrefix(msg.Method, "notifications/") {
			return nil, nil
		}
		return nil, &rpcError{codeMethodNotFound, fmt.Sprintf("method %q not supported", msg.Method)}
	}
}

func (h *Handler) initialize(params json.RawMessage) map[string]any {
	// The subset served here is shape-identical across revisions, so
	// refusing the client's requested one buys nothing.
	version := protocolVersion
	var p struct {
		ProtocolVersion string `json:"protocolVersion"`
	}
	if err := json.Unmarshal(params, &p); err == nil && p.ProtocolVersion != "" {
		version = p.ProtocolVersion
	}
	return map[string]any{
		"protocolVersion": version,
		"capabilities":    map[string]any{"tools": map[string]any{}},
		"serverInfo": map[string]any{
			"name":    "mugen-shell",
			"title":   "mugen-shell desktop",
			"version": h.version,
		},
	}
}

func (h *Handler) listTools() map[string]any {
	exposed := h.Exposed()
	list := make([]map[string]any, 0, len(exposed))
	for _, t := range exposed {
		list = append(list, map[string]any{
			"name":        t.Name,
			"description": t.Description,
			"inputSchema": t.Parameters,
			"annotations": map[string]any{"readOnlyHint": t.IsReadOnly()},
		})
	}
	return map[string]any{"tools": list}
}

func (h *Handler) callTool(ctx context.Context, params json.RawMessage) (any, *rpcError) {
	var p struct {
		Name      string         `json:"name"`
		Arguments map[string]any `json:"arguments"`
	}
	if err := json.Unmarshal(params, &p); err != nil || p.Name == "" {
		return nil, &rpcError{codeInvalidParams, "tools/call needs a tool name"}
	}
	// The gate that matters: only the exposed subset is callable, no matter
	// what else the registry knows about.
	found := false
	for _, t := range h.Exposed() {
		if t.Name == p.Name {
			found = true
			break
		}
	}
	if !found {
		return nil, &rpcError{codeInvalidParams, fmt.Sprintf("unknown tool %q", p.Name)}
	}
	if p.Arguments == nil {
		p.Arguments = map[string]any{}
	}

	out, err := h.src.Call(ctx, p.Name, p.Arguments)
	text := out
	isErr := false
	if err != nil {
		text = err.Error()
		isErr = true
	} else if strings.HasPrefix(strings.TrimSpace(out), "error:") {
		// Built-in tools report failures as "error:"-prefixed results.
		isErr = true
	}
	return map[string]any{
		"content": []map[string]any{{"type": "text", "text": text}},
		"isError": isErr,
	}, nil
}

// Stateless JSON response mode: requests answer with application/json,
// notifications with 202. GET (server-initiated stream) is not offered.
func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, maxMessageBytes))
	if err != nil {
		http.Error(w, "read error", http.StatusBadRequest)
		return
	}
	resp := h.HandleMessage(r.Context(), body)
	if resp == nil {
		w.WriteHeader(http.StatusAccepted)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write(resp)
}

func marshalResponse(resp rpcResponse) []byte {
	data, err := json.Marshal(resp)
	if err != nil {
		// Result values are maps of plain data; this cannot fail in practice.
		return []byte(`{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"internal marshal error"}}`)
	}
	return data
}

func nullID() json.RawMessage { return json.RawMessage("null") }
