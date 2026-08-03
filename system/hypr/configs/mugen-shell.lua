-- mugen-shell autostart for a Hyprland Lua config — the Lua counterpart of
-- mugen-shell.conf. If you already have your own hyprland.lua, adopt just this
-- snippet by adding near the top:
--
--     dofile(os.getenv("HOME") .. "/.config/hypr/configs/mugen-shell.lua")
--
-- (equivalent to `source = ~/.config/hypr/configs/mugen-shell.conf` on hyprlang.)

-- Lets the shell's Hypr dispatch facade detect the Lua config synchronously,
-- so a dispatch fired at shell startup picks the hl.dsp.* syntax right away.
hl.env("HYPR_CONFIG_LUA", "1")

hl.on("hyprland.start", function()
    -- Hand the compositor's address to systemd, then pull up the session
    -- target: graphical-session.target refuses a manual start, so user
    -- services bound to it (yura-voice) only run once
    -- something binds to it on their behalf.
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("systemctl --user start mugen-shell-session.target")
    hl.exec_cmd("sh -lc 'sleep 1; ~/.config/hypr/scripts/wallp-restore.sh'")
    -- fcitx's Wayland frontend only reaches a surface Qt has activated, and a
    -- layer shell never becomes the application's focus window, so text input
    -- here has to go over fcitx's DBus frontend instead. Scoped to these two
    -- processes: exporting QT_IM_MODULE session-wide is what fcitx5 warns
    -- about, and every other app is fine on the Wayland frontend.
    -- Qt picks no platform theme under XDG_CURRENT_DESKTOP=Hyprland, and
    -- without one its FileDialog is self-drawn rather than the desktop's.
    hl.exec_cmd("env QT_IM_MODULE=fcitx QT_QPA_PLATFORMTHEME=xdgdesktopportal quickshell -c mugen-shell")
    hl.exec_cmd("env QT_IM_MODULE=fcitx QT_QPA_PLATFORMTHEME=xdgdesktopportal quickshell -p ~/.config/quickshell/mugen-shell/yura-shell.qml")
    hl.exec_cmd("~/.config/quickshell/mugen-shell/scripts/blur-preset.sh boot")
    hl.exec_cmd("~/.config/hypr/scripts/hypridle-auto-start.sh")
    hl.exec_cmd("wl-paste --type text  --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
end)
