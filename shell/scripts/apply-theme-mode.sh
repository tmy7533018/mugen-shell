#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
[[ "$MODE" == "light" || "$MODE" == "dark" ]] || {
  echo "Usage: $0 <light|dark>" >&2
  exit 1
}

WALLP_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/mugen-shell/wallp"
CURRENT_WALLPAPER_FILE="$WALLP_DIR/current_wallpaper_path.txt"
THUMB_FILE="$WALLP_DIR/current_wallpaper_thumb.png"
LOCK="$WALLP_DIR/.wallp.lock"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mugen-shell"
THEME_MODE_FILE="$STATE_DIR/theme-mode"

# The shell writes this too, but running the script by hand must not leave the shell on the old mode.
mkdir -p "$STATE_DIR"
tmp="$THEME_MODE_FILE.$$.tmp"
printf '%s' "$MODE" > "$tmp" && mv "$tmp" "$THEME_MODE_FILE"

# The shell fires this detached and never sees the exit code, so a failure must announce itself.
notify_failure() {
  command -v notify-send >/dev/null 2>&1 && notify-send -a mugen-shell "Theme" "$1" >/dev/null 2>&1 || true
}

# The theme-mode file reaches nothing outside the shell; these are the keys portal-aware apps read.
SCHEMA=org.gnome.desktop.interface

# gsettings validates against the schema but lives in glib's bin output, which is often not on PATH.
setting_write() {
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set "$SCHEMA" "$1" "$2" 2>/dev/null && return 0
  fi
  command -v dconf >/dev/null 2>&1 && dconf write "/org/gnome/desktop/interface/$1" "'$2'" 2>/dev/null
}

setting_read() {
  if command -v gsettings >/dev/null 2>&1; then
    gsettings get "$SCHEMA" "$1" 2>/dev/null && return 0
  fi
  command -v dconf >/dev/null 2>&1 && dconf read "/org/gnome/desktop/interface/$1" 2>/dev/null
}

settings_stuck=1
apply_setting() {
  setting_write "$1" "$2" || true
  # Both writers report success against a memory backend when dconf's GIO module is missing, so read it back.
  if [[ "$(setting_read "$1")" != "'$2'" ]]; then
    echo "$1 did not stick: need a dconf backend, plus glib or dconf on PATH" >&2
    settings_stuck=0
  fi
}

apply_setting color-scheme "prefer-$MODE"
# Neither GTK3 nor plain GTK4 reads color-scheme; both need the dark stylesheet named, via gnome-themes-extra.
if [[ "$MODE" == "dark" ]]; then apply_setting gtk-theme Adwaita-dark; else apply_setting gtk-theme Adwaita; fi

if [[ "$settings_stuck" == "0" ]]; then
  notify_failure "Apps outside the shell could not be told about $MODE mode"
fi

if ! command -v matugen >/dev/null 2>&1; then
  echo "matugen not found: generated colours keep the old mode's ramp" >&2
  notify_failure "matugen is missing, so app colours did not follow $MODE mode"
  exit 0
fi

is_video() { case "${1,,}" in *.mp4|*.webm|*.mkv|*.gif) return 0;; *) return 1;; esac; }

# Mirrors change-wallpaper.sh (original for stills, thumb for video); diverging moves the accent on every toggle.
matugen_source() {
  local current=""
  [[ -f "$CURRENT_WALLPAPER_FILE" ]] && current="$(tr -d '\n' < "$CURRENT_WALLPAPER_FILE")"

  if [[ -n "$current" && -f "$current" ]] && ! is_video "$current"; then
    printf '%s' "$current"
  elif [[ -f "$THUMB_FILE" ]]; then
    printf '%s' "$THUMB_FILE"
  fi
}

run_matugen() {
  local args=(matugen image "$1" --mode "$MODE")
  # matugen >= 4 aborts headless when several source colors qualify
  if matugen image --help 2>/dev/null | grep -q -- '--prefer'; then
    args+=(--prefer saturation)
  fi
  "${args[@]}" 2>&1
}

SRC="$(matugen_source)"
[[ -n "$SRC" ]] || exit 0

mkdir -p "$WALLP_DIR"
exec 9>"$LOCK"
# change-wallpaper.sh holds this for a whole transition, so wait rather than bail.
flock -w 5 9 || exit 0

run_matugen "$SRC" >/dev/null
