package mcp

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"sync"
)

// The wire shapes this client relies on are unchanged across recent
// revisions, so a server replying with an older version is still usable.
const protocolVersion = "2025-06-18"

// A frame with a Method is a request or notification (the latter has no ID);
// one without is a response.
type rpcMessage struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      *int64          `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *rpcError       `json:"error,omitempty"`
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func (e *rpcError) Error() string { return fmt.Sprintf("mcp error %d: %s", e.Code, e.Message) }

// ToolDef is one tool advertised by an MCP server via tools/list.
type ToolDef struct {
	Name        string
	Description string
	InputSchema map[string]any
	ReadOnly    bool
	// Destructive is a resolved verdict, not a raw annotation: many servers
	// send neither hint, so it can fall back to the tool name.
	Destructive bool
}

// Client is a JSON-RPC client bound to a single MCP server. A background
// reader goroutine matches responses to in-flight requests by id.
type Client struct {
	name string
	tr   transport

	mu      sync.Mutex
	nextID  int64
	pending map[int64]chan rpcMessage
	closed  bool

	tools []ToolDef
}

func newClient(name string, tr transport) *Client {
	c := &Client{name: name, tr: tr, pending: map[int64]chan rpcMessage{}}
	go c.readLoop()
	return c
}

// Server-initiated requests and notifications are ignored: this client
// advertises no capabilities, so a compliant server won't send one that
// needs a reply.
func (c *Client) readLoop() {
	for {
		data, err := c.tr.recv()
		if err != nil {
			c.fail(err)
			return
		}
		data = bytes.TrimSpace(data)
		if len(data) == 0 {
			continue
		}
		var msg rpcMessage
		if err := json.Unmarshal(data, &msg); err != nil {
			fmt.Fprintf(os.Stderr, "mcp[%s]: dropping unparseable message: %v\n", c.name, err)
			continue
		}
		if msg.ID == nil || msg.Method != "" {
			continue
		}
		c.mu.Lock()
		ch := c.pending[*msg.ID]
		delete(c.pending, *msg.ID)
		c.mu.Unlock()
		if ch != nil {
			ch <- msg
		}
	}
}

func (c *Client) fail(err error) {
	c.mu.Lock()
	c.closed = true
	pending := c.pending
	c.pending = map[int64]chan rpcMessage{}
	c.mu.Unlock()
	for _, ch := range pending {
		ch <- rpcMessage{Error: &rpcError{Code: -1, Message: fmt.Sprintf("connection lost: %v", err)}}
	}
}

func (c *Client) clearPending(id int64) {
	c.mu.Lock()
	delete(c.pending, id)
	c.mu.Unlock()
}

func (c *Client) call(ctx context.Context, method string, params any) (json.RawMessage, error) {
	raw, err := marshalParams(params)
	if err != nil {
		return nil, err
	}

	c.mu.Lock()
	if c.closed {
		c.mu.Unlock()
		return nil, fmt.Errorf("mcp %q: connection closed", c.name)
	}
	c.nextID++
	id := c.nextID
	ch := make(chan rpcMessage, 1)
	c.pending[id] = ch
	c.mu.Unlock()

	data, err := json.Marshal(rpcMessage{JSONRPC: "2.0", ID: &id, Method: method, Params: raw})
	if err != nil {
		c.clearPending(id)
		return nil, err
	}
	if err := c.tr.send(data); err != nil {
		c.clearPending(id)
		return nil, err
	}

	select {
	case <-ctx.Done():
		c.clearPending(id)
		return nil, ctx.Err()
	case resp := <-ch:
		if resp.Error != nil {
			return nil, resp.Error
		}
		return resp.Result, nil
	}
}

func (c *Client) notify(method string, params any) error {
	raw, err := marshalParams(params)
	if err != nil {
		return err
	}
	data, err := json.Marshal(rpcMessage{JSONRPC: "2.0", Method: method, Params: raw})
	if err != nil {
		return err
	}
	return c.tr.send(data)
}

func marshalParams(params any) (json.RawMessage, error) {
	if params == nil {
		return nil, nil
	}
	return json.Marshal(params)
}

// Initialize runs the MCP handshake: the initialize request followed by the
// initialized notification the spec requires before any other request.
func (c *Client) Initialize(ctx context.Context) error {
	_, err := c.call(ctx, "initialize", map[string]any{
		"protocolVersion": protocolVersion,
		"capabilities":    map[string]any{},
		"clientInfo":      map[string]any{"name": "mugen-ai", "version": "1"},
	})
	if err != nil {
		return err
	}
	return c.notify("notifications/initialized", nil)
}

// ListTools fetches the server's full tool catalog, following pagination
// cursors, and caches it for Tools().
func (c *Client) ListTools(ctx context.Context) ([]ToolDef, error) {
	var all []ToolDef
	cursor := ""
	for {
		params := map[string]any{}
		if cursor != "" {
			params["cursor"] = cursor
		}
		raw, err := c.call(ctx, "tools/list", params)
		if err != nil {
			return nil, err
		}
		var res struct {
			Tools []struct {
				Name        string         `json:"name"`
				Description string         `json:"description"`
				InputSchema map[string]any `json:"inputSchema"`
				Annotations struct {
					ReadOnlyHint    bool  `json:"readOnlyHint"`
					DestructiveHint *bool `json:"destructiveHint"`
				} `json:"annotations"`
			} `json:"tools"`
			NextCursor string `json:"nextCursor"`
		}
		if err := json.Unmarshal(raw, &res); err != nil {
			return nil, fmt.Errorf("mcp %q: bad tools/list response: %w", c.name, err)
		}
		for _, t := range res.Tools {
			schema := t.InputSchema
			if schema == nil {
				schema = map[string]any{"type": "object", "properties": map[string]any{}}
			}
			destructive := resolveDestructive(t.Name, t.Annotations.ReadOnlyHint, t.Annotations.DestructiveHint)
			all = append(all, ToolDef{
				Name:        t.Name,
				Description: t.Description,
				InputSchema: schema,
				ReadOnly:    t.Annotations.ReadOnlyHint,
				Destructive: destructive,
			})
		}
		if res.NextCursor == "" {
			break
		}
		cursor = res.NextCursor
	}
	c.tools = all
	return all, nil
}

// Tools returns the catalog cached by the last ListTools call.
func (c *Client) Tools() []ToolDef { return c.tools }

// Only consulted when a server omits the readOnlyHint / destructiveHint
// annotations, which most do.
var readOnlyVerbs = map[string]bool{
	"get": true, "list": true, "read": true, "search": true, "find": true,
	"fetch": true, "query": true, "describe": true, "show": true, "view": true,
	"count": true, "check": true, "lookup": true, "browse": true, "scan": true,
}

// With no hints, only a clearly read-shaped name counts as safe, so an
// ambiguous name still errs toward asking the user for confirmation.
func resolveDestructive(name string, readOnly bool, destructiveHint *bool) bool {
	if readOnly {
		return false
	}
	if destructiveHint != nil {
		return *destructiveHint
	}
	return !readOnlyVerbs[strings.ToLower(firstWord(name))]
}

func firstWord(name string) string {
	for i := 0; i < len(name); i++ {
		c := name[i]
		if c == '_' || c == '-' || c == '.' || c == ' ' {
			return name[:i]
		}
		if i > 0 && c >= 'A' && c <= 'Z' && name[i-1] >= 'a' && name[i-1] <= 'z' {
			return name[:i]
		}
	}
	return name
}

// CallTool invokes a tool and flattens its content blocks into a string.
// A tool-level failure (isError) comes back as an "error:"-prefixed result
// rather than a Go error, matching how the built-in tools report failures.
func (c *Client) CallTool(ctx context.Context, name string, args map[string]any) (string, error) {
	if args == nil {
		args = map[string]any{}
	}
	raw, err := c.call(ctx, "tools/call", map[string]any{"name": name, "arguments": args})
	if err != nil {
		return "", err
	}
	var res struct {
		Content []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
		IsError bool `json:"isError"`
	}
	if err := json.Unmarshal(raw, &res); err != nil {
		return "", fmt.Errorf("mcp %q: bad tools/call response: %w", c.name, err)
	}
	var sb strings.Builder
	for i, block := range res.Content {
		if i > 0 {
			sb.WriteByte('\n')
		}
		if block.Type == "text" {
			sb.WriteString(block.Text)
		} else {
			fmt.Fprintf(&sb, "[non-text content: %s]", block.Type)
		}
	}
	if res.IsError {
		return "error: " + sb.String(), nil
	}
	return sb.String(), nil
}

func (c *Client) Close() error { return c.tr.close() }

// Closed reports whether the connection has dropped. A closed client cannot
// be revived; the Manager re-dials a fresh one in its place.
func (c *Client) Closed() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.closed
}
