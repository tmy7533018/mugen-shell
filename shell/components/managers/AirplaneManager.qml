import QtQuick
import Quickshell.Io

QtObject {
    id: airplaneManager

    property bool isEnabled: false
    property bool active: true

    onActiveChanged: {
        if (active) refreshStatus()
    }

    function toggle() {
        airplaneToggleProcess.command = ["bash", "-c",
            isEnabled
                ? "rfkill unblock all && sleep 1 && bluetoothctl power on"
                : "rfkill block all"]
        airplaneToggleProcess.running = true
    }

    function refreshStatus() {
        if (statusProcess.running) return
        statusProcess.total = 0
        statusProcess.blocked = 0
        statusProcess.running = true
    }

    property Process statusProcess: Process {
        command: ["bash", "-c", "rfkill --output SOFT --noheadings 2>/dev/null"]
        running: false

        property int total: 0
        property int blocked: 0

        stdout: SplitParser {
            onRead: line => {
                let t = line.trim()
                if (t.length === 0) return
                statusProcess.total++
                if (t === "blocked") statusProcess.blocked++
            }
        }

        onExited: (code, status) => {
            airplaneManager.isEnabled = (statusProcess.total > 0 && statusProcess.blocked === statusProcess.total)
        }
    }

    property Process airplaneToggleProcess: Process {
        running: false
        onExited: (code, status) => {
            airplaneManager.refreshStatus()
        }
    }

    property Process rfkillMonitor: Process {
        command: ["bash", "-c", "rfkill event"]
        running: airplaneManager.active && !airplaneManager.monitorRestartTimer.running

        stdout: SplitParser {
            onRead: data => {
                airplaneManager.debounceTimer.restart()
            }
        }

        // The stream ends when the process does, so this is where a dead monitor shows up.
        stderr: StdioCollector {
            onStreamFinished: airplaneManager.monitorRestartTimer.restart()
        }
    }

    // A dead rfkill monitor would otherwise freeze airplane mode until the shell restarts.
    property Timer monitorRestartTimer: Timer {
        interval: 2000
    }

    property Timer debounceTimer: Timer {
        interval: 200
        repeat: false
        onTriggered: {
            airplaneManager.refreshStatus()
        }
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            if (active) refreshStatus()
        })
    }

    Component.onDestruction: {
        if (rfkillMonitor.running) {
            rfkillMonitor.running = false
        }
    }
}
