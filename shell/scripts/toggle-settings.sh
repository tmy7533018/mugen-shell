#!/usr/bin/env bash
# Toggle the mugen-shell floating settings window; with a category argument, an already-open window switches there over ipc instead of closing.

set -u

SHELL_PATH="$HOME/.config/quickshell/mugen-shell/settings-shell.qml"
category="${1:-}"

if pgrep -f "/settings-shell\.qml" >/dev/null 2>&1; then
    if [[ -n "$category" ]]; then
        qs -p "$SHELL_PATH" ipc call settings openCategory "$category"
    else
        pkill -f "/settings-shell\.qml"
    fi
    exit 0
fi

if [[ -n "$category" ]]; then
    MUGEN_SETTINGS_CATEGORY="$category" setsid nohup quickshell -p "$SHELL_PATH" -d >/dev/null 2>&1 &
else
    setsid nohup quickshell -p "$SHELL_PATH" -d >/dev/null 2>&1 &
fi
disown 2>/dev/null || true
