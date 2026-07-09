pragma Singleton
import QtQuick
import Quickshell

// Single source for the shell's XDG base dirs, so the same
// XDG_DATA_HOME/HOME fallback isn't re-derived in every manager and section.
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
}
