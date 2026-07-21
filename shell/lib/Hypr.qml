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

    // Probed once at startup like isLua above: starts false, may flip true
    // once the check returns, and is read synchronously everywhere else.
    property bool hasXdgTerminalExec: false

    Process {
        id: xdgTerminalExecProbe
        command: ["sh", "-c", "command -v xdg-terminal-exec"]
        running: true
        onExited: (code) => { if (code === 0) root.hasXdgTerminalExec = true }
    }

    // Fallback per-terminal exec flag, used only when xdg-terminal-exec isn't
    // available. Unlisted terminals default to "-e", the most common form;
    // add an entry here for one that needs something else.
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

    // Runs `cmd` inside the user's terminal, for a launcher entry whose
    // .desktop file sets Terminal=true. Prefers xdg-terminal-exec (correct for
    // any terminal, no flag table needed) and falls back to the configured
    // launcherTerminal otherwise.
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

    // Argv prefix ["term", "-e"] (or just ["term"]) for callers building their
    // own Quickshell.execDetached argv — e.g. a script that relies on
    // positional args ($1, $2...) rather than a single quoted string.
    function terminalArgvPrefix(terminalCmd) {
        let bin = String(terminalCmd || "kitty").trim().split(/\s+/)[0]
        let flag = root._terminalFlag(terminalCmd)
        return flag.length > 0 ? [bin, flag] : [bin]
    }
}
