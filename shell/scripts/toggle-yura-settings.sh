#!/usr/bin/env bash
# Toggle the Yura settings window.

set -uo pipefail

SHELL_PATH="$HOME/.config/quickshell/mugen-shell/yura-settings-shell.qml"

if pgrep -f "yura-settings-shell\.qml" >/dev/null 2>&1; then
    pkill -f "yura-settings-shell\.qml"
    exit 0
fi

setsid nohup quickshell -p "$SHELL_PATH" -d >/dev/null 2>&1 &
disown 2>/dev/null || true
