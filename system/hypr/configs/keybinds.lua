-- Keybinds, dofile'd by hyprland.lua. Rebind by hand-editing keybind-overrides.lua.

local HOME = os.getenv("HOME")

-- Loaded before the app choices below so keybind-overrides.lua's `apps` table can win.
local overridesFile = {}
do
    local ok, loaded = pcall(dofile, HOME .. "/.config/hypr/configs/keybind-overrides.lua")
    if ok and type(loaded) == "table" then overridesFile = loaded end
end
local appOverrides = type(overridesFile.apps) == "table" and overridesFile.apps or {}
local keyOverrides = type(overridesFile.keys) == "table" and overridesFile.keys or {}

local mainMod     = "SUPER"
local terminal    = appOverrides.terminal or "kitty"
local fileManager = appOverrides.fileManager or "thunar"
local browser     = appOverrides.browser or "firefox"

local shellDir = HOME .. "/.config/quickshell/mugen-shell"
local scripts  = shellDir .. "/scripts"

local function ipc(args)
    return hl.dsp.exec_cmd(scripts .. "/mugen-shell-ipc.sh " .. args)
end

local function script(name, args)
    return hl.dsp.exec_cmd(scripts .. "/" .. name .. (args and (" " .. args) or ""))
end

local function cycle(prev)
    local opts = prev and "({ prev = true })" or "()"
    return hl.dsp.exec_cmd(
        "hyprctl dispatch 'hl.dsp.window.cycle_next" .. opts .. "' && " ..
        "hyprctl dispatch 'hl.dsp.window.bring_to_top()'")
end

local function volumeKey(cmd)
    return hl.dsp.exec_cmd(cmd .. " && " .. scripts .. "/mugen-shell-ipc.sh open volume")
end

local function brightnessKey(cmd)
    return hl.dsp.exec_cmd(cmd .. " && " .. scripts .. "/mugen-shell-ipc.sh open brightness")
end

local dirOf   = { h = "left", j = "down", k = "up", l = "right" }
local vimKeys = { "h", "j", "k", "l" }
local wsNums  = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }

-- `each` binds one row many times; keybind-overrides.lua can't target a family by id, only a plain bind.
local binds = {
    { id = "app.terminal", cat = "apps", desc = "Terminal",
      keys = mainMod .. " + RETURN", action = hl.dsp.exec_cmd(terminal) },
    { id = "app.browser", cat = "apps", desc = "Browser",
      keys = mainMod .. " + B", action = hl.dsp.exec_cmd(browser) },
    { id = "app.files", cat = "apps", desc = "File manager",
      keys = mainMod .. " + N", action = hl.dsp.exec_cmd(fileManager) },

    { id = "panel.launcher", cat = "shell", desc = "App launcher",
      keys = mainMod .. " + R", action = ipc("launcher") },
    { id = "panel.wallpaper", cat = "shell", desc = "Wallpaper picker",
      keys = mainMod .. " + W", action = ipc("wallpaper") },
    { id = "panel.music", cat = "shell", desc = "Music player",
      keys = mainMod .. " + M", action = ipc("music") },
    { id = "panel.volume", cat = "shell", desc = "Volume panel",
      keys = mainMod .. " + U", action = ipc("volume") },
    { id = "panel.clipboard", cat = "shell", desc = "Clipboard history",
      keys = mainMod .. " + V", action = ipc("clipboard") },
    { id = "panel.notification", cat = "shell", desc = "Notification center",
      keys = mainMod .. " + T", action = ipc("notification") },
    { id = "panel.ai", cat = "shell", desc = "Yura (bar)",
      keys = mainMod .. " + Y", action = ipc("ai") },
    { id = "panel.screenshots", cat = "shell", desc = "Screenshot gallery",
      keys = mainMod .. " + S", action = ipc("screenshot-gallery") },
    { id = "panel.wifi", cat = "shell", desc = "Wi-Fi panel",
      keys = mainMod .. " + I", action = ipc("wifi") },
    { id = "panel.bluetooth", cat = "shell", desc = "Bluetooth panel",
      keys = mainMod .. " + E", action = ipc("bluetooth") },
    { id = "panel.powermenu", cat = "shell", desc = "Power menu",
      keys = mainMod .. " + P", action = ipc("powermenu") },
    { id = "panel.weather", cat = "shell", desc = "Weather panel",
      keys = mainMod .. " + SHIFT + W", action = ipc("weather") },
    { id = "panel.timer", cat = "shell", desc = "Timer",
      keys = mainMod .. " + SHIFT + T", action = ipc("timer") },
    { id = "panel.calendar", cat = "shell", desc = "Calendar",
      keys = mainMod .. " + C", action = script("toggle-calendar.sh") },
    { id = "panel.settings", cat = "shell", desc = "Settings",
      keys = mainMod .. " + comma", action = script("toggle-settings.sh") },
    { id = "panel.keybinds", cat = "shell", desc = "Keyboard shortcuts",
      keys = mainMod .. " + slash", action = script("toggle-settings.sh", "keybinds") },
    { id = "panel.yura", cat = "shell", desc = "Yura (corner pop-up)",
      keys = mainMod .. " + SHIFT + Y",
      action = hl.dsp.exec_cmd("qs -p " .. shellDir .. "/yura-shell.qml ipc call yura toggle") },
    { id = "shell.idleInhibit", cat = "shell", desc = "Toggle idle inhibitor",
      keys = mainMod .. " + SHIFT + I", action = script("idle_inhibitor.sh") },

    { id = "win.close", cat = "window", desc = "Close active window",
      keys = mainMod .. " + backspace", action = hl.dsp.window.close() },
    { id = "win.fullscreen", cat = "window", desc = "Fullscreen",
      keys = mainMod .. " + F", action = hl.dsp.window.fullscreen() },
    { id = "win.float", cat = "window", desc = "Toggle floating",
      keys = mainMod .. " + SHIFT + SPACE", action = hl.dsp.window.float({ action = "toggle" }) },
    { id = "win.cycleNext", cat = "window", desc = "Cycle to next window",
      keys = mainMod .. " + Tab", action = cycle(false) },
    { id = "win.cyclePrev", cat = "window", desc = "Cycle to previous window",
      keys = mainMod .. " + SHIFT + Tab", action = cycle(true) },
    { id = "win.focus", cat = "window", desc = "Move focus between windows",
      each = vimKeys, display = mainMod .. " + h/j/k/l",
      keys   = function(d) return mainMod .. " + " .. d end,
      action = function(d) return hl.dsp.focus({ direction = dirOf[d] }) end },
    { id = "win.move", cat = "window", desc = "Move window in the tile",
      each = vimKeys, display = mainMod .. " + SHIFT + h/j/k/l",
      keys   = function(d) return mainMod .. " + SHIFT + " .. d end,
      action = function(d) return hl.dsp.window.move({ direction = dirOf[d] }) end },
    { id = "win.drag", cat = "window", desc = "Move window with the mouse",
      keys = mainMod .. " + mouse:272", display = mainMod .. " + drag",
      action = hl.dsp.window.drag(), opts = { mouse = true } },
    { id = "win.resize", cat = "window", desc = "Resize window with the mouse",
      keys = mainMod .. " + mouse:273", display = mainMod .. " + right-drag",
      action = hl.dsp.window.resize(), opts = { mouse = true } },
    { id = "win.floatDrag", cat = "window", desc = "Toggle floating by dragging",
      keys = mainMod .. " + SHIFT + mouse:272", display = mainMod .. " + SHIFT + drag",
      action = hl.dsp.window.float({ action = "toggle" }), opts = { mouse = true } },

    { id = "ws.switch", cat = "workspace", desc = "Switch workspace",
      each = wsNums, display = mainMod .. " + 1…10",
      keys   = function(i) return mainMod .. " + " .. (i == 10 and 0 or i) end,
      action = function(i) return hl.dsp.focus({ workspace = tostring(i) }) end },
    { id = "ws.moveSilent", cat = "workspace", desc = "Move window to workspace (stay here)",
      each = wsNums, display = mainMod .. " + SHIFT + 1…10",
      keys   = function(i) return mainMod .. " + SHIFT + " .. (i == 10 and 0 or i) end,
      action = function(i) return hl.dsp.window.move({ workspace = tostring(i), follow = false }) end },
    { id = "ws.moveFollow", cat = "workspace", desc = "Move window to workspace and follow",
      each = wsNums, display = "ALT + SHIFT + 1…10",
      keys   = function(i) return "ALT + SHIFT + " .. (i == 10 and 0 or i) end,
      action = function(i) return hl.dsp.window.move({ workspace = tostring(i), follow = true }) end },
    { id = "ws.wheel", cat = "workspace", desc = "Switch workspace by scrolling",
      each = { "mouse_down", "mouse_up" }, display = mainMod .. " + wheel",
      keys   = function(k) return mainMod .. " + " .. k end,
      action = function(k) return hl.dsp.focus({ workspace = k == "mouse_down" and "e+1" or "e-1" }) end },
    { id = "ws.special", cat = "workspace", desc = "Toggle special workspace (magic)",
      keys = mainMod .. " + SHIFT + S", action = hl.dsp.workspace.toggle_special("magic") },

    { id = "media.playPause", cat = "media", desc = "Play / Pause",
      keys = "code:172", display = "Play/Pause key", action = hl.dsp.exec_cmd("playerctl play-pause") },
    { id = "media.next", cat = "media", desc = "Next track",
      keys = "code:171", display = "Next key", action = hl.dsp.exec_cmd("playerctl next") },
    { id = "media.prev", cat = "media", desc = "Previous track",
      keys = "code:173", display = "Previous key", action = hl.dsp.exec_cmd("playerctl previous") },
    -- Volume keys explicitly open the panel: change detection mis-fires on a sink swap.
    { id = "media.volumeDown", cat = "media", desc = "Volume down (2%)",
      keys = "code:122", display = "Volume Down key",
      action = volumeKey("pactl set-sink-volume @DEFAULT_SINK@ -2%") },
    { id = "media.volumeUp", cat = "media", desc = "Volume up (2%)",
      keys = "code:123", display = "Volume Up key",
      action = volumeKey("pactl set-sink-volume @DEFAULT_SINK@ +2%") },
    { id = "media.mute", cat = "media", desc = "Mute output",
      keys = "code:121", display = "Mute key",
      action = volumeKey("pactl set-sink-mute @DEFAULT_SINK@ toggle") },
    { id = "media.micMute", cat = "media", desc = "Mute microphone",
      keys = "XF86AudioMicMute", display = "Mic Mute key",
      action = volumeKey("pactl set-source-mute @DEFAULT_SOURCE@ toggle") },
    { id = "media.brightnessUp", cat = "media", desc = "Brightness up (5%)",
      keys = "XF86MonBrightnessUp", display = "Brightness Up key",
      action = brightnessKey("brightnessctl --class backlight set +5%") },
    { id = "media.brightnessDown", cat = "media", desc = "Brightness down (5%)",
      keys = "XF86MonBrightnessDown", display = "Brightness Down key",
      action = brightnessKey("brightnessctl --class backlight set 5%-") },

    { id = "sys.reload", cat = "system", desc = "Reload Hyprland config",
      keys = mainMod .. " + SHIFT + R", action = hl.dsp.exec_cmd("hyprctl reload") },
    { id = "sys.screenshot", cat = "system", desc = "Take screenshot",
      each = { mainMod .. " + F12", "Print" }, display = mainMod .. " + F12 / Print",
      keys   = function(k) return k end,
      action = function() return script("take-screenshot.sh") end },
}

