import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: manager
    
    property string currentMode: "normal"
    property bool openedViaIpc: false
    property var modes: ({})
    
    property real screenWidth: 1920
    readonly property real baseWidth: 1920
    readonly property real scaleFactor: screenWidth / baseWidth
    
    function scale(value) {
        return Math.round(value * scaleFactor)
    }
    
    readonly property var normalBarSize: ({
        "height": scale(60),
        "leftMargin": scale(10),
        "rightMargin": scale(10),
        "topMargin": scale(6),
        "bottomMargin": scale(6)
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
        let wasViaIpc = openedViaIpc
        
        if (newMode === currentMode) {
            currentMode = "normal"
            openedViaIpc = false
        } else {
            currentMode = newMode
            openedViaIpc = viaIpc === true
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
    
    function listModes() {
    }
    
    property string ipcFile: {
        let runtimeDir = Quickshell.env("XDG_RUNTIME_DIR")
        if (!runtimeDir || runtimeDir === "") {
            runtimeDir = "/tmp"
        }
        return runtimeDir + "/mugen-shell-ipc"
    }
    // Monitor IPC reader — if it stalls, external keybinds stop working
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
                if (data) {
                    ipcReader.output += data
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
    
    // Watchdog: kills a stalled reader to prevent permanent IPC failure
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

        // Guard against corrupted IPC strings causing the bar to get stuck
        const known = {
            "normal": true,
            "launcher": true,
            "calendar": true,
            "wallpaper": true,
            "music": true,
            "notification": true,
            "notification-popup": true,
            "powermenu": true,
            "volume": true,
            "wifi": true,
            "bluetooth": true,
            "settings": true,
            "screenshot-gallery": true,
            "clipboard": true,
            "window-switcher": true,
            "ai": true
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
        
        switch(cmd) {
            case "window-switcher-next":
                safeSwitch("window-switcher")
                if (modes["window-switcher"] && typeof modes["window-switcher"].ipcAction === "function") {
                    modes["window-switcher"].ipcAction("next")
                }
                break
            case "window-switcher-prev":
                safeSwitch("window-switcher")
                if (modes["window-switcher"] && typeof modes["window-switcher"].ipcAction === "function") {
                    modes["window-switcher"].ipcAction("prev")
                }
                break
            case "open":
            case "switch":
                if (parts.length > 1) {
                    let modeName = parts[1]
                    safeSwitch(modeName)
                }
                break
            case "close":
                closeAllModes()
                break
            case "toggle":
                if (parts.length > 1) {
                    let modeName = parts[1]
                    safeSwitch(modeName)
                }
                break
            default:
                safeSwitch(cmd)
                break
        }
    }
    
    Component.onCompleted: {
    }
    
    Component.onDestruction: {
        let cleanupProcess = Qt.createQmlObject('
            import QtQuick
            import Quickshell.Io
            Process {
                command: ["rm", "-f", "' + manager.ipcFile + '"]
                running: true
            }
        ', manager)
    }
    
}
