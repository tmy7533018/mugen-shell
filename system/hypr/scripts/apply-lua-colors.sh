#!/usr/bin/env bash
# Apply the wallpaper-following border colors live. Under the Lua config
# `hyprctl reload` does not re-run hyprland.lua (unlike the legacy .conf source
# reload), so matugen calls this after regenerating colors.lua to push the two
# border colors via runtime keywords. Harmless under the legacy config too.
set -euo pipefail

COLORS="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/colors.lua"
[[ -f "$COLORS" ]] || exit 0

active=$(grep -oP '"outline"\]\s*=\s*"\K[^"]+' "$COLORS" || true)
inactive=$(grep -oP '"outline_variant"\]\s*=\s*"\K[^"]+' "$COLORS" || true)

[[ -n "$active"   ]] && hyprctl keyword general:col.active_border   "$active"   >/dev/null 2>&1 || true
[[ -n "$inactive" ]] && hyprctl keyword general:col.inactive_border "$inactive" >/dev/null 2>&1 || true
