#!/usr/bin/env bash
set -uo pipefail

# Hyprland launches this for non-consuming printable-key binds. Ignore the event
# whenever a client owns focus, so typing in an application remains unchanged.
code="${1:-}"
[[ "$code" =~ ^[0-9]{2,3}$ ]] || exit 0
(( code >= 32 && code <= 126 )) || exit 0
if ! hyprctl -j activewindow | jq -e 'length == 0' >/dev/null 2>&1; then
    exit 0
fi

exec "$(dirname "$0")/mugen-shell-ipc.sh" "typecode" "$code"
