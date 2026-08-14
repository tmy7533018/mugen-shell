-- Keybinds, dofile'd by hyprland.lua.

local mainMod     = "SUPER"
local terminal    = "kitty"
local fileManager = "thunar"
local browser     = "firefox"

hl.bind(mainMod .. " + RETURN",    hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + backspace", hl.dsp.window.close())
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd(browser))

hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))

hl.bind(mainMod .. " + Tab",         hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.window.cycle_next()' && hyprctl dispatch 'hl.dsp.window.bring_to_top()'"))
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.window.cycle_next({ prev = true })' && hyprctl dispatch 'hl.dsp.window.bring_to_top()'"))

for i = 1, 10 do
    local key = i == 10 and 0 or i
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = tostring(i) }))
    hl.bind("ALT + SHIFT + " .. key,         hl.dsp.window.move({ workspace = tostring(i), follow = true }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i), follow = false }))
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume keys — explicitly open the volume panel (change-detection mis-fires on sink swap)
hl.bind("code:122", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -2% && ~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh open volume"))
hl.bind("code:123", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +2% && ~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh open volume"))
hl.bind("code:121", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle && ~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh open volume"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle && ~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh open volume"))

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl --class backlight set +5% && ~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh open brightness"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl --class backlight set 5%- && ~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh open brightness"))

hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())

hl.bind(mainMod .. " + F12", hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/take-screenshot.sh"))
hl.bind("Print",             hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/take-screenshot.sh"))

hl.bind(mainMod .. " + SHIFT + h", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + j", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + k", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + l", hl.dsp.window.move({ direction = "right" }))

hl.bind(mainMod .. " + SHIFT + mouse:272", hl.dsp.window.float({ action = "toggle" }), { mouse = true })
hl.bind(mainMod .. " + SHIFT + SPACE",     hl.dsp.window.float({ action = "toggle" }))

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.workspace.toggle_special("magic"))

hl.bind("code:172", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("code:171", hl.dsp.exec_cmd("playerctl next"))
hl.bind("code:173", hl.dsp.exec_cmd("playerctl previous"))

hl.bind(mainMod .. " + R",         hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh launcher"))
hl.bind(mainMod .. " + W",         hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh wallpaper"))
hl.bind(mainMod .. " + P",         hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh powermenu"))
hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh music"))
hl.bind(mainMod .. " + T",         hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh notification"))
hl.bind(mainMod .. " + Y",         hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh ai"))
hl.bind(mainMod .. " + V",         hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh clipboard"))
hl.bind(mainMod .. " + C",         hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/toggle-calendar.sh"))
hl.bind(mainMod .. " + S",         hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh screenshot-gallery"))
hl.bind(mainMod .. " + U",         hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh volume"))
hl.bind(mainMod .. " + I",         hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh wifi"))
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh bluetooth"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh weather"))
hl.bind(mainMod .. " + comma",     hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/toggle-settings.sh"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/mugen-shell-ipc.sh timer"))
hl.bind(mainMod .. " + SHIFT + Y", hl.dsp.exec_cmd("qs -p ~/.config/quickshell/mugen-shell/yura-shell.qml ipc call yura toggle"))
hl.bind(mainMod .. " + slash",     hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/toggle-shortcuts.sh"))

-- `global`, not a plain bind: only it reports the release to GlobalShortcut.
hl.bind(mainMod .. " + Z", hl.dsp.global("mugen-shell:ptt"))

hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd("~/.config/quickshell/mugen-shell/scripts/idle_inhibitor.sh"))
