#!/usr/bin/env bash
# Convert videos to 1920x1080 / 60fps with center crop (no black bars) for wallpaper use.
#
# Usage:
#   ./resize-videos.sh file1.mp4 file2.mp4
#   ./resize-videos.sh ~/Videos/*.mp4
#   ./resize-videos.sh ~/Videos/   # process directory recursively
#
# Output: <original_name>_wall.mp4 in the same directory

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

for ARG in "$@"; do
  if [ -e "$ARG" ]; then
    ARG="$(cd "$(dirname "$ARG")" && pwd)/$(basename "$ARG")"
  else
    echo "Not found: $ARG"
    continue
  fi

  if [ -d "$ARG" ]; then
    while IFS= read -r -d '' f; do
      convert_video "$f"
    done < <(find "$ARG" -type f -iname '*.mp4' -print0)
  elif [ -f "$ARG" ]; then
    convert_video "$ARG"
  else
    echo "Not found: $ARG"
  fi
done

echo "Done!"
