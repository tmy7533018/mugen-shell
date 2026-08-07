#!/usr/bin/env bash
# Blocks until the compositor reports the session locked: hypridle's
# before_sleep_cmd suspends as soon as this returns.
set -uo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/mugen-shell"
READY_FILE="$RUNTIME_DIR/lock.secure"
PID_FILE="$RUNTIME_DIR/lock.pid"
LOG_FILE="$RUNTIME_DIR/lock.log"
SHELL_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ENTRY="$SHELL_DIR/lock-shell.qml"
READY_TIMEOUT_SEC=10
# misc:session_lock_blur is a bool, so the only way to soften the lock's blur is
# the global radius. Everything else is behind the lock face while it applies.
BLUR_SCALE="${MUGEN_LOCK_BLUR:-0.5}"

read_blur_int() {
  hyprctl getoption "decoration:blur:$1" 2>/dev/null | awk '/^int:/{print $2}'
}

set_blur() {
  hyprctl eval \
    "hl.config({ decoration = { blur = { size = $1, passes = $2 } } })" \
    >/dev/null 2>&1
}

scaled() {
  awk -v v="$1" -v k="$BLUR_SCALE" 'BEGIN { n = int(v * k + 0.5); print (n < 1 ? 1 : n) }'
}

mkdir -p "$RUNTIME_DIR"

# `pgrep -f <pattern>` would match the shell running it.
pid_is_lock() {
  ps -p "$1" -o args= 2>/dev/null | grep -q "lock-shell.qml"
}

lock_is_running() {
  local pid
  [[ -f "$PID_FILE" ]] || return 1
  pid=$(<"$PID_FILE")
  [[ -n "$pid" ]] || return 1
  pid_is_lock "$pid"
}

if command -v qs >/dev/null 2>&1; then
  runner=qs
elif command -v quickshell >/dev/null 2>&1; then
  runner=quickshell
else
  echo "mugen-lock: neither qs nor quickshell is on PATH" >&2
  exit 1
fi

# This script returns once the session is secure, so restoring the bar cannot
# be its job. A detached re-entry outlives it and covers a crash too.
if [[ "${1:-}" == "--watch" ]]; then
  watched=${2:-0}
  while pid_is_lock "$watched"; do
    sleep 0.5
  done
  "$runner" -c mugen-shell ipc call bar restore >/dev/null 2>&1
  # A crash leaves session_lock_blur on, and the next lock would start blurred.
  hyprctl eval 'hl.config({ misc = { session_lock_blur = false } })' >/dev/null 2>&1
  [[ -n "${3:-}" && -n "${4:-}" ]] && set_blur "$3" "$4"
  rm -f "$PID_FILE"
  exit 0
fi

if lock_is_running; then
  exit 0
fi

rm -f "$READY_FILE"

# Applied here rather than from QML so the reduced radius is already in place
# on the frame the lock surface first appears.
blur_size=$(read_blur_int size)
blur_passes=$(read_blur_int passes)
if [[ "$blur_size" =~ ^[0-9]+$ && "$blur_passes" =~ ^[0-9]+$ ]]; then
  set_blur "$(scaled "$blur_size")" "$(scaled "$blur_passes")"
  export MUGEN_LOCK_BLUR_RESTORE="$blur_size $blur_passes"
fi

"$runner" -p "$ENTRY" >>"$LOG_FILE" 2>&1 &
lock_pid=$!
echo "$lock_pid" > "$PID_FILE"

setsid "${BASH_SOURCE[0]}" --watch "$lock_pid" \
  "${blur_size:-}" "${blur_passes:-}" >>"$LOG_FILE" 2>&1 &
disown 2>/dev/null || true

deadline=$((SECONDS + READY_TIMEOUT_SEC))
while ((SECONDS < deadline)); do
  [[ -e "$READY_FILE" ]] && exit 0
  if ! kill -0 "$lock_pid" 2>/dev/null; then
    echo "mugen-lock: the lock screen exited before locking, see $LOG_FILE" >&2
    rm -f "$PID_FILE"
    exit 1
  fi
  sleep 0.05
done

echo "mugen-lock: not locked after ${READY_TIMEOUT_SEC}s, see $LOG_FILE" >&2
exit 1
