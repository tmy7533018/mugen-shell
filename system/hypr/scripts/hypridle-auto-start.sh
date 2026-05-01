#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/mugen-shell/idle-inhibitor.json"

if [ ! -f "$STATE_FILE" ]; then
    systemctl --user start hypridle.service
    exit 0
fi

ENABLED=$(cat "$STATE_FILE" 2>/dev/null | grep -o '"enabled":[^,}]*' | cut -d: -f2 | tr -d ' ' || echo "true")

if [ "$ENABLED" = "false" ]; then
    exit 0
else
    systemctl --user start hypridle.service
fi
