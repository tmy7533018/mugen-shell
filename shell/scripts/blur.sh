#!/usr/bin/env bash
# Writes Hyprland's blur block from settings.json: `boot` at login, `apply <json>` from the settings window.
set -euo pipefail

CFG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/hypr/configs"
BLUR_LUA="$CFG_DIR/blur.lua"
SETTINGS="${XDG_CONFIG_HOME:-${HOME}/.config}/mugen-shell/settings.json"

# The settings window hands its values over as $1 so the apply never races its own save.
blur_params() {
    python3 - "$SETTINGS" "${1:-}" <<'PY'
import json, sys
settings_file, override = sys.argv[1:3]
defaults = {"enabled": True, "size": 5, "passes": 3, "noise": 0.02, "contrast": 1.0,
            "brightness": 1.2, "vibrancy": 0.0, "xray": False, "ignoreOpacity": True}
try:
    with open(settings_file) as f:
        saved = json.load(f).get("blur")
except (OSError, ValueError, AttributeError):
    saved = None
if not isinstance(saved, dict):
    saved = {}
if override:
    saved.update(json.loads(override))
v = {k: saved.get(k, d) for k, d in defaults.items()}
print(json.dumps({"enabled": bool(v["enabled"]), "size": int(v["size"]), "passes": int(v["passes"]),
                  "ignore_opacity": bool(v["ignoreOpacity"]), "noise": float(v["noise"]),
                  "contrast": float(v["contrast"]), "brightness": float(v["brightness"]),
                  "vibrancy": float(v["vibrancy"]), "xray": bool(v["xray"]), "new_optimizations": True}))
PY
}

# Redirecting straight at the destination empties it first, so a failure would leave no blur block.
write_atomic() {
    local dest="$1"
    shift
    local tmp
    tmp=$(mktemp "$dest.XXXXXX")
    if "$@" > "$tmp"; then
        mv "$tmp" "$dest"
    else
        rm -f "$tmp"
        return 1
    fi
}

write_blur_lua() {
    write_atomic "$BLUR_LUA" python3 -c '
import json, sys
print("hl.config({ decoration = { blur = {")
for k, v in json.loads(sys.argv[1]).items():
    if isinstance(v, bool):
        v = "true" if v else "false"
    print(f"    {k} = {v},")
print("} } })")
' "$1"
}

apply() {
    local params
    params=$(blur_params "${1:-}")
    write_blur_lua "$params"
    # `hyprctl keyword` is rejected under a Lua config; a reload re-dofiles blur.lua.
    hyprctl reload >/dev/null 2>&1 || true
}

case "${1:-}" in
    boot) apply ;;
    apply) apply "${2:-}" ;;
    show) blur_params "${2:-}" ;;
    *) echo "usage: $0 boot | apply [json] | show [json]" >&2; exit 1 ;;
esac
