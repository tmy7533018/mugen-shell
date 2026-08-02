import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: manager
    
    property string currentMode: "normal"
    property bool openedViaIpc: false
    property var modes: ({})
    property var settingsManager

    property real screenWidth: 1920
    readonly property real baseWidth: 1920
    readonly property real scaleFactor: screenWidth / baseWidth

    function scale(value) {
        return Math.round(value * scaleFactor)
    }

    readonly property var normalBarSize: ({
        "height": scale(settingsManager ? settingsManager.barHeight : 60),
        "leftMargin": scale(settingsManager ? settingsManager.barMarginH : 10),
        "rightMargin": scale(settingsManager ? settingsManager.barMarginH : 10),
        "topMargin": scale(settingsManager ? settingsManager.barMarginV : 6),
        "bottomMargin": scale(settingsManager ? settingsManager.barMarginV : 6)
    })
    
    property var currentBarSize: {
        if (currentMode === "normal") {
            return normalBarSize
        }
        
        var mode = modes[currentMode]
        if (mode && mode.requiredBarSize) {
            return mode.requiredBarSize
        }
        
        return normalBarSize
    }
    
    readonly property var currentModeInstance: currentMode === "normal" ? null : (modes[currentMode] || null)

    readonly property var currentSurfaceBackground: {
        var mode = currentModeInstance
        return (mode && mode.surfaceBackground) ? mode.surfaceBackground : null
    }

    function registerMode(modeName, moduleInstance) {
        if (!modeName || !moduleInstance) {
            return
        }
        
        var newModes = Object.assign({}, modes)
        newModes[modeName] = moduleInstance
        modes = newModes
    }
    
    function switchMode(newMode, viaIpc) {
        // openedViaIpc must be set before currentMode: currentModeChanged
        // listeners read it synchronously to decide whether to grab focus,
        // and a stale value breaks keybind-open ESC handling.
        if (newMode === currentMode) {
            openedViaIpc = false
            currentMode = "normal"
        } else {
            openedViaIpc = viaIpc === true
            currentMode = newMode
        }

        if (currentMode === "normal") {
            openedViaIpc = false
        }
    }
    
    function closeAllModes() {
        currentMode = "normal"
        openedViaIpc = false
    }
    
    function isMode(modeName) {
        return currentMode === modeName
    }

    // Bar.qml restarts the central autoCloseTimer when this fires.
    signal interaction()

    function bump() {
        interaction()
    }
    
    function listModes() {
    }
    
    property string ipcFile: {
        let runtimeDir = Quickshell.env("XDG_RUNTIME_DIR")
        if (!runtimeDir || runtimeDir === "") {
            runtimeDir = "/tmp"
        }
        return runtimeDir + "/mugen-shell-ipc"
    }
    // scripts/mugen-shell-ipc.sh appends a line here; that is how keybinds and
    // anything outside the shell reach this manager.
    property FileView ipcWatcher: FileView {
        path: manager.ipcFile
        watchChanges: true
        printErrors: false

        onFileChanged: ipcWatcher.reload()

        // reload() is asynchronous: text() called right after it still returns
        // the previous contents, so the read has to happen here.
        onLoaded: {
            const queued = String(ipcWatcher.text()).trim()
            if (queued === "") return
            // Cleared before dispatching so the resulting write, which comes
            // back through onFileChanged, finds nothing left to replay.
            ipcWatcher.setText("")
            for (const line of queued.split("\n")) {
                const command = line.trim()
                if (command) manager.handleIpcCommand(command)
            }
        }
    }

    function handleIpcCommand(command) {
        let parts = command.trim().split(" ")
        let cmd = parts[0]
        if (!cmd || cmd.length === 0) return

        // A corrupted IPC string would otherwise wedge the bar in a dead mode.
        const known = {
            "normal": true,
            "launcher": true,
            "wallpaper": true,
            "music": true,
            "notification": true,
            "notification-popup": true,
            "powermenu": true,
            "volume": true,
            "wifi": true,
            "bluetooth": true,
            "screenshot-gallery": true,
            "clipboard": true,
            "ai": true,
            "timer": true,
            "brightness": true,
            "weather": true
        }

        function safeSwitch(modeName) {
            if (!modeName || modeName.length === 0) return
            if (modeName === "normal") {
                closeAllModes()
                return
            }
            if (!known[modeName]) {
                console.warn("Unknown mode from IPC:", modeName)
                closeAllModes()
                return
            }
            switchMode(modeName, true)
        }

        // Non-toggling, unlike safeSwitch, so repeated volume-key presses
        // don't close the panel.
        function safeOpen(modeName) {
            if (!modeName || modeName.length === 0) return
            if (modeName === "normal") {
                closeAllModes()
                return
            }
            if (!known[modeName]) {
                console.warn("Unknown mode from IPC:", modeName)
                closeAllModes()
                return
            }
            if (isMode(modeName)) return
            switchMode(modeName, true)
        }

        switch(cmd) {
            case "open":
                if (parts.length > 1) safeOpen(parts[1])
                break
            case "switch":
            case "toggle":
                if (parts.length > 1) safeSwitch(parts[1])
                break
            case "close":
                closeAllModes()
                break
            default:
                safeSwitch(cmd)
                break
        }
    }
    
    Component.onDestruction: {
        Qt.createQmlObject(`
            import QtQuick
            import Quickshell.Io
            Process {
                command: ["rm", "-f", ${JSON.stringify(manager.ipcFile)}]
                running: true
            }
        `, manager)
    }
    
}
