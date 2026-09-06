#!/usr/bin/env bash
# Usage: sync-wallpaper-thumbs.sh <thumb-dir> [file...]
# Prints "<state><TAB><path>[<TAB>hue<TAB>chroma<TAB>lightness]" — Qt only reloads an image whose URL changed.
set -uo pipefail

THUMB_DIR="${1:-}"
[[ -z "$THUMB_DIR" ]] && { echo "Usage: $0 <thumb-dir> [file...]" >&2; exit 1; }
shift

mkdir -p "$THUMB_DIR"

SCALE="scale=360:-1:force_original_aspect_ratio=decrease"

# flags=area averages the frame; the default resample leaves noise that pins chroma at 1.0 near white.
hsl_of() {
  local rgb
  rgb=$(ffmpeg -v error -i "$1" -vf scale=1:1:flags=area -f rawvideo -pix_fmt rgb24 - 2>/dev/null |
        od -An -tu1 | tr -s ' \n' ' ')
  [[ -z "${rgb// /}" ]] && return 1
  awk -v v="$rgb" 'BEGIN {
    n = split(v, c, " ")
    if (n < 3) exit 1
    r = c[1] / 255; g = c[2] / 255; b = c[3] / 255
    max = (r > g ? (r > b ? r : b) : (g > b ? g : b))
    min = (r < g ? (r < b ? r : b) : (g < b ? g : b))
    l = (max + min) / 2
    d = max - min
    if (d == 0) { h = 0 }
    else {
      if (max == r)      h = (g - b) / d + (g < b ? 6 : 0)
      else if (max == g) h = (b - r) / d + 2
      else               h = (r - g) / d + 4
      h *= 60
    }
    hi = int(h + 0.5) % 360
    printf "%d %.4f %.4f\n", hi, d, l
  }'
}

emit() {
  local state=$1 src=$2 out=$3
  if [[ -s "$out.color" ]]; then
    printf '%s\t%s\t%s\n' "$state" "$src" "$(tr ' ' '\t' < "$out.color")"
  else
    printf '%s\t%s\n' "$state" "$src"
  fi
}

declare -A keep=()
for src; do
  keep["${src##*/}.png"]=1
done

for f in "$THUMB_DIR"/*; do
  [[ -f "$f" ]] || continue
  b="${f##*/}"
  base="${b%.failed}"
  base="${base%.color}"
  [[ -n "${keep[$base]:-}" ]] || rm -f "$f"
done

command -v ffmpeg >/dev/null 2>&1 || exit 0

for src; do
  out="$THUMB_DIR/${src##*/}.png"
  fail="$out.failed"

  if [[ -f "$out" && ! "$src" -nt "$out" ]]; then
    [[ -s "$out.color" ]] || { hsl_of "$out" > "$out.color" 2>/dev/null || rm -f "$out.color"; }
    emit ok "$src" "$out"
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
    hsl_of "$out" > "$out.color" 2>/dev/null || rm -f "$out.color"
    emit new "$src" "$out"
  else
    rm -f "$out" "$out.color"
    touch "$fail"
  fi
done
