#!/usr/bin/env bash
# Toggle the floating settings window; a category switches an open one over ipc, and --open raises an open one instead of closing it.

set -uo pipefail

# Resolved from this script's own location, so it cannot disagree with whoever launched it.
SHELL_PATH="$(dirname "$0")/../settings-shell.qml"
open_only=0
if [[ "${1:-}" == "--open" ]]; then
    open_only=1
    shift
fi
category="${1:-}"

# The check and the launch are one step, or two callers both start a window.
LOCK_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/mugen-shell/toggle-settings.lock"
mkdir -p "$(dirname "$LOCK_FILE")"
exec 9>"$LOCK_FILE"
flock 9

if pgrep -f "/settings-shell\.qml" >/dev/null 2>&1; then
    exec 9>&-
    if [[ -n "$category" ]]; then
        qs -p "$SHELL_PATH" ipc call settings openCategory "$category"
        "$(dirname "$0")/raise-window.sh" "Mugen Settings"
    elif [[ $open_only -eq 1 ]]; then
        "$(dirname "$0")/raise-window.sh" "Mugen Settings"
    else
        pkill -f "/settings-shell\.qml"
    fi
    exit 0
fi

if [[ -n "$category" ]]; then
    MUGEN_SETTINGS_CATEGORY="$category" setsid nohup quickshell -p "$SHELL_PATH" -d >/dev/null 2>&1 9>&- &
else
    setsid nohup quickshell -p "$SHELL_PATH" -d >/dev/null 2>&1 9>&- &
fi
disown 2>/dev/null || true
