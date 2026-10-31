// Package tools is the registry of what the assistant can call: shell IPC, native and MCP tools.
package tools

import (
	"context"
	"fmt"
	"maps"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/tmy7533018/mugen-ai/internal/apps"
	"github.com/tmy7533018/mugen-ai/internal/mcp"
	"github.com/tmy7533018/mugen-ai/internal/store"
)

type Tool struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Parameters  map[string]any `json:"parameters"`

	target   string
	function string
	argOrder []string

	// Exec'd instead of `qs ipc call`, for tools whose data comes from a process rather than the shell.
	cmdTemplate []string

	// readonly runs under an RLock; anything mutating shell state takes the exclusive lock.
	readonly bool

	// Some IPC calls only start detached work, so confirmFn re-reads until the target agrees.
	confirmFn string

	// kind selects the dispatch path: empty is built-in, "mcp" external, "native" in-process.
	kind      string
	mcpServer string
	mcpTool   string // un-prefixed name on that server

	fn func(ctx context.Context, args map[string]any) (string, error)

	// Irreversible effects: the chat loop blocks on the user's approval first.
	needsConfirm bool
}

type Registry struct {
	qsConfig     string
	allowedApps  []string
	disabledCats map[string]bool
	auditor      *Auditor
	apps         *apps.Resolver
	mcp          *mcp.Manager
	memStore     *store.Store
	calendarPath string
	tools        []Tool
	mu           sync.RWMutex

	// A field so tests need not wait out the real budget.
	callTimeout time.Duration

	// A field so tests can substitute a fake for the real subprocess exec.
	run func(ctx context.Context, name string, args []string) (string, error)
}

func New(qsConfig string, allowedApps, disabledCategories []string, auditor *Auditor) *Registry {
	if qsConfig == "" {
		qsConfig = "mugen-shell"
	}
	disabled := make(map[string]bool, len(disabledCategories))
	for _, c := range disabledCategories {
		disabled[strings.ToLower(strings.TrimSpace(c))] = true
	}
	return &Registry{
		qsConfig:     qsConfig,
		allowedApps:  allowedApps,
		disabledCats: disabled,
		auditor:      auditor,
		apps:         apps.Load(),
		tools:        builtin(),
		run:          execCommand,
		callTimeout:  defaultCallTimeout,
	}
}

// Held under the registry lock, so an unbounded tool would wedge every conversation.
const defaultCallTimeout = 60 * time.Second

func execCommand(ctx context.Context, name string, args []string) (string, error) {
	out, err := exec.CommandContext(ctx, name, args...).CombinedOutput()
	return strings.TrimSpace(string(out)), err
}

// Re-invoking by name would run whichever mugen-ai PATH finds first, not this binary.
var selfPath = sync.OnceValue(func() string {
	if path, err := os.Executable(); err == nil {
		return path
	}
	return "mugen-ai"
})

// NeedsConfirm reports whether the named tool must be approved by the user
// before the chat loop runs it. Unknown tools return false.
func (r *Registry) NeedsConfirm(name string) bool {
	t := r.Find(name)
	return t != nil && t.needsConfirm
}

// Audit records a tool decision that never reached Call(), chiefly a
// confirmation the user denied.
func (r *Registry) Audit(name string, args map[string]any, result string, err error) {
	r.auditor.Log(name, args, result, err)
}

// CategoryOf returns a tool's category: the server name for an MCP tool ("server__tool"), else the
// prefix before the first underscore. Lowercased to match Registry.New's disabled-set keys.
func CategoryOf(toolName string) string {
	if i := strings.Index(toolName, "__"); i > 0 {
		return strings.ToLower(toolName[:i])
	}
	if i := strings.Index(toolName, "_"); i > 0 {
		return strings.ToLower(toolName[:i])
	}
	return strings.ToLower(toolName)
}

func (r *Registry) List() []Tool {
	if len(r.disabledCats) == 0 {
		return r.tools
	}
	filtered := make([]Tool, 0, len(r.tools))
	for _, t := range r.tools {
		if !r.disabledCats[CategoryOf(t.Name)] {
			filtered = append(filtered, t)
		}
	}
	return filtered
}

func (r *Registry) Find(name string) *Tool {
	for i := range r.tools {
		if r.tools[i].Name == name {
			return &r.tools[i]
		}
	}
	return nil
}

// IsCategoryDisabled lets Call() reject invocations even when the model somehow
// saw the tool, e.g. an old conversation that still references it.
func (r *Registry) IsCategoryDisabled(category string) bool {
	return r.disabledCats[category]
}

