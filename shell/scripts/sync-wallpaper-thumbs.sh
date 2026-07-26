#!/usr/bin/env bash
# Usage: sync-wallpaper-thumbs.sh <thumb-dir> [video...]
#
# Prints one line per video: "ok<TAB><path>" when the existing thumbnail is
# still usable, "new<TAB><path>" when it was just regenerated. WallpaperManager
# needs the distinction because Qt only reloads an image whose URL changed.
set -uo pipefail

THUMB_DIR="${1:-}"
[[ -z "$THUMB_DIR" ]] && { echo "Usage: $0 <thumb-dir> [video...]" >&2; exit 1; }
shift

mkdir -p "$THUMB_DIR"

SCALE="scale=360:-1:force_original_aspect_ratio=decrease"

declare -A keep=()
for src; do
  keep["${src##*/}.png"]=1
done

for f in "$THUMB_DIR"/*; do
  [[ -f "$f" ]] || continue
  b="${f##*/}"
  [[ -n "${keep[${b%.failed}]:-}" ]] || rm -f "$f"
done

command -v ffmpeg >/dev/null 2>&1 || exit 0

for src; do
  out="$THUMB_DIR/${src##*/}.png"
  fail="$out.failed"

  if [[ -f "$out" && ! "$src" -nt "$out" ]]; then
    printf 'ok\t%s\n' "$src"
    continue
  fi

  # Without this a file ffmpeg cannot decode would be retried on every poll.
  [[ -f "$fail" && ! "$src" -nt "$fail" ]] && continue

  # Seeking to 2s yields no frame at all on clips shorter than that (gifs,
  # stingers), so fall back to the first frame.
  if ffmpeg -y -v error -ss 2 -i "$src" -vf "$SCALE" -frames:v 1 "$out" >/dev/null 2>&1 && [[ -s "$out" ]]; then
    rm -f "$fail"
    printf 'new\t%s\n' "$src"
  elif ffmpeg -y -v error -i "$src" -vf "$SCALE" -frames:v 1 "$out" >/dev/null 2>&1 && [[ -s "$out" ]]; then
    rm -f "$fail"
    printf 'new\t%s\n' "$src"
  else
    rm -f "$out"
    touch "$fail"
  fi
done
