// Package tools exposes shell-control tools to the LLM via mugen-shell's
// quickshell IPC. Each tool maps to a `qs ipc call <target> <function> [args]`
// invocation; the registry is the catalog presented to providers as
// function-calling tools.
package tools

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
)

type Tool struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Parameters  map[string]any `json:"parameters"`

	target   string
	function string
	argOrder []string
}

type Registry struct {
	qsConfig string
	tools    []Tool
}

func New(qsConfig string) *Registry {
	if qsConfig == "" {
		qsConfig = "mugen-shell"
	}
	return &Registry{
		qsConfig: qsConfig,
		tools:    builtin(),
	}
}

func (r *Registry) List() []Tool {
	return r.tools
}

func (r *Registry) Find(name string) *Tool {
	for i := range r.tools {
		if r.tools[i].Name == name {
			return &r.tools[i]
		}
	}
	return nil
}

// Call executes the named tool with the given arguments and returns the raw
// stdout of `qs ipc call`. Errors include qs exit status and combined output
// so the provider can surface them back to the LLM.
func (r *Registry) Call(ctx context.Context, name string, args map[string]any) (string, error) {
	t := r.Find(name)
	if t == nil {
		return "", fmt.Errorf("unknown tool: %s", name)
	}
	cmdArgs := []string{"-c", r.qsConfig, "ipc", "call", t.target, t.function}
	for _, key := range t.argOrder {
		v, ok := args[key]
		if !ok {
			return "", fmt.Errorf("missing argument %q for tool %s", key, name)
		}
		cmdArgs = append(cmdArgs, fmt.Sprint(v))
	}
	out, err := exec.CommandContext(ctx, "qs", cmdArgs...).CombinedOutput()
	res := strings.TrimSpace(string(out))
	if err != nil {
		return res, fmt.Errorf("qs ipc call %s.%s failed: %w (output: %s)", t.target, t.function, err, res)
	}
	return res, nil
}

func emptyParams() map[string]any {
	return map[string]any{
		"type":       "object",
		"properties": map[string]any{},
	}
}

func builtin() []Tool {
	return []Tool{
		{
			Name:        "audio_set_volume",
			Description: "Set the system output volume. Range 0-100 (percent).",
			Parameters: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"volume": map[string]any{
						"type":        "integer",
						"minimum":     0,
						"maximum":     100,
						"description": "Target volume in percent (0-100).",
					},
				},
				"required": []string{"volume"},
			},
			target:   "audio",
			function: "set_volume",
			argOrder: []string{"volume"},
		},
		{
			Name:        "audio_get_volume",
			Description: "Read the current system output volume (0-100).",
			Parameters:  emptyParams(),
			target:      "audio",
			function:    "get_volume",
		},
		{
			Name:        "audio_toggle_mute",
			Description: "Toggle the output mute state. Returns the new muted state.",
			Parameters:  emptyParams(),
			target:      "audio",
			function:    "toggle_mute",
		},
		{
			Name:        "music_toggle",
			Description: "Play or pause the currently active MPRIS music player.",
			Parameters:  emptyParams(),
			target:      "music",
			function:    "toggle",
		},
		{
			Name:        "music_next",
			Description: "Skip to the next track on the active MPRIS music player.",
			Parameters:  emptyParams(),
			target:      "music",
			function:    "next",
		},
		{
			Name:        "music_previous",
			Description: "Skip to the previous track on the active MPRIS music player.",
			Parameters:  emptyParams(),
			target:      "music",
			function:    "previous",
		},
		{
			Name:        "panel_open",
			Description: "Open a mugen-shell side panel. Valid names include: volume, wifi, bluetooth, brightness, calendar, ai, settings, timer, clipboard, notification, wallpaper, power.",
			Parameters: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"name": map[string]any{
						"type":        "string",
						"description": "Panel name.",
					},
				},
				"required": []string{"name"},
			},
			target:   "panel",
			function: "open",
			argOrder: []string{"name"},
		},
		{
			Name:        "panel_close",
			Description: "Close any open mugen-shell side panel.",
			Parameters:  emptyParams(),
			target:      "panel",
			function:    "close",
		},
	}
}
