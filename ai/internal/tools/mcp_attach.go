package tools

import (
	"fmt"
	"hash/fnv"
	"os"

	"github.com/tmy7533018/mugen-ai/internal/mcp"
)

// AttachMCP merges every connected MCP server's tools in as "<server>__<tool>", so the
// server name becomes a gateable category. An untrusted destructive tool gets "[CONFIRM]".
func (r *Registry) AttachMCP(m *mcp.Manager, trusted map[string]bool) {
	if m == nil {
		return
	}
	r.mcp = m
	for server, client := range m.Clients() {
		for _, def := range client.Tools() {
			name := mcpToolName(server, def.Name)
			if name == "" {
				fmt.Fprintf(os.Stderr, "mcp[%s]: server name leaves no room for tool %q within %d bytes, skipping\n", server, def.Name, maxMCPToolNameBytes)
				continue
			}
			if name != server+"__"+def.Name {
				fmt.Fprintf(os.Stderr, "mcp[%s]: tool %q renamed to %q for provider compatibility\n", server, def.Name, name)
			}
			if r.Find(name) != nil {
				fmt.Fprintf(os.Stderr, "mcp[%s]: tool %q collides with an existing tool, skipping\n", server, name)
				continue
			}
			gated := def.Destructive && !trusted[server]
			desc := def.Description
			if gated {
				desc = "[CONFIRM] " + desc
			}
			r.tools = append(r.tools, Tool{
				Name:         name,
				Description:  desc,
				Parameters:   def.InputSchema,
				readonly:     def.ReadOnly,
				kind:         "mcp",
				mcpServer:    server,
				mcpTool:      def.Name,
				needsConfirm: gated,
			})
		}
	}
}

// OpenAI's function-name limit, the tightest of the providers.
const maxMCPToolNameBytes = 64

// Only the tool half is rewritten: the server half doubles as the disabled_categories / always_include key.
func mcpToolName(server, tool string) string {
	tl := sanitizeMCPToolName(tool)
	name := server + "__" + tl
	if tl == tool && len(name) <= maxMCPToolNameBytes {
		return name
	}
	suffix := fmt.Sprintf("_%08x", fnv32a(tool))
	budget := maxMCPToolNameBytes - len(server) - len("__") - len(suffix)
	if budget <= 0 {
		return ""
	}
	if len(tl) > budget {
		tl = tl[:budget]
	}
	return server + "__" + tl + suffix
}

func sanitizeMCPToolName(s string) string {
	b := []byte(s)
	for i, c := range b {
		if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_' || c == '-') {
			b[i] = '_'
		}
	}
	return string(b)
}

func fnv32a(s string) uint32 {
	h := fnv.New32a()
	h.Write([]byte(s))
	return h.Sum32()
}
