#!/usr/bin/env bash
set -euo pipefail

CURRENT_WALLPAPER_FILE="$HOME/.config/quickshell/mugen-shell/.cache/wallp/current_wallpaper_path.txt"
TRANS_OPTS=(--transition-type any --transition-fps 60)
MPV_OPTS='no-config no-audio loop cache=yes profile=low-latency'

is_image() { case "${1,,}" in *.png|*.jpg|*.jpeg|*.webp) return 0;; *) return 1;; esac; }
is_video() { case "${1,,}" in *.mp4|*.webm|*.mkv|*.gif) return 0;; *) return 1;; esac; }

ensure_swww() {
  if ! pgrep -x swww-daemon >/dev/null 2>&1; then
    setsid nohup swww-daemon --format xrgb >/dev/null 2>&1 &
    for _ in {1..10}; do
      pgrep -x swww-daemon >/dev/null 2>&1 && break
      sleep 0.05
    done
  fi
}

[[ -f "$CURRENT_WALLPAPER_FILE" ]] || exit 0

TARGET="$(cat "$CURRENT_WALLPAPER_FILE" 2>/dev/null | tr -d '\n')"
[[ -n "${TARGET:-}" && -e "$TARGET" ]] || exit 0

pkill -x mpvpaper >/dev/null 2>&1 || true

if is_video "$TARGET"; then
  setsid nohup mpvpaper -o "$MPV_OPTS" '*' "$TARGET" >/dev/null 2>&1 &
else
  ensure_swww
  swww img "$TARGET" "${TRANS_OPTS[@]}"
fi
