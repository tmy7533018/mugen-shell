#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:?usage: dpms.sh <on|off>}"

case "$ACTION" in
    on) LUA_ACTION="enable" ;;
    off) LUA_ACTION="disable" ;;
    *)
        echo "unknown action: $ACTION (expected on or off)" >&2
        exit 1
        ;;
esac

# A Lua Hyprland config evaluates `hyprctl dispatch` args as Lua and rejects the legacy string form.
IS_LUA=0
if [[ "${HYPR_CONFIG_LUA:-}" == "1" ]]; then
    IS_LUA=1
elif command -v hyprctl >/dev/null 2>&1 && hyprctl systeminfo 2>/dev/null | grep -qE '^configProvider:\s*lua\s*$'; then
    IS_LUA=1
fi

if [[ "$IS_LUA" == "1" ]]; then
    exec hyprctl dispatch "hl.dsp.dpms({ action = \"${LUA_ACTION}\" })"
fi
exec hyprctl dispatch dpms "$ACTION"
