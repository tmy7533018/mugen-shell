import QtQuick
import Quickshell.Io
import "../../lib" as Theme

Item {
    id: root

    required property var timerManagerRef
    required property var modeManagerRef
    required property var settingsManagerRef

    readonly property string timerSoundsDir: Theme.Paths.timerSoundsDir

    Connections {
        target: root.timerManagerRef

        function onCompleted() {
            // Don't yank focus from another open panel.
            if (root.modeManagerRef.isMode("normal")) {
                root.modeManagerRef.switchMode("timer")
            }
        }

        function onAlertingChanged() {
            if (root.timerManagerRef.alerting) {
                root._playTimerSound()
                timerLoopTimer.restart()
                timerSafetyTimer.restart()
            } else {
                timerLoopTimer.stop()
                timerSafetyTimer.stop()
                if (timerSoundProcess.running) timerSoundProcess.running = false
            }
        }
    }

    function _playTimerSound() {
        const name = root.settingsManagerRef ? root.settingsManagerRef.timerSound : "None"
        if (!name || name === "None" || name === "") return
        timerSoundProcess.command = ["paplay", root.timerSoundsDir + "/" + name]
        timerSoundProcess.running = true
    }

    Process {
        id: timerSoundProcess
        command: []
        running: false

        stderr: StdioCollector { id: timerSoundError }

        // Dismissing the alert ends paplay with SIGTERM, which is not a failure.
        onExited: (exitCode) => {
            if (exitCode !== 0 && root.timerManagerRef.alerting)
                console.warn("timer sound: paplay exited " + exitCode + ": " + timerSoundError.text.trim())
        }
    }

    Timer {
        id: timerLoopTimer
        interval: 4000
        repeat: true
        running: false
        onTriggered: root._playTimerSound()
    }

    Timer {
        id: timerSafetyTimer
        interval: 60000
        repeat: false
        running: false
        onTriggered: {
            if (root.timerManagerRef.alerting) root.timerManagerRef.dismissAlert()
        }
    }
}
