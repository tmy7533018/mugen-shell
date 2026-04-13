#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
THUMB_DIR="$SHELL_DIR/.cache/wallp"
mkdir -p "$THUMB_DIR"

DEBUG_LOG="$THUMB_DIR/debug.log"

debug_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$DEBUG_LOG"
}

debug_log "========== NEW EXECUTION =========="
debug_log "Called with: $*"
debug_log "PWD: $PWD"
debug_log "USER: ${USER:-unknown}"
debug_log "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-not set}"
debug_log "XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR:-not set}"
debug_log "PATH: $PATH"

WALLPAPER="$1"
[[ -z "${WALLPAPER:-}" ]] && { echo "Usage: $0 <wallpaper-path>" >&2; exit 1; }
[[ ! -f "$WALLPAPER" ]] && { echo "File not found: $WALLPAPER" >&2; exit 1; }

WALLPAPER_ABS="$(cd "$(dirname "$WALLPAPER")" && pwd)/$(basename "$WALLPAPER")"

THUMB_FILE="$THUMB_DIR/current_wallpaper_thumb.png"
CURRENT_WALLPAPER_FILE="$THUMB_DIR/current_wallpaper_path.txt"
MPV_SOCKET="$THUMB_DIR/mpvpaper.sock"
LOCK="$THUMB_DIR/.wallp.lock"

TRANS_OPTS=(
  --transition-type wave
  --transition-fps 144
  --transition-duration 1.3
  --transition-angle 30
  --transition-wave 40,40
  --transition-step 20
  --transition-bezier 0.25,0.1,0.25,1.0
)

TRANS_SEC=1.0

MPV_OPTS="no-config no-audio loop cache=yes profile=low-latency \
vo=gpu-next gpu-context=wayland \
hwdec=auto \\
keep-open=yes \
input-ipc-server=${MPV_SOCKET} \
screenshot-format=png screenshot-high-bit-depth=no screenshot-png-compression=1"

# Remove stale lock files older than 60 seconds
find "$THUMB_DIR" -name '.wallp.lock' -mmin +1 -delete 2>/dev/null || true

exec 9>"$LOCK"
if ! flock -n 9; then
  if [[ -f "$LOCK" ]]; then
    lock_age=$(($(date +%s) - $(stat -c %Y "$LOCK" 2>/dev/null || echo 0)))
    if ((lock_age > 60)); then
      echo "Stale lock file detected (${lock_age}s old), removing..." >&2
      rm -f "$LOCK"
      exec 9>"$LOCK"
      flock -n 9 || { echo "Still cannot acquire lock" >&2; exit 1; }
    else
      echo "Already running (locked ${lock_age}s ago)" >&2
      exit 1
    fi
  else
    echo "Already running" >&2
    exit 1
  fi
fi
cleanup() {
  debug_log "Cleanup: releasing lock"
  exec 9>&-
  rm -f "$LOCK"
  find "$THUMB_DIR" -name 'wprev.*.png' -mmin +5 -delete 2>/dev/null || true
  debug_log "========== EXECUTION COMPLETED =========="
}
trap cleanup EXIT

is_image() {
  case "${1,,}" in
    *.png|*.jpg|*.jpeg|*.webp) return 0 ;;
    *) return 1 ;;
  esac
}

is_video() {
  case "${1,,}" in
    *.mp4|*.webm|*.mkv|*.gif) return 0 ;;
    *) return 1 ;;
  esac
}

swww_ready() {
  awww query >/dev/null 2>&1
}

start_swww() {
  setsid nohup awww-daemon --format xrgb --no-cache >/dev/null 2>&1 &
}

ensure_swww() {
  debug_log "ensure_swww: checking awww-daemon status"
  if ! swww_ready; then
    debug_log "ensure_swww: awww-daemon not ready, starting..."
    pkill -x awww-daemon >/dev/null 2>&1 || true
    start_swww
  fi

  for _ in {1..60}; do
    swww_ready && { debug_log "ensure_swww: awww-daemon ready"; return 0; }
    sleep 0.05
  done

  echo "awww-daemon not ready" >&2
  debug_log "ensure_swww: FAILED - awww-daemon not ready"
  return 1
}

