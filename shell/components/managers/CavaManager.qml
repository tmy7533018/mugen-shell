import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: cavaManager
    
    property real audioLevel: 0.0
    property real rms: 0.0
    property bool isActive: false
    property var barLevels: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property Process cavaProcess: Process {
        running: cavaManager.isActive
        command: ["/bin/bash", Quickshell.shellDir + "/scripts/cava.sh"]
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed === "") return
                
                let values = trimmed.split(/\s+/)
                
                if (values.length >= 16) {
                    let levels = []
                    let sum = 0
                    let max = 0
                    
                    for (let i = 0; i < 16; i++) {
                        let val = parseInt(values[i])
                        if (!isNaN(val)) {
                            let normalized = val / 100.0
                            levels.push(normalized)
                            sum += normalized
                            max = Math.max(max, normalized)
                        } else {
                            levels.push(0)
                        }
                    }
                    
                    if (levels.length === 16) {
                        cavaManager.barLevels = levels
                        cavaManager.audioLevel = max
                        cavaManager.rms = sum / 16.0
                    }
                }
            }
        }
        
        stderr: SplitParser {
        }
        
        onExited: (exitCode, exitStatus) => {
            if (cavaManager.isActive) {
                Qt.callLater(() => {
                    restartTimer.start()
                })
            }
        }
    }
    
    property Timer restartTimer: Timer {
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            if (cavaManager.isActive && !cavaProcess.running) {
                cavaProcess.running = true
            }
        }
    }
    
    function start() {
        if (!isActive) {
            isActive = true
        }
    }
    
    function stop() {
        if (isActive) {
            isActive = false
            audioLevel = 0.0
            barLevels = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        }
    }
    
    Component.onDestruction: {
        if (cavaProcess.running) {
            cavaProcess.running = false
        }
    }
    
}

