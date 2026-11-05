#!/usr/bin/env bash
# Usage: volume-key.sh up|down  (steps the default sink by volume.step in settings.json, up to volume.max, and unmutes it)

set -euo pipefail

case "${1:-}" in
up) sign=+ ;;
down) sign=- ;;
*)
  echo "usage: $0 up|down" >&2
  exit 2
  ;;
esac

settings="${XDG_CONFIG_HOME:-$HOME/.config}/mugen-shell/settings.json"
# Same clamp and fallback as SettingsManager._volumeStepOf, so the keys and the panel agree.
step=$(jq -r '.volume.step | numbers | round | [., 1] | max | [., 10] | min' "$settings" 2> /dev/null) || step=""
step=${step:-2}

if [[ "$sign" == + ]]; then
  # Same clamp and fallback as SettingsManager._volumeMaxOf.
  limit=$(jq -r '.volume.max | numbers | round | [., 100] | max | [., 150] | min' "$settings" 2> /dev/null) || limit=""
  limit=${limit:-100}
  loudest=$(LC_ALL=C pactl get-sink-volume @DEFAULT_SINK@ | grep -oE '[0-9]+%' | tr -d % | sort -n | tail -1)
  room=$((limit - ${loudest:-0}))
  ((room < step)) && step=$room
fi

# Stays relative: an absolute value would flatten a channel balance.
((step > 0)) && pactl set-sink-volume @DEFAULT_SINK@ "${sign}${step}%"
pactl set-sink-mute @DEFAULT_SINK@ 0
