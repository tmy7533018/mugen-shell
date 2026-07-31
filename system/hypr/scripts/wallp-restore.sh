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

is_image() { case "${1,,}" in *.png|*.jpg|*.jpeg|*.webp) return 0;; *) return 1;; esac; }
is_video() { case "${1,,}" in *.mp4|*.webm|*.mkv|*.gif) return 0;; *) return 1;; esac; }

# Substring pgrep/pkill: Nix wraps these daemons and truncates comm, so -x misses.
ensure_swww() {
  if ! pgrep awww-daemon >/dev/null 2>&1; then
    setsid nohup awww-daemon --format xrgb >/dev/null 2>&1 &
    for _ in {1..10}; do
      pgrep awww-daemon >/dev/null 2>&1 && break
      sleep 0.05
    done
  fi
}

[[ -f "$CURRENT_WALLPAPER_FILE" ]] || exit 0

TARGET="$(cat "$CURRENT_WALLPAPER_FILE" 2>/dev/null | tr -d '\n')"
[[ -n "${TARGET:-}" && -e "$TARGET" ]] || exit 0

pkill mpvpaper >/dev/null 2>&1 || true

if is_video "$TARGET"; then
  setsid nohup mpvpaper -o "$MPV_OPTS" '*' "$TARGET" >/dev/null 2>&1 &
else
  ensure_swww
  awww img "$TARGET" "${TRANS_OPTS[@]}"
fi
