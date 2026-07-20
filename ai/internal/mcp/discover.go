package mcp

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Candidate is an MCP server found installed on this machine, pre-shaped as
// a config entry the Settings GUI can offer with one tap.
type Candidate struct {
	Name    string   `json:"name"`
	Command string   `json:"command"`
	Args    []string `json:"args"`
	Source  string   `json:"source"`
}

// Discover lists MCP servers installed under npm's global root. Best-effort:
// no npm, no global root, or nothing installed all yield an empty list.
func Discover(ctx context.Context) []Candidate {
	root := npmGlobalRoot(ctx)
	if root == "" {
		return []Candidate{}
	}
	return discoverIn(root)
}

func npmGlobalRoot(ctx context.Context) string {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, "npm", "root", "-g").Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func discoverIn(root string) []Candidate {
	var out []Candidate
	add := func(name, pkg string) {
		out = append(out, Candidate{
			Name:    name,
			Command: "npx",
			Args:    []string{"-y", pkg},
			Source:  "npm-global",
		})
	}

	if entries, err := os.ReadDir(filepath.Join(root, "@modelcontextprotocol")); err == nil {
		for _, e := range entries {
			if e.IsDir() && strings.HasPrefix(e.Name(), "server-") {
				add(strings.TrimPrefix(e.Name(), "server-"), "@modelcontextprotocol/"+e.Name())
			}
		}
	}
	if entries, err := os.ReadDir(root); err == nil {
		for _, e := range entries {
			n := e.Name()
			if !e.IsDir() || strings.HasPrefix(n, "@") {
				continue
			}
			switch {
			case strings.HasPrefix(n, "mcp-server-"):
				add(strings.TrimPrefix(n, "mcp-server-"), n)
			case strings.HasSuffix(n, "-mcp-server"):
				add(strings.TrimSuffix(n, "-mcp-server"), n)
			}
		}
	}

	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	if out == nil {
		out = []Candidate{}
	}
	return out
}
