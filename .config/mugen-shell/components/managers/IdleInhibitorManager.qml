import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: idleInhibitorManager

    property bool isInhibited: false
    property bool isBusy: false
    property string lastError: ""
    property bool isLoadingState: false

    readonly property string toggleScript: Quickshell.shellDir + "/scripts/idle_inhibitor.sh"
    // Qt.env is unavailable; use shell $HOME expansion at runtime via bash
    readonly property string cacheDir: "$HOME/.cache/mugen-shell"
    readonly property string stateFile: cacheDir + "/idle_inhibitor_state.json"

    function refreshStatus() {
        if (!statusProcess.running) {
            statusProcess.running = true
        }
    }

    function toggle() {
        if (toggleProcess.running) {
            return
        }
        isBusy = true
        lastError = ""
        toggleProcess.command = ["bash", toggleScript]
        toggleProcess.running = true
    }

    function saveState() {
        let state = {
            "enabled": isInhibited
        }
        let jsonString = JSON.stringify(state, null, 2)

        saveStateProcess.command = [
            "bash", "-c",
            "mkdir -p \"" + cacheDir + "\" && echo '" + jsonString + "' > \"" + stateFile + "\""
        ]
        saveStateProcess.running = true
    }

    function loadState() {
        if (isLoadingState) {
            return
        }
        isLoadingState = true
        loadStateProcess.command = ["bash", "-c", "cat \"" + stateFile + "\""]
        loadStateProcess.running = true
    }

    function restoreState(shouldBeInhibited) {
        pendingRestoreState = shouldBeInhibited
        refreshStatus()
    }

    property var pendingRestoreState: null

    property Process statusProcess: Process {
        command: ["systemctl", "--user", "is-active", "hypridle.service"]
        running: false

        onExited: (exitCode) => {
            // exitCode 0 = hypridle active (not inhibited), non-0 = stopped (inhibited)
            let currentInhibited = exitCode !== 0
            idleInhibitorManager.isInhibited = currentInhibited
            idleInhibitorManager.isBusy = false

            if (pendingRestoreState !== null && pendingRestoreState !== currentInhibited) {
                if (pendingRestoreState && !currentInhibited) {
                    restoreToggleProcess.command = ["bash", toggleScript]
                    restoreToggleProcess.running = true
                } else if (!pendingRestoreState && currentInhibited) {
                    restoreToggleProcess.command = ["bash", toggleScript]
                    restoreToggleProcess.running = true
                }
                pendingRestoreState = null
            }
        }
    }

    onIsInhibitedChanged: {
        // Only auto-save after initialization, not during restore or loading
        if (isInitialized && !isLoadingState && pendingRestoreState === null) {
            saveState()
        }
    }

    property Process toggleProcess: Process {
        command: []
        running: false

        stderr: SplitParser {
            onRead: data => {
                idleInhibitorManager.lastError = data.trim()
            }
        }

        onExited: () => {
            idleInhibitorManager.isBusy = false
            idleInhibitorManager.refreshStatus()
        }
    }

    property Process restoreToggleProcess: Process {
        command: []
        running: false

        onExited: () => {
            // Only refresh status; no save needed since we're restoring to already-saved state
            idleInhibitorManager.refreshStatus()
        }
    }

    property Process saveStateProcess: Process {
        command: []
        running: false

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Failed to save idle inhibitor state")
            }
        }
    }

    property Process loadStateProcess: Process {
        command: []
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => {
                loadStateProcess.output += data
            }
        }

        onExited: (exitCode) => {
            idleInhibitorManager.isLoadingState = false
            if (exitCode === 0 && loadStateProcess.output.trim().length > 0) {
                try {
                    let state = JSON.parse(loadStateProcess.output)
                    if (state.enabled !== undefined) {
                        idleInhibitorManager.restoreState(state.enabled)
                    } else {
                        idleInhibitorManager.refreshStatus()
                    }
                } catch (e) {
                    console.warn("Failed to parse idle inhibitor state:", e)
                    idleInhibitorManager.refreshStatus()
                }
            } else {
                idleInhibitorManager.refreshStatus()
            }
            loadStateProcess.output = ""
        }
    }

    // Polling disabled in favor of D-Bus monitoring; kept as fallback
    property Timer pollTimer: Timer {
        interval: 5000
        running: false
        repeat: true
        onTriggered: idleInhibitorManager.refreshStatus()
    }

    property bool isInitialized: false

    property Process dbusMonitor: Process {
        command: [
            "dbus-monitor",
            "--session",
            "sender='org.freedesktop.systemd1'"
        ]
        running: false

        stdout: SplitParser {
            onRead: data => {
                if (!idleInhibitorManager.isInitialized) return

                if (data.includes("hypridle") || data.includes("ActiveState")) {
                    idleDebounceTimer.restart()
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {
            }
        }
    }

    property Timer idleDebounceTimer: Timer {
        interval: 300
        repeat: false
        onTriggered: {
            if (!statusProcess.running) {
                refreshStatus()
            }
        }
    }

    // Delay D-Bus monitor start to let state restoration complete first
    property Timer initDelayTimer: Timer {
        interval: 500
        repeat: false
        onTriggered: {
            idleInhibitorManager.isInitialized = true
            idleInhibitorManager.dbusMonitor.running = true
        }
    }

    Component.onCompleted: {
        loadState()
        initDelayTimer.start()
    }

    Component.onDestruction: {
        if (dbusMonitor.running) {
            dbusMonitor.running = false
        }
    }
}