// Call runs the named tool and returns its result, sanitized for the LLM.
func (r *Registry) Call(ctx context.Context, name string, args map[string]any) (string, error) {
	t := r.Find(name)
	if t == nil {
		return "", fmt.Errorf("unknown tool: %s", name)
	}

	if cat := CategoryOf(name); r.disabledCats[cat] {
		msg := fmt.Sprintf("error: tool category %q is disabled in [tools].disabled_categories. First tell the user the %s category is currently off, then immediately call panel_open(name=\"settings\") so they can re-enable it via AI / Yura → Tool categories. After that you may suggest a workaround if one fits.", cat, cat)
		r.auditor.Log(name, args, msg, nil)
		return msg, nil
	}

	if t.readonly {
		r.mu.RLock()
		defer r.mu.RUnlock()
	} else {
		r.mu.Lock()
		defer r.mu.Unlock()
	}

	ctx, cancel := context.WithTimeout(ctx, r.callTimeout)
	defer cancel()

	if name == "app_launch" {
		// Resolved in a copy: the caller's map is the model's call as history replays it.
		args = maps.Clone(args)
		if rejection := r.rejectAppLaunch(args); rejection != "" {
			r.auditor.Log(name, args, rejection, nil)
			return rejection, nil
		}
		// Off-$PATH binaries need the absolute Exec path, or Hyprland fails the exec silently.
		// Only for a bare name: an absolute path was allowlisted verbatim in rejectAppLaunch
		// and must not be swapped for a different binary that happens to share its basename.
		if cmd, _ := args["cmd"].(string); cmd != "" {
			tokens := strings.Fields(strings.TrimSpace(cmd))
			if len(tokens) > 0 && !strings.ContainsRune(tokens[0], filepath.Separator) {
				bin := filepath.Base(tokens[0])
				if resolved := r.apps.Resolve(bin); resolved != "" {
					resolvedTokens := strings.Fields(resolved)
					if len(resolvedTokens) > 0 {
						if rejection := desktopExecRejection(resolvedTokens[0]); rejection != "" {
							r.auditor.Log(name, args, rejection, nil)
							return rejection, nil
						}
						tokens[0] = resolvedTokens[0]
						args["cmd"] = strings.Join(tokens, " ")
					}
				}
			}
		}
	}

	if t.kind == "mcp" {
		if r.mcp == nil {
			msg := fmt.Sprintf("error: MCP server %q is not connected. Tell the user the server is unavailable.", t.mcpServer)
			r.auditor.Log(name, args, msg, nil)
			return msg, nil
		}
		// Re-dials transparently, so a server that crashed since startup self-heals on next use.
		out, err := r.mcp.Call(ctx, t.mcpServer, t.mcpTool, args)
		res := strings.TrimSpace(out)
		r.auditor.Log(name, args, res, err)
		if err != nil {
			return "", fmt.Errorf("%s failed: %w", name, err)
		}
		return sanitizeForLLM(res), nil
	}

	if t.kind == "native" {
		out, err := t.fn(ctx, args)
		res := strings.TrimSpace(out)
		r.auditor.Log(name, args, res, err)
		if err != nil {
			return "", fmt.Errorf("%s failed: %w", name, err)
		}
		return sanitizeForLLM(res), nil
	}

	var cmdName string
	var cmdArgs []string

	if len(t.cmdTemplate) > 0 {
		expanded, err := expandTemplate(t.cmdTemplate, args)
		if err != nil {
			return "", fmt.Errorf("expand %s: %w", name, err)
		}
		if len(expanded) == 0 {
			return "", fmt.Errorf("empty command for tool %s", name)
		}
		cmdName = expanded[0]
		cmdArgs = expanded[1:]
	} else {
		cmdName = "qs"
		var posArgs []string
		for _, key := range t.argOrder {
			v, ok := args[key]
			if !ok {
				return "", fmt.Errorf("missing argument %q for tool %s", key, name)
			}
			posArgs = append(posArgs, fmt.Sprint(v))
		}
		// Quickshell filters `qs ipc` by display, which this headless service lacks; --pid bypasses it.
		if pid := r.resolveQsPID(ctx); pid > 0 {
			cmdArgs = []string{"ipc", "--pid", strconv.Itoa(pid), "call", t.target, t.function}
		} else {
			cmdArgs = []string{"-c", r.qsConfig, "ipc", "call", t.target, t.function}
		}
		cmdArgs = append(cmdArgs, posArgs...)
	}

	res, err := r.run(ctx, cmdName, cmdArgs)
	out := sanitizeForLLM(res)
	var callErr error
	switch {
	case err != nil:
		callErr = fmt.Errorf("%s failed: %w (output: %s)", name, err, out)
	case t.confirmFn != "" && !strings.HasPrefix(res, "error:"):
		if got, ok := r.confirm(ctx, t, res); !ok {
			callErr = fmt.Errorf("%s did not take effect: %s reports %q. Tell the user it failed; do not claim it worked", name, t.target, got)
		}
	}
	r.auditor.Log(name, args, res, callErr)
	return out, callErr
}

var placeholderRe = regexp.MustCompile(`\{\{(\w+)\}\}`)

// Substituted values are never re-scanned, so an argument containing "{{...}}" stays literal.
func expandTemplate(tmpl []string, args map[string]any) ([]string, error) {
	out := make([]string, 0, len(tmpl))
	for _, tok := range tmpl {
		var unresolved string
		s := placeholderRe.ReplaceAllStringFunc(tok, func(m string) string {
			key := m[2 : len(m)-2]
			if key == "self" {
				return selfPath()
			}
			if v, ok := args[key]; ok {
				return fmt.Sprint(v)
			}
			unresolved = key
			return m
		})
		if unresolved != "" {
			return nil, fmt.Errorf("unresolved placeholder %q in token %q", unresolved, tok)
		}
		out = append(out, s)
	}
	return out, nil
}

func emptyParams() map[string]any {
	return map[string]any{
		"type":       "object",
		"properties": map[string]any{},
	}
}
