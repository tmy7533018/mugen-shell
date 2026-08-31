#!/usr/bin/env bash
# Usage: take-screenshot.sh [region|window|screen]

set -euo pipefail

MODE="${1:-region}"

OUTPUT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/mugen-screenshots"
mkdir -p "$OUTPUT_DIR"
stamp=$(date +%Y%m%d_%H%M%S)
output_path="$OUTPUT_DIR/screenshot_$stamp.png"
# Two captures inside one second would otherwise land on the same name.
n=1
while [[ -e "$output_path" ]]; do
  output_path="$OUTPUT_DIR/screenshot_${stamp}_$n.png"
  n=$((n + 1))
done

# The bar takes ~180ms to collapse after the menu closes, and grim would catch it mid-way.
settle() { sleep 0.35; }

case "$MODE" in
region)
  grim -g "$(slurp)" "$output_path"
  ;;
window)
  settle
  geometry=$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
  grim -g "$geometry" "$output_path"
  ;;
screen)
  settle
  grim "$output_path"
  ;;
*)
  echo "Usage: $0 [region|window|screen]" >&2
  exit 1
  ;;
esac

wl-copy < "$output_path"
echo "$output_path"
