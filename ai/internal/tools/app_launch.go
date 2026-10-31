package tools

import (
	"fmt"
	"path/filepath"
	"strings"
)

const shellMetachars = ";|&$`<>(){}[]\\!*?\"'\n\r"

func desktopExecRejection(exec string) string {
	if strings.ContainsAny(exec, shellMetachars) {
		return "error: the installed launch command for that app contains shell metacharacters and was blocked for safety."
	}
	return ""
}

func (r *Registry) rejectAppLaunch(args map[string]any) string {
	cmd, _ := args["cmd"].(string)
	if strings.ContainsAny(cmd, shellMetachars) {
		return "error: cmd contains shell metacharacters (;|&$ etc.); only a plain app or binary name is allowed. Tell the user the command was blocked for safety."
	}
	if len(r.allowedApps) == 0 {
		return "error: app launcher has no allowed apps. Tell the user nothing is allowed yet, then immediately call panel_open(name=\"settings\") so they can pick apps via AI / Yura → Allowed apps."
	}
	trimmed := strings.TrimSpace(cmd)
	tokens := strings.Fields(trimmed)
	if len(tokens) == 0 {
		return "error: cmd is empty."
	}
	bin := filepath.Base(tokens[0])
	// A path must match verbatim: /tmp/evil/firefox shares a basename with the real one.
	if len(tokens) == 1 {
		for _, a := range r.allowedApps {
			if a == tokens[0] {
				return ""
			}
		}
	}
	// Flatpak / AppImage apps share one launcher binary, so one "flatpak" entry covers them all.
	if app, ok := r.apps.FindByDisplay(trimmed); ok {
		aliasTokens := strings.Fields(app.Exec)
		if len(aliasTokens) > 0 {
			aliasBin := filepath.Base(aliasTokens[0])
			for _, a := range r.allowedApps {
				if a == aliasBin {
					if rejection := desktopExecRejection(app.Exec); rejection != "" {
						return rejection
					}
					args["cmd"] = app.Exec
					return ""
				}
			}
		}
	}
	if len(tokens) > 1 {
		return fmt.Sprintf("error: app_launch takes no arguments, only an app or binary name, and %q is not an installed app's name either. Retry with just %q if that is the app the user meant. Otherwise tell the user that launching a command with arguments is blocked for safety.", trimmed, bin)
	}
	return fmt.Sprintf("error: %q is not in the app launcher allowlist. Allowed apps right now: %s. If one of those is the same app under a different name (e.g. user said \"zenbrowser\" but the binary is \"zen-bin\"), retry app_launch with that binary. Otherwise tell the user the app is not allowed, then immediately call panel_open(name=\"settings\") so they can enable %q via AI / Yura → Allowed apps.", bin, strings.Join(r.allowedApps, ", "), bin)
}
