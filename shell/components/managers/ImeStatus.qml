import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    
    property var theme

    property string displayText: "--"
    property string tooltip: "No input method"
    property string statusClass: "ime-none"
    
    property color textColor: theme ? theme.textPrimary : Qt.rgba(0.72, 0.72, 0.82, 0.80)
    
    property string previousDisplayText: "--"
    signal textChanged()
    
    property bool active: true

    property int consecutiveFailures: 0
    property bool queryAnswered: false

    property Timer pollTimer: Timer {
        interval: root.consecutiveFailures >= 3 ? 10000 : 1000
        repeat: true
        running: root.active
        onTriggered: {
            if (!queryProc.running) queryProc.running = true
        }
    }
    
    property Process initialQuery: Process {
        command: ["fcitx5-remote", "-n"]
        running: false
        
        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0) {
                    root.updateDisplayText(trimmed)
                }
            }
        }
    }
    
    property Process queryProcess: Process {
        id: queryProc
        command: ["fcitx5-remote", "-n"]
        running: false
        
        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0) {
                    root.queryAnswered = true
                    root.updateDisplayText(trimmed)
                }
            }
        }

        // A binary that cannot be spawned never emits exited, so the outcome is judged when running drops.
        onRunningChanged: {
            if (running) return
            root.consecutiveFailures = root.queryAnswered ? 0 : root.consecutiveFailures + 1
            root.queryAnswered = false
        }
    }
    
    function updateDisplayText(imName) {
        let newText = "--"
        let newClass = "ime-none"
        let newTooltip = "No input method"
        
        if (!imName || imName === "") {
            newText = "--"
            newClass = "ime-none"
            newTooltip = "No input method"
        } else if (imName.includes("mozc") || imName.includes("Mozc")) {
            newText = "あ"
            newClass = "ime-mozc"
            newTooltip = "Mozc (Japanese input)"
        } else if (imName.includes("keyboard-jp") || imName.includes("jp")) {
            newText = "JP"
            newClass = "ime-jp"
            newTooltip = "Japanese keyboard (OADG 109A)"
        } else if (imName.includes("keyboard-us") || imName.includes("us")) {
            newText = "US"
            newClass = "ime-us"
            newTooltip = "English keyboard (US)"
        } else {
            newText = imName.substring(0, 2).toUpperCase()
            newClass = "ime-other"
            newTooltip = "Input method: " + imName
        }
        
        if (newText !== root.displayText) {
            root.previousDisplayText = root.displayText
            root.displayText = newText
            root.statusClass = newClass
            root.tooltip = newTooltip
            root.textChanged()
        }
    }
    
    property Timer initTimer: Timer {
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            root.initialQuery.running = true
        }
    }
    
    Component.onCompleted: {
        // Delay initial query to wait for fcitx5 to start
        initTimer.start()
    }
}
