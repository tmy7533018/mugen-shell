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
		{
			Name:        "audio_set_mic_volume",
			Description: "Set the microphone input volume. Range 0-100 (percent). Returns the new volume as a string, or a string starting with \"error:\" when no microphone is available — surface that to the user, don't claim success.",
			Parameters: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"volume": map[string]any{
						"type":        "integer",
						"minimum":     0,
						"maximum":     100,
						"description": "Target mic volume in percent (0-100).",
					},
				},
				"required": []string{"volume"},
			},
			target:   "audio",
			function: "set_mic_volume",
			argOrder: []string{"volume"},
		},
		{
			Name:        "audio_get_mic_volume",
			Description: "Read the current microphone input volume (0-100). Returns a string starting with \"error:\" when no microphone is available.",
			Parameters:  emptyParams(),
			target:      "audio",
			function:    "get_mic_volume",
		},
		{
			Name:        "audio_toggle_mic_mute",
			Description: "Toggle the microphone mute state. Returns the new muted state as a string (\"true\"/\"false\"), or a string starting with \"error:\" when no microphone is available.",
			Parameters:  emptyParams(),
			target:      "audio",
			function:    "toggle_mic_mute",
		},
		{
			Name:        "brightness_set",
			Description: "Set the display brightness. Range 0-100 (percent). Returns the new brightness as a string, or a string starting with \"error:\" on desktops without a backlight — surface that to the user, don't claim success.",
			Parameters: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"percent": map[string]any{
						"type":        "integer",
						"minimum":     0,
						"maximum":     100,
						"description": "Target brightness in percent (0-100).",
					},
				},
				"required": []string{"percent"},
			},
			target:   "brightness",
			function: "set",
			argOrder: []string{"percent"},
		},
		{
			Name:        "brightness_get",
			Description: "Read the current display brightness (0-100). Returns a string starting with \"error:\" on desktops without a backlight.",
			Parameters:  emptyParams(),
			target:      "brightness",
			function:    "get",
		},
		{
			Name:        "theme_set",
			Description: "Switch the desktop theme. Accepts \"dark\" or \"light\".",
			Parameters: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"mode": map[string]any{
						"type":        "string",
						"enum":        []string{"dark", "light"},
						"description": "Theme mode: \"dark\" or \"light\".",
					},
				},
				"required": []string{"mode"},
			},
			target:   "theme",
			function: "set",
			argOrder: []string{"mode"},
		},
		{
			Name:        "theme_toggle",
			Description: "Flip between dark and light theme. Returns the new mode.",
			Parameters:  emptyParams(),
			target:      "theme",
			function:    "toggle",
		},
		{
			Name:        "theme_get",
			Description: "Read the current theme mode (\"dark\" or \"light\").",
			Parameters:  emptyParams(),
			target:      "theme",
			function:    "get",
		},
		{
			Name:        "wallpaper_set",
			Description: "Switch the desktop wallpaper. `path` must be an absolute path to a file under the user's wallpaper directory; use wallpaper_list to discover available wallpapers.",
			Parameters: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"path": map[string]any{
						"type":        "string",
						"description": "Absolute path to a wallpaper file.",
					},
				},
				"required": []string{"path"},
			},
			target:   "wallpaper",
			function: "set",
			argOrder: []string{"path"},
		},
		{
			Name:        "wallpaper_current",
			Description: "Read the absolute path of the currently active wallpaper.",
			Parameters:  emptyParams(),
			target:      "wallpaper",
			function:    "current",
		},
		{
			Name:        "wallpaper_list",
			Description: "List available wallpapers as a JSON array of absolute paths.",
			Parameters:  emptyParams(),
			target:      "wallpaper",
			function:    "list",
		},
		{
			Name:        "notification_toggle_dnd",
			Description: "Flip Do Not Disturb. Prefer notification_set_dnd when the user explicitly asks to turn it on or off — toggle is for \"switch DnD\".",
			Parameters:  emptyParams(),
			target:      "notification",
			function:    "toggle_dnd",
		},
		{
			Name:        "notification_set_dnd",
			Description: "Set Do Not Disturb explicitly. When DnD is on, notification popups and sounds are suppressed but history still records them. Idempotent — call this for \"turn DnD on/off\" requests so you don't depend on the current state.",
			Parameters: map[string]any{
				"type": "object",
				"properties": map[string]any{
					"enabled": map[string]any{
						"type":        "boolean",
						"description": "true = DnD on (suppress popups), false = DnD off (allow popups).",
					},
				},
				"required": []string{"enabled"},
			},
			target:   "notification",
			function: "set_dnd",
			argOrder: []string{"enabled"},
		},
		{
			Name:        "notification_get_dnd",
			Description: "Read the current Do Not Disturb state (true = DnD enabled, popups suppressed).",
			Parameters:  emptyParams(),
			target:      "notification",
			function:    "get_dnd",
		},
		{
			Name:        "notification_clear_all",
			Description: "Clear all notification history. Returns the number of notifications cleared. DESTRUCTIVE — confirm in plain language before invoking.",
			Parameters:  emptyParams(),
			target:      "notification",
			function:    "clear_all",
		},
		{
			Name:        "notification_unread",
			Description: "Read the current unread notification count.",
			Parameters:  emptyParams(),
			target:      "notification",
			function:    "unread",
		},
	}
}
