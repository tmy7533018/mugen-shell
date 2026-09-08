#!/usr/bin/env bash
# Usage: qs-ipc.sh <target> <function> [args...]
# Distro packages install the binary as `qs` or as `quickshell`, and the yura/bar
# bridge dies silently on the systems that only have the latter.
set -uo pipefail

if command -v qs >/dev/null 2>&1; then
  runner=qs
elif command -v quickshell >/dev/null 2>&1; then
  runner=quickshell
else
  echo "qs-ipc: neither qs nor quickshell is on PATH" >&2
  exit 1
fi

exec "$runner" -c mugen-shell ipc call "$@"
