#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/mugen-shell/idle-inhibitor.json"

if [ ! -f "$STATE_FILE" ]; then
    systemctl --user start hypridle.service
    exit 0
fi

INHIBITED=$(grep -o '"enabled":[^,}]*' "$STATE_FILE" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "false")

if [ "$INHIBITED" = "true" ]; then
    exit 0
fi

systemctl --user start hypridle.service
