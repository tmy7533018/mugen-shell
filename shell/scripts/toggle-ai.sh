#!/usr/bin/env bash
# Toggle the mugen-shell floating AI assistant window.

set -u

SHELL_PATH="$HOME/.config/quickshell/mugen-shell/ai-shell.qml"

if pgrep -f "ai-shell\.qml" >/dev/null 2>&1; then
    pkill -f "ai-shell\.qml"
    exit 0
fi

setsid nohup quickshell -p "$SHELL_PATH" -d >/dev/null 2>&1 &
disown 2>/dev/null || true
