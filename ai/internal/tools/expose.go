package tools

import "strings"

// IsReadOnly reports whether the tool only reads state. The MCP expose layer
// advertises it as the readOnlyHint annotation.
func (t Tool) IsReadOnly() bool { return t.readonly }

// ExposedTools returns the subset publishable through the MCP expose endpoint:
// read-only tools when readonly is set, plus every tool of the listed
// categories. Tools from external MCP servers are never included —
// re-exporting them would invite dispatch loops and mislead clients about who
// executes what.
func (r *Registry) ExposedTools(readonly bool, categories []string) []Tool {
	cats := make(map[string]bool, len(categories))
	for _, c := range categories {
		cats[strings.ToLower(strings.TrimSpace(c))] = true
	}
	var out []Tool
	for _, t := range r.tools {
		if t.kind == "mcp" {
			continue
		}
		cat := CategoryOf(t.Name)
		if r.disabledCats[cat] {
			continue
		}
		if (readonly && t.readonly) || cats[cat] {
			out = append(out, t)
		}
	}
	return out
}
