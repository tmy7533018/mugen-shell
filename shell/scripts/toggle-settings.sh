#!/usr/bin/env bash
# Toggle the mugen-shell floating settings window.

set -u

SHELL_PATH="$HOME/.config/quickshell/mugen-shell/settings-shell.qml"

if pgrep -f "/settings-shell\.qml" >/dev/null 2>&1; then
    pkill -f "/settings-shell\.qml"
    exit 0
fi

setsid nohup quickshell -p "$SHELL_PATH" -d >/dev/null 2>&1 &
disown 2>/dev/null || true
