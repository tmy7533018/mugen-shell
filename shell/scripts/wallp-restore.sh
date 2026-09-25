#!/usr/bin/env bash
set -euo pipefail

WALLP_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/mugen-shell/wallp"
CURRENT_WALLPAPER_FILE="$WALLP_DIR/current_wallpaper_path.txt"
source "$(dirname "${BASH_SOURCE[0]}")/mpvpaper-opts.sh"
TRANS_OPTS=(--transition-type any --transition-fps 60)

is_video() { case "${1,,}" in *.mp4|*.webm|*.mkv|*.gif) return 0;; *) return 1;; esac; }

# The daemon is up long before it listens, so a running process is not readiness.
swww_ready() { awww query >/dev/null 2>&1; }

# A service restart kills the shell's whole cgroup, so the daemons get a scope of their own.
spawn_daemon() {
  setsid nohup systemd-run --user --scope --quiet -- "$@" >/dev/null 2>&1 &
}

ensure_swww() {
  swww_ready && return 0
  spawn_daemon awww-daemon --format xrgb --no-cache
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

# Spawning before the old process is gone races its socket unlink and flashes black.
for _ in {1..10}; do
  pgrep mpvpaper >/dev/null 2>&1 || break
  sleep 0.1
done

if is_video "$TARGET"; then
  spawn_daemon mpvpaper -o "$MPV_OPTS" '*' "$TARGET"
else
  ensure_swww
  awww img --resize crop "$TARGET" "${TRANS_OPTS[@]}"
fi
