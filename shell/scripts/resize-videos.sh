#!/usr/bin/env bash
# Convert videos to 1920x1080 / 60fps with center crop for wallpaper use.
# Usage: ./resize-videos.sh <file.mp4|dir>...  → <name>_wall.mp4 beside each input.

set -euo pipefail

WIDTH=1920
HEIGHT=1080
FPS=60

convert_video () {
  local INPUT="$1"

  local BASENAME="$(basename "$INPUT" | sed 's/\.[^.]*$//')"
  local DIR="$(dirname "$INPUT")"
  local OUTPUT="${DIR}/${BASENAME}_wall.mp4"

  echo "Converting: $INPUT → $OUTPUT"

  if [ ! -f "$INPUT" ]; then
    echo "Error: file not found: $INPUT"
    return 1
  fi

  ffmpeg -y -i "$INPUT" \
    -vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=increase,\
crop=${WIDTH}:${HEIGHT}:(in_w-${WIDTH})/2:(in_h-${HEIGHT})/2,\
fps=${FPS}" \
    -c:v libx264 -preset fast -crf 20 -an \
    "$OUTPUT"
}

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 <files or directories>"
  exit 1
fi

FAILED=0

for ARG in "$@"; do
  if [ -e "$ARG" ]; then
    ARG="$(cd "$(dirname "$ARG")" && pwd)/$(basename "$ARG")"
  else
    echo "Not found: $ARG"
    continue
  fi

  if [ -d "$ARG" ]; then
    while IFS= read -r -d '' f; do
      convert_video "$f" || FAILED=$((FAILED + 1))
    done < <(find "$ARG" -type f -iname '*.mp4' ! -iname '*_wall.mp4' -print0)
  elif [ -f "$ARG" ]; then
    convert_video "$ARG" || FAILED=$((FAILED + 1))
  else
    echo "Not found: $ARG"
  fi
done

if [ "$FAILED" -ne 0 ]; then
  echo "Done, $FAILED failed." >&2
  exit 1
fi

echo "Done!"
