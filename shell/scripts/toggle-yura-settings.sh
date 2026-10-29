#!/usr/bin/env bash
# Toggle the Yura settings window; --open raises an open one instead of closing it.

set -uo pipefail

# Resolved from this script's own location, so it cannot disagree with whoever launched it.
SHELL_PATH="$(dirname "$0")/../yura-settings-shell.qml"
open_only=0
if [[ "${1:-}" == "--open" ]]; then
    open_only=1
fi

# The check and the launch are one step, or two callers both start a window.
LOCK_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/mugen-shell/toggle-yura-settings.lock"
mkdir -p "$(dirname "$LOCK_FILE")"
exec 9>"$LOCK_FILE"
flock 9

if pgrep -f "yura-settings-shell\.qml" >/dev/null 2>&1; then
    exec 9>&-
    if [[ $open_only -eq 1 ]]; then
        "$(dirname "$0")/raise-window.sh" "Yura Settings"
    else
        pkill -f "yura-settings-shell\.qml"
    fi
    exit 0
fi

setsid nohup quickshell -p "$SHELL_PATH" -d >/dev/null 2>&1 9>&- &
disown 2>/dev/null || true
