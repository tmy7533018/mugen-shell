pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Every Hyprland dispatch must route through here: under a Lua config Hyprland evaluates
// the argument as Lua, so the legacy string form is rejected and hl.dsp.* is required.
Item {
    id: root

    // Only children Hyprland spawns inherit this; the bar comes from systemd, so the probe is what settles it.
    property bool isLua: Quickshell.env("HYPR_CONFIG_LUA") === "1"
    property bool probed: false
    readonly property bool settled: root.isLua || root.probed
    property var deferred: []

    function _run(dispatch) {
        if (root.settled) dispatch()
        else root.deferred.push(dispatch)
    }

    function _settle() {
        root.probed = true
        const queued = root.deferred
        root.deferred = []
        for (const dispatch of queued) dispatch()
    }

    function esc(s) {
        return String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")
    }

    function exec(cmd) {
        root._run(() => root.isLua
            ? Hyprland.dispatch("hl.dsp.exec_cmd(\"" + root.esc(cmd) + "\")")
            : Hyprland.dispatch("exec " + cmd))
    }

    // Callers keep their own Process (onExited, detached spawning), so this cannot defer; both are user-triggered long after settling.
    function execArgv(cmd) {
        if (root.isLua) return ["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"" + root.esc(cmd) + "\")"]
        return ["hyprctl", "dispatch", "exec", cmd]
    }

    function workspace(id) {
        root._run(() => root.isLua
            ? Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })")
            : Hyprland.dispatch("workspace " + id))
    }

    function exit() {
        root._run(() => root.isLua
            ? Hyprland.dispatch("hl.dsp.exit()")
            : Hyprland.dispatch("exit"))
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
        onExited: root._settle()
    }

    // ai/internal/hypr/focus.go gives the same probe 3s; past that Hyprland is wedged and queueing helps nobody.
    Timer {
        interval: 3000
        running: !root.settled
        onTriggered: root._settle()
    }

    // Probed once at startup like isLua: starts false and only ever upgrades to true.
    property bool hasXdgTerminalExec: false

    Process {
        id: xdgTerminalExecProbe
        command: ["sh", "-c", "command -v xdg-terminal-exec"]
        running: true
        onExited: (code) => { if (code === 0) root.hasXdgTerminalExec = true }
    }

    // Only used when xdg-terminal-exec is missing; unlisted terminals default to "-e".
    readonly property var _terminalExecFlags: ({
        "kitty": "",
        "foot": "",
        "wezterm": "start --",
        "gnome-terminal": "--",
        "konsole": "-e",
        "xterm": "-e",
        "alacritty": "-e"
    })

    function _terminalFlag(terminalCmd) {
        let bin = String(terminalCmd || "kitty").trim().split(/\s+/)[0]
        return root._terminalExecFlags.hasOwnProperty(bin) ? root._terminalExecFlags[bin] : "-e"
    }

    // Runs cmd in the user's terminal for a Terminal=true .desktop entry; prefers xdg-terminal-exec.
    function execInTerminal(terminalCmd, cmd) {
        let quoted = "'" + String(cmd).replace(/'/g, "'\\''") + "'"
        if (root.hasXdgTerminalExec) {
            root.exec("xdg-terminal-exec sh -c " + quoted)
            return
        }
        let bin = String(terminalCmd || "kitty").trim().split(/\s+/)[0]
        let flag = root._terminalFlag(terminalCmd)
        root.exec(flag.length > 0 ? (bin + " " + flag + " sh -c " + quoted) : (bin + " sh -c " + quoted))
    }

    // Argv prefix for callers building their own execDetached argv with positional args.
    function terminalArgvPrefix(terminalCmd) {
        let bin = String(terminalCmd || "kitty").trim().split(/\s+/)[0]
        let flag = root._terminalFlag(terminalCmd)
        return flag.length > 0 ? [bin].concat(flag.split(/\s+/)) : [bin]
    }
}