-- b.keys/b.display stay the shipped default so Settings -> Keyboard can flag an overridden row.
for _, b in ipairs(binds) do
    if b.each then
        for _, v in ipairs(b.each) do
            hl.bind(b.keys(v), b.action(v), b.opts)
        end
    else
        local effectiveKeys = b.keys
        if type(keyOverrides[b.id]) == "string" then effectiveKeys = keyOverrides[b.id] end
        hl.bind(effectiveKeys, b.action, b.opts)
        b.effectiveKeys = effectiveKeys
    end
end

-- Exported so Settings -> Keyboard reads what is actually bound, not a copy that can drift.
local function jsonString(v)
    return '"' .. tostring(v):gsub('[\\"]', '\\%0'):gsub('\n', '\\n') .. '"'
end

local function exportBinds()
    local stateDir = (os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")) .. "/mugen-shell"
    pcall(os.execute, "mkdir -p '" .. stateDir .. "'")

    local f = io.open(stateDir .. "/keybinds.json", "w")
    if not f then return end

    local rows = {}
    for _, b in ipairs(binds) do
        local overridden = not b.each and b.effectiveKeys ~= b.keys
        -- An override has no shipped display label, so show the raw chord from keybind-overrides.lua.
        local shown = b.each and (b.display or "") or (overridden and b.effectiveKeys or (b.display or b.keys))
        rows[#rows + 1] = table.concat({
            "  {",
            '"id": ' .. jsonString(b.id) .. ", ",
            '"keys": ' .. jsonString(shown) .. ", ",
            '"desc": ' .. jsonString(b.desc) .. ", ",
            '"cat": ' .. jsonString(b.cat) .. ", ",
            '"fixed": ' .. (b.each and "true" or "false") .. ", ",
            '"overridden": ' .. (overridden and "true" or "false"),
            "}",
        })
    end
    f:write("[\n" .. table.concat(rows, ",\n") .. "\n]\n")
    f:close()
end

exportBinds()
