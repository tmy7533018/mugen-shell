#!/usr/bin/env bash
# Blocks until the compositor reports the session locked — before_sleep_cmd suspends once this returns.
set -uo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/mugen-shell"
READY_FILE="$RUNTIME_DIR/lock.secure"
PID_FILE="$RUNTIME_DIR/lock.pid"
ACQUIRE_FILE="$RUNTIME_DIR/lock.acquire"
LOG_FILE="$RUNTIME_DIR/lock.log"
SHELL_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ENTRY="$SHELL_DIR/lock-shell.qml"
READY_TIMEOUT_SEC=10
# session_lock_blur is a bool, so softening the lock's blur means the global radius.
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

# 0 = secure, 1 = still not secure, 2 = the locker died first.
wait_for_ready() {
  local pid=$1 deadline=$((SECONDS + READY_TIMEOUT_SEC))
  while ((SECONDS < deadline)); do
    [[ -e "$READY_FILE" ]] && return 0
    kill -0 "$pid" 2>/dev/null || return 2
    sleep 0.05
  done
  return 1
}

if command -v qs >/dev/null 2>&1; then
  runner=qs
elif command -v quickshell >/dev/null 2>&1; then
  runner=quickshell
else
  echo "mugen-lock: neither qs nor quickshell is on PATH" >&2
  exit 1
fi

# Sleep releases its inhibitor the moment the compositor reports locked, well before a fade ends.
if [[ "${1:-}" == "--instant" ]]; then
  export MUGEN_LOCK_INSTANT=1
  shift
fi

# This returns once secure, so a detached re-entry owns the restore and covers a crash.
if [[ "${1:-}" == "--watch" ]]; then
  watched=${2:-0}
  # ps per tick would fork twice a second for the whole lock; identity is checked once.
  if pid_is_lock "$watched"; then
    tail -s 0.2 --pid="$watched" -f /dev/null 2>/dev/null \
      || while kill -0 "$watched" 2>/dev/null; do sleep 0.5; done
  fi
  # A newer lock owns the restore state; an absent pidfile means nobody replaced us.
  current=$(cat "$PID_FILE" 2>/dev/null)
  [[ -n "$current" && "$current" != "$watched" ]] && exit 0
  "$runner" -c mugen-shell ipc call bar restore >/dev/null 2>&1
  # A crash leaves session_lock_blur on, and the next lock would start blurred.
  hyprctl eval 'hl.config({ misc = { session_lock_blur = false } })' >/dev/null 2>&1
  [[ -n "${3:-}" && -n "${4:-}" ]] && set_blur "$3" "$4"
  rm -f "$PID_FILE"
  exit 0
fi

# The check and the pidfile write are one step, or two callers both spawn a locker.
exec 9>"$ACQUIRE_FILE"
flock 9

if lock_is_running; then
  existing=$(<"$PID_FILE")
  exec 9>&-
  # A live locker is not a locked session: wait for it rather than trusting the pid.
  wait_for_ready "$existing"
  case $? in
    0) exit 0 ;;
    2) echo "mugen-lock: the running lock screen exited before locking, see $LOG_FILE" >&2 ;;
    *) echo "mugen-lock: the running lock screen is not secure after ${READY_TIMEOUT_SEC}s, see $LOG_FILE" >&2 ;;
  esac
  exit 1
fi

rm -f "$READY_FILE"

# Applied here so the reduced radius is already in place on the lock's first frame.
blur_size=$(read_blur_int size)
blur_passes=$(read_blur_int passes)
if [[ "$blur_size" =~ ^[0-9]+$ && "$blur_passes" =~ ^[0-9]+$ ]]; then
  set_blur "$(scaled "$blur_size")" "$(scaled "$blur_passes")"
  export MUGEN_LOCK_BLUR_RESTORE="$blur_size $blur_passes"
fi

# The children must not inherit the acquisition fd, or it outlives this script.
"$runner" -p "$ENTRY" >>"$LOG_FILE" 2>&1 9>&- &
lock_pid=$!
echo "$lock_pid" > "$PID_FILE"

setsid "${BASH_SOURCE[0]}" --watch "$lock_pid" \
  "${blur_size:-}" "${blur_passes:-}" >>"$LOG_FILE" 2>&1 9>&- &
disown 2>/dev/null || true

exec 9>&-

wait_for_ready "$lock_pid"
case $? in
  0) exit 0 ;;
  2)
    echo "mugen-lock: the lock screen exited before locking, see $LOG_FILE" >&2
    rm -f "$PID_FILE"
    ;;
  *)
    # An orphan that never locked would keep the softened blur and stall the next attempt.
    echo "mugen-lock: not locked after ${READY_TIMEOUT_SEC}s, stopping it; see $LOG_FILE" >&2
    kill "$lock_pid" 2>/dev/null
    ;;
esac
exit 1
