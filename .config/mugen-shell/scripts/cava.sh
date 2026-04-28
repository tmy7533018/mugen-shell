#!/usr/bin/env bash
set -euo pipefail

COLOR_CONFIG="${HOME}/.config/cava/colors.conf"
TMP_CONFIG="$(mktemp)"

cleanup() {
    rm -f "$TMP_CONFIG"
}
trap cleanup EXIT

cat <<'EOF' > "$TMP_CONFIG"
[general]
bars = 16
framerate = 20

[input]
method = pipewire
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 32
frame_delimiter = 10
channels = mono
EOF

if [[ -f "$COLOR_CONFIG" ]]; then
    cat "$COLOR_CONFIG" >> "$TMP_CONFIG"
fi

cava -p "$TMP_CONFIG" | while read -r line; do
    if [[ $line =~ ^[0-9[:space:]]+$ ]]; then
        echo "$line"
    fi
done
