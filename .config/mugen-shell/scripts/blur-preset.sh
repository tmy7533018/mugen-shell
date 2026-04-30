#!/usr/bin/env bash
set -euo pipefail

CFG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/hypr/configs"
PRESETS="$CFG_DIR/blur-presets.json"
STATE="$CFG_DIR/.blur-current"
DEFAULT_PRESET="glow blur"

list_presets() {
    python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    for p in json.load(f):
        print(p["name"])
' "$PRESETS"
}

get_current() {
    [[ -f "$STATE" ]] && cat "$STATE" || echo ""
}

apply_live() {
    local name="$1"
    while IFS=$'\t' read -r key val; do
        hyprctl keyword "$key" "$val" >/dev/null 2>&1 || true
    done < <(python3 -c '
import json, sys
name = sys.argv[2]
with open(sys.argv[1]) as f:
    presets = json.load(f)
for p in presets:
    if p["name"] == name:
        for k, v in p["params"].items():
            if isinstance(v, bool):
                v = "true" if v else "false"
            print(f"decoration:blur:{k}\t{v}")
        sys.exit(0)
sys.stderr.write(f"preset not found: {name}\n")
sys.exit(1)
' "$PRESETS" "$name")
    echo "$name" > "$STATE"
}

pick() {
    if [[ $# -gt 0 ]]; then echo "$1"; return; fi
    mapfile -t P < <(list_presets)
    ((${#P[@]})) || { echo "no presets in $PRESETS" >&2; exit 1; }

    if command -v rofi >/dev/null; then
        sel="$(printf '%s\n' "${P[@]}" | rofi -dmenu -p 'Blur preset')"
    elif command -v fzf >/dev/null; then
        sel="$(printf '%s\n' "${P[@]}" | fzf --prompt='Blur preset> ')"
    else
        echo "available presets:"; nl -ba <(printf '%s\n' "${P[@]}")
        read -rp 'number: ' n; sel="${P[$((n-1))]:-}"
    fi
    [[ -n "${sel:-}" ]] || { echo "no selection" >&2; exit 1; }
    echo "$sel"
}

boot() {
    local name
    name="$(get_current)"
    [[ -z "$name" ]] && name="$DEFAULT_PRESET"
    apply_live "$name"
    echo "restored preset: $name"
}

main() {
    case "${1:-}" in
        list) list_presets; exit 0 ;;
        current) get_current; exit 0 ;;
        boot) boot; exit 0 ;;
    esac

    local sel
    sel="$(pick "$@")"
    apply_live "$sel"
    echo "active preset: $sel"
}

main "$@"
