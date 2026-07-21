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
    // A stalled reader takes external keybinds down with it.
    property bool ipcReadInFlight: false
    
    property Timer ipcPollTimer: Timer {
        interval: 500
        running: true
        repeat: true
        
        onTriggered: {
            readIpcFile()
        }
    }
    
    property Process ipcReader: Process {
        command: ["bash", "-c", 
            "if [ -f '" + manager.ipcFile + "' ] && [ -s '" + manager.ipcFile + "' ]; then " +
            "  cat '" + manager.ipcFile + "'; " +
            "else " +
            "  exit 1; " +
            "fi"
        ]
        running: false
        property string output: ""
        
        stdout: SplitParser {
            onRead: data => {
                // SplitParser drops the trailing newline; without restoring it
                // queued commands concatenate into one unparseable line.
                if (data) {
                    ipcReader.output += data + "\n"
                }
            }
        }
        
        stderr: SplitParser {
            onRead: data => {
            }
        }
        
        onExited: (exitCode) => {
            ipcReaderTimeout.stop()
            manager.ipcReadInFlight = false

            if (exitCode !== 0 && ipcReader.output.length === 0) {
                ipcReader.output = ""
                return
            }
            
            let trimmed = ipcReader.output.trim()
            if (trimmed) {
                let lines = trimmed.split('\n')
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim()
                    if (line) {
                            manager.handleIpcCommand(line)
                    }
                }
                if (trimmed.length > 0) {
                    ipcClearProcess.running = true
                }
            }
            ipcReader.output = ""
        }
    }
    
    property Process ipcClearProcess: Process {
        command: ["bash", "-c", "> '" + manager.ipcFile + "' 2>/dev/null || true"]
        running: false
    }
    
    // Without this a stalled reader wedges IPC permanently.
    property Timer ipcReaderTimeout: Timer {
        interval: 1200
        running: false
        repeat: false
        onTriggered: {
            if (ipcReader.running) {
                ipcReader.running = false
            }
            ipcReader.output = ""
            manager.ipcReadInFlight = false
        }
    }
    
    function readIpcFile() {
        if (!ipcReader.running && ipcFile && ipcFile !== "") {
            manager.ipcReadInFlight = true
            ipcReader.running = true
            ipcReaderTimeout.restart()
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
            "brightness": true
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
        Qt.createQmlObject('
            import QtQuick
            import Quickshell.Io
            Process {
                command: ["rm", "-f", "' + manager.ipcFile + '"]
                running: true
            }
        ', manager)
    }
    
}
