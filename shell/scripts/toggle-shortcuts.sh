#!/usr/bin/env bash
# Toggle the keyboard shortcuts reference window; a running instance is killed.

set -u

SHELL_PATH="$HOME/.config/quickshell/mugen-shell/shortcuts-shell.qml"

if pgrep -f "shortcuts-shell\.qml" >/dev/null 2>&1; then
    pkill -f "shortcuts-shell\.qml"
    exit 0
fi

setsid nohup quickshell -p "$SHELL_PATH" -d >/dev/null 2>&1 &
disown 2>/dev/null || true
