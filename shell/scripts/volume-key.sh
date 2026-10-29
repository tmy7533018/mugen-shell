#!/usr/bin/env bash
# Usage: volume-key.sh up|down  (steps the default sink by volume.step in settings.json and unmutes it)

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
pactl set-sink-volume @DEFAULT_SINK@ "${sign}${step:-2}%"
pactl set-sink-mute @DEFAULT_SINK@ 0
