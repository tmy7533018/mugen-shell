#!/usr/bin/env bash

set -euo pipefail

OUTPUT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/mugen-screenshots"
mkdir -p "$OUTPUT_DIR"
filename="screenshot_$(date +%Y%m%d_%H%M%S).png"
output_path="$OUTPUT_DIR/$filename"

grim -g "$(slurp)" "$output_path"

wl-copy < "$output_path"
echo "$output_path"

