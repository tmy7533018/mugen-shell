#!/usr/bin/env bash
set -euo pipefail

WALLP_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/mugen-shell/wallp"
CURRENT_WALLPAPER_FILE="$WALLP_DIR/current_wallpaper_path.txt"
MPV_SOCKET="$WALLP_DIR/mpvpaper.sock"
TRANS_OPTS=(--transition-type any --transition-fps 60)

# Must stay in step with change-wallpaper.sh. Without the ipc socket and the
# auto-copy readback, the next change cannot screenshot this video, so it tears
# the layer down with nothing underneath and the screen goes black first.
MPV_OPTS="no-config no-audio loop cache=yes profile=low-latency \
vo=gpu-next gpu-context=wayland \
hwdec=auto-copy \
keep-open=yes \
input-ipc-server=${MPV_SOCKET} \
screenshot-format=png screenshot-high-bit-depth=no screenshot-png-compression=1"

is_video() { case "${1,,}" in *.mp4|*.webm|*.mkv|*.gif) return 0;; *) return 1;; esac; }

# The daemon is up long before it listens, so a running process is not readiness.
swww_ready() { awww query >/dev/null 2>&1; }

ensure_swww() {
  swww_ready && return 0
  setsid nohup awww-daemon --format xrgb --no-cache >/dev/null 2>&1 &
  for _ in {1..60}; do
    swww_ready && return 0
    sleep 0.05
  done
  return 1
}

[[ -f "$CURRENT_WALLPAPER_FILE" ]] || exit 0

TARGET="$(cat "$CURRENT_WALLPAPER_FILE" 2>/dev/null | tr -d '\n')"
[[ -n "${TARGET:-}" && -e "$TARGET" ]] || exit 0

# Substring pkill: Nix wraps this daemon and truncates comm, so -x misses.
pkill mpvpaper >/dev/null 2>&1 || true

if is_video "$TARGET"; then
  setsid nohup mpvpaper -o "$MPV_OPTS" '*' "$TARGET" >/dev/null 2>&1 &
else
  ensure_swww
  awww img --resize crop "$TARGET" "${TRANS_OPTS[@]}"
fi
