#!/usr/bin/env bash
# Toggle the floating calendar; a separate quickshell process keeps the bar responsive.

set -u

SHELL_PATH="$HOME/.config/quickshell/mugen-shell/calendar-shell.qml"

if pgrep -f "calendar-shell\.qml" >/dev/null 2>&1; then
    pkill -f "calendar-shell\.qml"
    exit 0
fi

setsid nohup quickshell -p "$SHELL_PATH" -d >/dev/null 2>&1 &
disown 2>/dev/null || true
