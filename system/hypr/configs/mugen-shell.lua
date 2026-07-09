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
    hl.exec_cmd("sh -lc 'sleep 1; ~/.config/hypr/scripts/wallp-restore.sh'")
    hl.exec_cmd("quickshell -c mugen-shell")
    hl.exec_cmd("quickshell -p ~/.config/quickshell/mugen-shell/yura-shell.qml")
    hl.exec_cmd("~/.config/quickshell/mugen-shell/scripts/blur-preset.sh boot")
    hl.exec_cmd("~/.config/hypr/scripts/hypridle-auto-start.sh")
    hl.exec_cmd("wl-paste --type text  --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
end)
