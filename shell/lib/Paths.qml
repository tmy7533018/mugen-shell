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
    readonly property string stateDir: {
        let xdg = Quickshell.env("XDG_STATE_HOME")
        if (!xdg || xdg === "") xdg = Quickshell.env("HOME") + "/.local/state"
        return xdg + "/mugen-shell"
    }
    readonly property string soundsDir: dataDir + "/sounds"
    readonly property string timerSoundsDir: dataDir + "/timer-sounds"

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
}
