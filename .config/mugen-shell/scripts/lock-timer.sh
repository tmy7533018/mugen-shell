#!/usr/bin/env bash
set -euo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hypridle.conf"
MINUTES="${1:-10}"
SECONDS_VAL=$((MINUTES * 60))

if [[ ! -f "$CFG" ]]; then
    echo "hypridle.conf not found: $CFG" >&2
    exit 1
fi

python3 - "$CFG" "$SECONDS_VAL" <<'PY'
import re, sys

cfg, seconds = sys.argv[1], int(sys.argv[2])
with open(cfg) as f:
    content = f.read()

def replace(match):
    block = match.group(0)
    # The lockscreen listener triggers `hyprlock` directly (without `before_sleep`).
    if re.search(r"on-timeout\s*=\s*hyprlock\b", block):
        block = re.sub(r"timeout\s*=\s*\d+", f"timeout = {seconds}", block, count=1)
    return block

new = re.sub(r"listener\s*\{[^}]+\}", replace, content)
if new == content:
    sys.stderr.write("warning: no lockscreen listener matched; nothing changed\n")

with open(cfg, "w") as f:
    f.write(new)
PY

if command -v systemctl >/dev/null 2>&1; then
    # Only restart if hypridle is currently active. Otherwise the user has
    # idle inhibitor on (service intentionally stopped) and we'd flip it
    # back on as a side effect of a timer change.
    if systemctl --user is-active --quiet hypridle.service; then
        systemctl --user restart hypridle.service >/dev/null 2>&1 || true
    fi
fi

echo "lock timer set to ${MINUTES} min (${SECONDS_VAL}s)"