ensure_swww_top_if_mpvpaper() {
  if pgrep -x mpvpaper >/dev/null 2>&1; then
    pkill -x awww-daemon >/dev/null 2>&1 || true
    start_swww
    for _ in {1..60}; do
      swww_ready && return 0
      sleep 0.05
    done
  else
    ensure_swww
  fi
}

swww_set_no_transition() {
  ensure_swww || return 1

  if awww img --help 2>/dev/null | grep -q -- '--transition-type'; then
    awww img --resize crop "$1" --transition-type none --transition-duration 0 --transition-fps 1 2>/dev/null \
    || awww img --resize crop "$1" --transition-duration 0 --transition-fps 1
  else
    awww img --resize crop "$1" --transition-duration 0 --transition-fps 1
  fi
}

mpv_ipc_send() {
  local payload="$1"
  if command -v socat >/dev/null 2>&1; then
    printf '%s\n' "$payload" | socat - UNIX-CONNECT:"$MPV_SOCKET" 2>/dev/null
  elif command -v nc >/dev/null 2>&1; then
    printf '%s\n' "$payload" | nc -U "$MPV_SOCKET" 2>/dev/null
  else
    return 1
  fi
}

stop_mpvpaper() {
  if [[ -S "$MPV_SOCKET" ]]; then
    mpv_ipc_send '{"command":["quit"]}' >/dev/null 2>&1 || true
    sleep 0.2
  fi

  if pgrep -x mpvpaper >/dev/null 2>&1; then
    pkill -x mpvpaper 2>/dev/null || true
    for _ in {1..10}; do
      pgrep -x mpvpaper >/dev/null 2>&1 || break
      sleep 0.1
    done
  fi

  if pgrep -x mpvpaper >/dev/null 2>&1; then
    pkill -9 -x mpvpaper 2>/dev/null || true
  fi

  [[ -S "$MPV_SOCKET" ]] && rm -f "$MPV_SOCKET" || true
}

freeze_and_shot_current_frame() {
  [[ -S "$MPV_SOCKET" ]] || return 1

  mpv_ipc_send '{"command":["set_property","pause",true]}' >/dev/null 2>&1 || true

  local out
  out="$(mktemp "$THUMB_DIR/wprev.XXXXXX.png")"
  mpv_ipc_send "{\"command\":[\"screenshot-to-file\",\"${out}\",\"video\"]}" >/dev/null 2>&1 || true

  for _ in {1..40}; do
    [[ -s "$out" ]] && { printf '%s' "$out"; return 0; }
    sleep 0.01
  done

  return 1
}

