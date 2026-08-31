#!/usr/bin/env bash
# Usage: sync-clipboard-thumbs.sh <thumb-dir> [id...]
# Prints "ok<TAB><id>" or "new<TAB><id>": Qt only reloads an image whose URL changed.
set -uo pipefail

THUMB_DIR="${1:-}"
[[ -z "$THUMB_DIR" ]] && { echo "Usage: $0 <thumb-dir> [id...]" >&2; exit 1; }
shift

mkdir -p "$THUMB_DIR"

SCALE="scale=360:-1:force_original_aspect_ratio=decrease"

declare -A keep=()
for id; do
  keep["$id.png"]=1
done

for f in "$THUMB_DIR"/*; do
  [[ -f "$f" ]] || continue
  b="${f##*/}"
  [[ -n "${keep[${b%.failed}]:-}" ]] || rm -f "$f"
done

command -v ffmpeg >/dev/null 2>&1 || exit 0

for id; do
  out="$THUMB_DIR/$id.png"
  fail="$out.failed"

  # A cliphist id never points at different bytes, so a decoded thumbnail cannot go stale.
  if [[ -s "$out" ]]; then
    printf 'ok\t%s\n' "$id"
    continue
  fi

  # Without this an entry ffmpeg cannot decode is retried every time the panel opens.
  [[ -f "$fail" ]] && continue

  if cliphist decode "$id" | ffmpeg -y -v error -i pipe: -vf "$SCALE" -frames:v 1 "$out" >/dev/null 2>&1 &&
      [[ -s "$out" ]]; then
    rm -f "$fail"
    printf 'new\t%s\n' "$id"
  else
    rm -f "$out"
    touch "$fail"
  fi
done
