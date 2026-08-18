pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: keybinds

    // Written by system/hypr/configs/keybinds.lua on every Hyprland (re)load.
    readonly property string exportFile: Paths.stateDir + "/keybinds.json"

    property var rows: []

    function _parse() {
        try {
            const parsed = JSON.parse(String(watcher.text()))
            rows = Array.isArray(parsed) ? parsed : []
        } catch (e) {
            console.warn("Keybinds: failed to parse", exportFile, e)
        }
    }

    property FileView watcher: FileView {
        path: keybinds.exportFile
        watchChanges: true
        printErrors: false

        onFileChanged: keybinds.watcher.reload()
        onLoaded: keybinds._parse()
        onLoadFailed: keybinds.rows = []
    }
}
