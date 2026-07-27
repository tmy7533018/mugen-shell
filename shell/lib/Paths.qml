pragma Singleton
import QtQuick
import Quickshell

QtObject {
    readonly property string dataDir: {
        let xdg = Quickshell.env("XDG_DATA_HOME")
        if (!xdg || xdg === "") xdg = Quickshell.env("HOME") + "/.local/share"
        return xdg + "/mugen-shell"
    }
    readonly property string cacheDir: {
        let xdg = Quickshell.env("XDG_CACHE_HOME")
        if (!xdg || xdg === "") xdg = Quickshell.env("HOME") + "/.cache"
        return xdg + "/mugen-shell"
    }
    readonly property string soundsDir: dataDir + "/sounds"
    readonly property string timerSoundsDir: dataDir + "/timer-sounds"

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
    // Empty when the runtime dir is missing, which callers read as "the voice
    // daemon cannot be reached" rather than posting to a bogus path.
    readonly property string yuraCtlSocket:
        runtimeDir === "" ? "" : runtimeDir + "/mugen-shell/yura-ctl.sock"
}
