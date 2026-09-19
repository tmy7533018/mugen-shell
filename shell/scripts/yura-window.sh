#!/usr/bin/env bash
# Launches the Yura window; Hyprland's exec-once and install.sh both go through here.

# A layer shell never becomes Qt's focus window, so fcitx has to be reached over its DBus frontend.
export QT_IM_MODULE=fcitx
# Under XDG_CURRENT_DESKTOP=Hyprland Qt picks no platform theme and self-draws its FileDialog.
export QT_QPA_PLATFORMTHEME=xdgdesktopportal
exec quickshell -p "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/mugen-shell/yura-shell.qml"
