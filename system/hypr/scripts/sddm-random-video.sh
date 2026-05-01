#!/usr/bin/env bash
set -euo pipefail

# Example sudoers entry:
#   YOUR_USERNAME ALL=(root) NOPASSWD: /path/to/sddm-random-video.sh

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
SRC_DIR="$USER_HOME/.local/share/mugen-shell/wallpapers/videos"
DEST_DIR="/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds"
TARGET_NAME="login.mp4"

PICK="$(find "$SRC_DIR" -type f -iname '*.mp4' -print0 | shuf -z -n 1 | xargs -0 -r echo)"
[ -n "${PICK:-}" ] || { echo "No mp4 in $SRC_DIR"; exit 1; }

mkdir -p "$DEST_DIR"
rm -f "$DEST_DIR/$TARGET_NAME"
cp -f "$PICK" "$DEST_DIR/$TARGET_NAME"
chown root:root "$DEST_DIR/$TARGET_NAME" || true
chmod 644 "$DEST_DIR/$TARGET_NAME" || true

echo "Copied SDDM background to: $DEST_DIR/$TARGET_NAME (from $PICK)"
