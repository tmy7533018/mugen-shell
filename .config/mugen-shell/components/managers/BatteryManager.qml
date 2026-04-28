import QtQuick
import Quickshell.Io

QtObject {
    id: batteryManager

    property bool present: false
    property int percentage: 0
    // "Charging", "Discharging", "Full", "Not charging", "Unknown"
    property string state: "Unknown"
    readonly property bool isCharging: state === "Charging" || state === "Full"

    function refresh() {
        if (!detectProcess.running) {
            detectProcess.running = true
        }
    }

    property Timer pollTimer: Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: batteryManager.refresh()
    }

    // Detects the first BAT* device under /sys/class/power_supply
    property Process detectProcess: Process {
        command: ["bash", "-c", "for d in /sys/class/power_supply/BAT*; do [ -d \"$d\" ] && echo \"$d\" && exit 0; done; echo ''"]
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => { detectProcess.output += data }
        }

        onExited: () => {
            const path = detectProcess.output.trim()
            detectProcess.output = ""
            if (path.length === 0) {
                batteryManager.present = false
                return
            }
            batteryManager.present = true
            readProcess.command = ["bash", "-c",
                "cat \"" + path + "/capacity\" \"" + path + "/status\" 2>/dev/null"]
            readProcess.running = true
        }
    }

    property Process readProcess: Process {
        command: []
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => { readProcess.output += data }
        }

        onExited: () => {
            const lines = readProcess.output.trim().split("\n")
            readProcess.output = ""
            if (lines.length >= 2) {
                const pct = parseInt(lines[0])
                if (!isNaN(pct)) batteryManager.percentage = pct
                batteryManager.state = lines[1].trim()
            }
        }
    }
}
