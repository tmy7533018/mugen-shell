package mcp

import (
	"context"
	"fmt"
	"os"
	"sort"
	"sync"
	"time"
)

// handshakeTimeout bounds initialize + tools/list per server so one that
// never replies can't hang mugen-ai's startup indefinitely.
const handshakeTimeout = 15 * time.Second

// ServerConfig is the subset of a configured MCP server the manager needs.
// Kept here so the mcp package stays free of an internal/config import.
// URL selects the Streamable HTTP transport; Command spawns a stdio server.
type ServerConfig struct {
	Command  string
	Args     []string
	Env      map[string]string
	URL      string
	Disabled bool
}

// ServerStatus is the post-startup outcome for one configured server,
// surfaced over the HTTP API so the Settings GUI can show what loaded.
type ServerStatus struct {
	Name      string `json:"name"`
	Connected bool   `json:"connected"`
	ToolCount int    `json:"tool_count"`
	Error     string `json:"error,omitempty"`
	Disabled  bool   `json:"disabled"`
}

// Manager owns the set of connected MCP clients for the process lifetime
// and remembers the outcome of every configured server, connected or not.
// A crashed server is re-dialed lazily on its next use; mu guards the
// clients map against those concurrent swaps.
type Manager struct {
	mu       sync.Mutex
	clients  map[string]*Client
	configs  map[string]ServerConfig // immutable after Connect; for re-dial
	statuses []ServerStatus
}

// Connect spawns every configured server and runs its handshake. A server
// that fails to spawn or handshake is recorded with its error and skipped,
// so one broken entry can't stop mugen-ai from starting. Servers are
// processed in name order for deterministic startup logs.
func Connect(ctx context.Context, servers map[string]ServerConfig) *Manager {
	m := &Manager{clients: map[string]*Client{}, configs: servers}

	names := make([]string, 0, len(servers))
	for name := range servers {
		names = append(names, name)
	}
	sort.Strings(names)

	for _, name := range names {
		sc := servers[name]
		st := ServerStatus{Name: name, Disabled: sc.Disabled}

		switch {
		case sc.Disabled:
			// Recorded but not spawned.
		case sc.Command == "" && sc.URL == "":
			st.Error = "no command or url configured"
			fmt.Fprintf(os.Stderr, "mcp[%s]: %s, skipping\n", name, st.Error)
		default:
			if client, err := dial(ctx, name, sc); err != nil {
				st.Error = err.Error()
				fmt.Fprintf(os.Stderr, "mcp[%s]: %v\n", name, err)
			} else {
				st.Connected = true
				st.ToolCount = len(client.Tools())
				m.clients[name] = client
				fmt.Fprintf(os.Stderr, "mcp[%s]: connected (%d tools)\n", name, st.ToolCount)
			}
		}
		m.statuses = append(m.statuses, st)
	}
	return m
}

// dial connects one server — spawning it for stdio, straight HTTP for a
// URL — and runs its handshake, returning a ready client or the failure
// reason.
func dial(ctx context.Context, name string, sc ServerConfig) (*Client, error) {
	var tr transport
	var err error
	if sc.URL != "" {
		tr, err = newHTTPTransport(name, sc.URL)
		if err != nil {
			return nil, err
		}
	} else {
		tr, err = newStdioTransport(name, sc.Command, sc.Args, sc.Env)
		if err != nil {
			return nil, fmt.Errorf("spawn failed: %w", err)
		}
	}
	client := newClient(name, tr)

	hctx, cancel := context.WithTimeout(ctx, handshakeTimeout)
	defer cancel()
	if err := client.Initialize(hctx); err != nil {
		client.Close()
		return nil, fmt.Errorf("handshake failed: %w", err)
	}
	if _, err := client.ListTools(hctx); err != nil {
		client.Close()
		return nil, fmt.Errorf("tools/list failed: %w", err)
	}
	return client, nil
}

// Clients returns the servers connected at startup, keyed by configured
// name. Intended for the one-shot tool merge right after Connect, before
// any re-dial can race the map.
func (m *Manager) Clients() map[string]*Client { return m.clients }

// Call dispatches a tool invocation to the named server. If the server has
// crashed since startup it is re-dialed once and the call retried, so a
// crash self-heals on next use instead of failing until mugen-ai restarts.
func (m *Manager) Call(ctx context.Context, server, tool string, args map[string]any) (string, error) {
	m.mu.Lock()
	client := m.clients[server]
	m.mu.Unlock()
	if client == nil {
		return "", fmt.Errorf("mcp server %q is not connected", server)
	}

	out, err := client.CallTool(ctx, tool, args)
	if err == nil || !client.Closed() {
		return out, err
	}

	fresh, derr := m.redial(ctx, server)
	if derr != nil {
		return "", fmt.Errorf("mcp server %q crashed; re-dial failed: %w", server, derr)
	}
	return fresh.CallTool(ctx, tool, args)
}

// redial spawns a fresh client for a crashed server and swaps it into the
// clients map. configs is immutable after Connect, so it is read lock-free;
// the brief lock only guards the map swap and resolves a concurrent re-dial.
func (m *Manager) redial(ctx context.Context, server string) (*Client, error) {
	sc, ok := m.configs[server]
	if !ok {
		return nil, fmt.Errorf("no configuration for server %q", server)
	}
	client, err := dial(ctx, server, sc)
	if err != nil {
		return nil, err
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	if existing := m.clients[server]; existing != nil && !existing.Closed() {
		client.Close() // another caller already recovered this server
		return existing, nil
	}
	if old := m.clients[server]; old != nil {
		old.Close()
	}
	m.clients[server] = client
	fmt.Fprintf(os.Stderr, "mcp[%s]: re-dialed after crash (%d tools)\n", server, len(client.Tools()))
	return client, nil
}

// Statuses returns the state of every configured server, in name order.
// Connected state is read live so a crash — or recovery — since startup is
// reflected; the startup error / disabled / tool-count baseline is kept for
// servers that never had a live client.
func (m *Manager) Statuses() []ServerStatus {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]ServerStatus, len(m.statuses))
	copy(out, m.statuses)
	for i := range out {
		if out[i].Disabled {
			continue
		}
		c := m.clients[out[i].Name]
		if c == nil {
			continue // startup failure; keep the baseline error
		}
		if c.Closed() {
			out[i].Connected = false
			out[i].Error = "connection lost since startup"
		} else {
			out[i].Connected = true
			out[i].ToolCount = len(c.Tools())
			out[i].Error = ""
		}
	}
	return out
}

// Close terminates every connected server. Safe to call on a Manager with
// no servers.
func (m *Manager) Close() {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, c := range m.clients {
		_ = c.Close()
	}
}
