pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Single entry point for every Hyprland dispatch in the shell.
// Under a Lua config Hyprland evaluates the dispatch argument as Lua, so the
// legacy string form ("exec ...", "workspace N") is rejected and the hl.dsp.*
// form is required. Routing all dispatches through here means the config-type
// switch lives in one place: on hyprlang the emitted string is byte-identical
// to what the call sites used before, and only the lua branch is new.
Item {
    id: root

    // Detected once from `hyprctl systeminfo`. Defaults to the current reality
    // (hyprlang); a dispatch fired before the probe returns just uses the
    // legacy form, which is harmless while we are still on hyprlang.
    property bool isLua: false

    function esc(s) {
        return String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")
    }

    function exec(cmd) {
        if (root.isLua) Hyprland.dispatch("hl.dsp.exec_cmd(\"" + root.esc(cmd) + "\")")
        else Hyprland.dispatch("exec " + cmd)
    }

    // argv form for the `hyprctl dispatch exec` call sites that keep a Process
    // (they rely on onExited or on Hyprland-detached spawning); same exec
    // semantics as exec() but issued through the hyprctl CLI.
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
                if (line.indexOf("configProvider:") !== -1)
                    root.isLua = line.split(":")[1].trim() === "lua"
            }
        }
    }
}
