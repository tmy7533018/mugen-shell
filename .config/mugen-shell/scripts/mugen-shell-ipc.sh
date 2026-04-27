#!/usr/bin/env bash

IPC_FILE="${XDG_RUNTIME_DIR:-/tmp}/mugen-shell-ipc"

if [ $# -eq 0 ]; then
    cat << EOF
Usage: $0 <mode-name>

Available modes:
  launcher      Open app launcher
  calendar      Open calendar
  wallpaper     Open wallpaper selector
  music         Open music player
  notification  Open notifications
  powermenu     Open power menu
  volume        Open volume control
  close         Close all modules

Examples:
  $0 launcher
  $0 wallpaper
  $0 close
EOF
    exit 1
fi

mkdir -p "$(dirname "$IPC_FILE")" 2>/dev/null || true

if command -v flock >/dev/null 2>&1; then
    exec 9>>"$IPC_FILE"
    if flock -w 0.2 9; then
        printf '%s\n' "$*" >&9
        flock -u 9 || true
        exec 9>&-
        exit 0
    fi
    exec 9>&- || true
fi

if printf '%s\n' "$*" >> "$IPC_FILE" 2>/dev/null; then
    exit 0
else
    echo "Error: Failed to send IPC command" >&2
    echo "Make sure mugen-shell is running" >&2
    exit 1
fi
