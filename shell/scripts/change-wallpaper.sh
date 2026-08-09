#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
THUMB_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/mugen-shell/wallp"
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

# The shell fires this detached and never sees the exit code, so a rejection must announce itself.
notify_failure() {
  command -v notify-send >/dev/null 2>&1 && notify-send -a mugen-shell "Wallpaper" "$1" >/dev/null 2>&1 || true
}

WALLPAPER="$1"
[[ -z "${WALLPAPER:-}" ]] && { echo "Usage: $0 <wallpaper-path>" >&2; exit 1; }
[[ ! -f "$WALLPAPER" ]] && {
  echo "File not found: $WALLPAPER" >&2
  notify_failure "File not found: ${WALLPAPER##*/}"
  exit 1
}

WALLPAPER_ABS="$(cd "$(dirname "$WALLPAPER")" && pwd)/$(basename "$WALLPAPER")"

THUMB_FILE="$THUMB_DIR/current_wallpaper_thumb.png"
CURRENT_WALLPAPER_FILE="$THUMB_DIR/current_wallpaper_path.txt"
MPV_SOCKET="$THUMB_DIR/mpvpaper.sock"
LOCK="$THUMB_DIR/.wallp.lock"

TRANS_DURATION=1.3

TRANS_OPTS=(
  --transition-type wave
  --transition-fps 144
  --transition-duration "$TRANS_DURATION"
  --transition-angle 30
  --transition-wave 40,40
  --transition-step 20
  --transition-bezier 0.25,0.1,0.25,1.0
)

# Hyprland draws a closing layer's fade-out on top of the stack, so it bleeds through for this long.
LAYER_FADE_SEC=0.5

# awww paces even a zero-duration set by --transition-fps, so 1 fps would stall the commit.
STILL_SET_FPS=60
STILL_COMMIT_SEC=0.35

# A mapped layer stays off screen until its first frame, so this hides mpvpaper's start-up.
MPV_WARMUP_SEC=0.4

# vaapi surfaces can't be read back, failing every mpv screenshot; auto-copy lands frames in memory.
MPV_OPTS="no-config no-audio loop cache=yes profile=low-latency \
vo=gpu-next gpu-context=wayland \
hwdec=auto-copy \
keep-open=yes \
input-ipc-server=${MPV_SOCKET} \
screenshot-format=png screenshot-high-bit-depth=no screenshot-png-compression=1"

# awww-daemon and mpvpaper are spawned with 9>&-: an inherited fd holds the flock for their whole life.
exec 9>"$LOCK"
if ! flock -n 9; then
  echo "Already running" >&2
  notify_failure "Another wallpaper change is still running"
  exit 1
fi
cleanup() {
  debug_log "Cleanup: releasing lock"
  exec 9>&-
  find "$THUMB_DIR" -name 'wprev.*.png' -mmin +5 -delete 2>/dev/null || true
  debug_log "========== EXECUTION COMPLETED =========="
}
trap cleanup EXIT

# Nix wraps these in scripts, so comm becomes ".mpvpaper-wrapped" and pgrep -x misses them.

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

run_matugen() {
  local args=(matugen image "$1")
  # matugen >= 4 aborts headless when several source colors qualify
  if matugen image --help 2>/dev/null | grep -q -- '--prefer'; then
    args+=(--prefer saturation)
  fi
  "${args[@]}" 2>&1
}

swww_ready() {
  awww query >/dev/null 2>&1
}

start_swww() {
  setsid nohup awww-daemon --format xrgb --no-cache >/dev/null 2>&1 9>&- &
}

ensure_swww() {
  debug_log "ensure_swww: checking awww-daemon status"
  if ! swww_ready; then
    debug_log "ensure_swww: awww-daemon not ready, starting..."
    pkill awww-daemon >/dev/null 2>&1 || true
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

swww_set_no_transition() {
  ensure_swww || return 1

  if awww img --help 2>/dev/null | grep -q -- '--transition-type'; then
    awww img --resize crop "$1" --transition-type none --transition-duration 0 --transition-fps "$STILL_SET_FPS" 2>/dev/null \
    || awww img --resize crop "$1" --transition-duration 0 --transition-fps "$STILL_SET_FPS"
  else
    awww img --resize crop "$1" --transition-duration 0 --transition-fps "$STILL_SET_FPS"
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

  if pgrep mpvpaper >/dev/null 2>&1; then
    pkill mpvpaper 2>/dev/null || true
    for _ in {1..10}; do
      pgrep mpvpaper >/dev/null 2>&1 || break
      sleep 0.1
    done
  fi

  if pgrep mpvpaper >/dev/null 2>&1; then
    pkill -9 mpvpaper 2>/dev/null || true
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

# Tear the video layer down while awww already holds the same frame, so the flash shows nothing new.
if pgrep mpvpaper >/dev/null 2>&1; then
  echo "Capturing current video frame for smooth transition..."

  prev_png="$(freeze_and_shot_current_frame 2>/dev/null || true)"
  [[ -z "${prev_png:-}" ]] && prev_png="$(grab_current_video_frame_via_ipc 2>/dev/null || true)"

  if [[ -n "${prev_png:-}" && -s "$prev_png" ]]; then
    ensure_swww
    if swww_set_no_transition "$prev_png"; then
      sleep "$STILL_COMMIT_SEC"
      echo "Current frame captured and displayed"
    fi
    rm -f "$prev_png"
  fi

  stop_mpvpaper
  sleep "$LAYER_FADE_SEC"
fi

if is_image "$WALLPAPER_ABS"; then
  echo "Setting image wallpaper: $WALLPAPER_ABS"
  debug_log "Setting image wallpaper: $WALLPAPER_ABS"

  if command -v matugen >/dev/null 2>&1; then
    echo "Generating color palette with matugen..."
    debug_log "Running matugen..."
    if matugen_output=$(run_matugen "$WALLPAPER_ABS"); then
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
    if matugen_output=$(run_matugen "$THUMB_FILE"); then
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

  sleep "$(awk "BEGIN { d = $TRANS_DURATION - $MPV_WARMUP_SEC; print (d > 0) ? d : 0 }")"

  echo "Starting mpvpaper..."
  debug_log "Starting mpvpaper with: $WALLPAPER_ABS"
  setsid nohup mpvpaper -o "$MPV_OPTS" '*' "$WALLPAPER_ABS" >"$THUMB_DIR/mpvpaper.log" 2>&1 9>&- &

  for i in {1..20}; do
    if pgrep mpvpaper >/dev/null 2>&1; then
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
  notify_failure "Unsupported file format: ${WALLPAPER_ABS##*/}"
  exit 1
fi
