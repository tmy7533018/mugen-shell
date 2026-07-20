pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Every Hyprland dispatch in the shell must route through here. Under a Lua
// config Hyprland evaluates the dispatch argument as Lua, so the legacy string
// form ("exec ...", "workspace N") is rejected and hl.dsp.* is required.
Item {
    id: root

    // Read synchronously from the env var so startup dispatches, which fire
    // before the async probe returns, still pick the right syntax. The probe
    // is a backstop for a Lua config that omits the var, so it only ever
    // upgrades to true.
    property bool isLua: Quickshell.env("HYPR_CONFIG_LUA") === "1"

    function esc(s) {
        return String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")
    }

    function exec(cmd) {
        if (root.isLua) Hyprland.dispatch("hl.dsp.exec_cmd(\"" + root.esc(cmd) + "\")")
        else Hyprland.dispatch("exec " + cmd)
    }

    // For call sites that keep a Process because they need onExited or
    // Hyprland-detached spawning.
    function execArgv(cmd) {
        if (root.isLua) return ["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"" + root.esc(cmd) + "\")"]
        return ["hyprctl", "dispatch", "exec", cmd]
    }

    function workspace(id) {
        if (root.isLua) Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })")
        else Hyprland.dispatch("workspace " + id)
    }

    function exit() {
        if (root.isLua) Hyprland.dispatch("hl.dsp.exit()")
        else Hyprland.dispatch("exit")
    }

    Process {
        id: probe
        command: ["hyprctl", "systeminfo"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("configProvider:") !== -1 && line.split(":")[1].trim() === "lua")
                    root.isLua = true
            }
        }
    }
}
