#!/usr/bin/env bash
# Usage: sync-wallpaper-thumbs.sh <thumb-dir> [file...]
# Prints "ok<TAB><path>" or "new<TAB><path>" — Qt only reloads an image whose URL changed.
set -uo pipefail

THUMB_DIR="${1:-}"
[[ -z "$THUMB_DIR" ]] && { echo "Usage: $0 <thumb-dir> [file...]" >&2; exit 1; }
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

  ok=0
  # Seeking only makes sense for video, and on a still it just costs a wasted ffmpeg run.
  case "${src,,}" in
  *.mp4|*.webm|*.mkv|*.gif)
    # A clip shorter than 2s yields no frame there, so the first-frame pass below catches it.
    ffmpeg -y -v error -ss 2 -i "$src" -vf "$SCALE" -frames:v 1 "$out" >/dev/null 2>&1 &&
      [[ -s "$out" ]] && ok=1
    ;;
  esac

  if [[ $ok -eq 0 ]]; then
    ffmpeg -y -v error -i "$src" -vf "$SCALE" -frames:v 1 "$out" >/dev/null 2>&1 &&
      [[ -s "$out" ]] && ok=1
  fi

  if [[ $ok -eq 1 ]]; then
    rm -f "$fail"
    printf 'new\t%s\n' "$src"
  else
    rm -f "$out"
    touch "$fail"
  fi
done