grab_current_video_frame_via_ipc() {
  [[ -S "$MPV_SOCKET" ]] || return 1
  command -v ffmpeg >/dev/null 2>&1 || return 1

  local json path curtime tries=0 out

  json="$(mpv_ipc_send '{"command":["get_property","path"]}')" || true
  path="$(printf '%s' "$json" | sed -n 's/.*"data"\s*:\s*"\([^"]\+\)".*/\1/p')" || true
  [[ -n "${path:-}" && -f "$path" ]] || return 1

  while :; do
    json="$(mpv_ipc_send '{"command":["get_property","time-pos"]}')" || true
    curtime="$(printf '%s' "$json" | sed -n 's/.*"data"\s*:\s*\([0-9]\+\(\.[0-9]\+\)\?\).*/\1/p')" || true
    [[ -n "${curtime:-}" ]] && break
    ((tries++>=2)) && curtime=0 && break
    sleep 0.02
  done

  out="$(mktemp "$THUMB_DIR/wprev.XXXXXX.png")"
  ffmpeg -y -v error -i "$path" -ss "$curtime" \
    -frames:v 1 -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=0x00000000" \
    "$out" >/dev/null 2>&1 || return 1

  [[ -s "$out" ]] || return 1
  printf '%s' "$out"
}

# For smooth transitions when switching from video wallpapers, capture the current
# mpvpaper frame and set it via swww before stopping mpvpaper.
prev_applied=false
if pgrep -x mpvpaper >/dev/null 2>&1; then
  echo "Capturing current video frame for smooth transition..."

  prev_png="$(freeze_and_shot_current_frame 2>/dev/null || true)"
  [[ -z "${prev_png:-}" ]] && prev_png="$(grab_current_video_frame_via_ipc 2>/dev/null || true)"

  if [[ -n "${prev_png:-}" && -s "$prev_png" ]]; then
    ensure_swww_top_if_mpvpaper
    if swww_set_no_transition "$prev_png"; then
      prev_applied=true
      echo "Current frame captured and displayed"
      sleep 0.3
    fi
    rm -f "$prev_png"
  fi
fi

if is_image "$WALLPAPER_ABS"; then
  echo "Setting image wallpaper: $WALLPAPER_ABS"
  debug_log "Setting image wallpaper: $WALLPAPER_ABS"

  if command -v matugen >/dev/null 2>&1; then
    echo "Generating color palette with matugen..."
    debug_log "Running matugen..."
    if matugen_output=$(matugen image "$WALLPAPER_ABS" 2>&1); then
      echo "$matugen_output" >> "$DEBUG_LOG"
      echo "Color palette generated successfully"
      debug_log "matugen: success"
    else
      echo "$matugen_output" >> "$DEBUG_LOG"
      echo "matugen failed with exit code $?"
      debug_log "matugen: FAILED"
    fi
  fi

  ensure_swww
  debug_log "Running awww img with TRANS_OPTS"
  if swww_output=$(awww img --resize crop "$WALLPAPER_ABS" "${TRANS_OPTS[@]}" 2>&1); then
    echo "$swww_output" >> "$DEBUG_LOG"
    debug_log "awww img: success"
  else
    echo "$swww_output" >> "$DEBUG_LOG"
    debug_log "awww img: FAILED with exit code $?"
  fi

  sleep "$TRANS_SEC"
  stop_mpvpaper
  echo "$WALLPAPER_ABS" > "$CURRENT_WALLPAPER_FILE"
  echo "Image wallpaper set successfully"
  debug_log "Image wallpaper set successfully"

elif is_video "$WALLPAPER_ABS"; then
  echo "Setting video wallpaper: $WALLPAPER_ABS"
  debug_log "Setting video wallpaper: $WALLPAPER_ABS"

  if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -v error -i "$WALLPAPER_ABS" \
      -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=0x00000000" \
      -frames:v 1 "$THUMB_FILE" >/dev/null 2>&1 || true
  fi

  if command -v matugen >/dev/null 2>&1 && [[ -f "$THUMB_FILE" ]]; then
    echo "Generating color palette with matugen..."
    debug_log "Running matugen..."
    if matugen_output=$(matugen image "$THUMB_FILE" 2>&1); then
      echo "$matugen_output" >> "$DEBUG_LOG"
      echo "Color palette generated successfully"
      debug_log "matugen: success"
    else
      echo "$matugen_output" >> "$DEBUG_LOG"
      echo "matugen failed with exit code $?"
      debug_log "matugen: FAILED"
    fi
  fi

  ensure_swww
  if [[ -f "$THUMB_FILE" ]]; then
    awww img --resize crop "$THUMB_FILE" "${TRANS_OPTS[@]}"
  else
    if command -v ffmpeg >/dev/null 2>&1; then
      ffmpeg -v error -f lavfi -i color=c=#222222:s=1920x1080 -frames:v 1 -y "$THUMB_FILE" >/dev/null 2>&1 || true
      [[ -f "$THUMB_FILE" ]] && awww img --resize crop "$THUMB_FILE" "${TRANS_OPTS[@]}"
    fi
  fi

  sleep "$TRANS_SEC"
  stop_mpvpaper
  sleep 0.1

  echo "Starting mpvpaper..."
  debug_log "Starting mpvpaper with: $WALLPAPER_ABS"
  setsid nohup mpvpaper -o "$MPV_OPTS" '*' "$WALLPAPER_ABS" >"$THUMB_DIR/mpvpaper.log" 2>&1 &

  for i in {1..20}; do
    if pgrep -x mpvpaper >/dev/null 2>&1; then
      echo "$WALLPAPER_ABS" > "$CURRENT_WALLPAPER_FILE"
      echo "Video wallpaper is playing"
      debug_log "mpvpaper: started successfully"
      exit 0
    fi
    sleep 0.1
  done

  echo "mpvpaper failed to start, check $THUMB_DIR/mpvpaper.log" >&2
  debug_log "mpvpaper: FAILED to start"
  cat "$THUMB_DIR/mpvpaper.log" >> "$DEBUG_LOG" 2>/dev/null || true
  exit 1

else
  echo "Unsupported file format: $WALLPAPER_ABS" >&2
  exit 1
fi
