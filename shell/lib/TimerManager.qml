import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: timerManager

    readonly property string stateDir: {
        let xdg = Quickshell.env("XDG_STATE_HOME")
        if (!xdg || xdg === "") xdg = Quickshell.env("HOME") + "/.local/state"
        return xdg + "/mugen-shell"
    }
    property string stateFile: stateDir + "/timer.json"

    property bool running: false
    property bool paused: false
    property int durationSec: 0
    property real endTime: 0
    property int pausedRemainingSec: 0

    property real now: Date.now()

    readonly property int remainingSec: {
        if (!running) return durationSec
        if (paused) return pausedRemainingSec
        return Math.max(0, Math.ceil((endTime - now) / 1000))
    }

    property bool _applyingExternal: false

    signal completed()

    function start(seconds) {
        if (seconds <= 0) return
        durationSec = seconds
        endTime = Date.now() + seconds * 1000
        running = true
        paused = false
        pausedRemainingSec = 0
        save()
    }

    function pause() {
        if (!running || paused) return
        pausedRemainingSec = remainingSec
        paused = true
        save()
    }

    function resume() {
        if (!running || !paused) return
        endTime = Date.now() + pausedRemainingSec * 1000
        paused = false
        pausedRemainingSec = 0
        save()
    }

    function cancel() {
        running = false
        paused = false
        endTime = 0
        durationSec = 0
        pausedRemainingSec = 0
        save()
    }

    function save() {
        if (_applyingExternal) return

        let payload = {
            "running": running,
            "paused": paused,
            "durationSec": durationSec,
            "endTime": endTime,
            "pausedRemainingSec": pausedRemainingSec
        }
        let json = JSON.stringify(payload, null, 2)
        saveProcess.command = [
            "bash", "-c",
            "mkdir -p \"" + stateDir + "\" && cat > \"" + stateFile + "\" <<'JSON_EOF'\n" + json + "\nJSON_EOF"
        ]
        saveProcess.running = true
    }

    function loadState() {
        readProcess.command = ["cat", stateFile]
        readProcess.running = true
    }

    function applyFromJson(jsonString) {
        try {
            let s = JSON.parse(jsonString)
            _applyingExternal = true

            if (s.durationSec !== undefined) durationSec = s.durationSec
            if (s.endTime !== undefined) endTime = s.endTime
            if (s.pausedRemainingSec !== undefined) pausedRemainingSec = s.pausedRemainingSec
            if (s.paused !== undefined) paused = s.paused
            if (s.running !== undefined) running = s.running

            // If running with endTime in the past, treat it as already expired
            if (running && !paused && endTime > 0 && endTime <= Date.now()) {
                completed()
                _applyingExternal = false
                cancel()
                return
            }

            _applyingExternal = false
        } catch (e) {
            _applyingExternal = false
            console.error("Failed to parse timer state:", e)
        }
    }

    property Timer tick: Timer {
        interval: 200
        running: timerManager.running && !timerManager.paused
        repeat: true
        onTriggered: {
            timerManager.now = Date.now()
            if (timerManager.running && !timerManager.paused && timerManager.remainingSec === 0) {
                timerManager.completed()
                timerManager.cancel()
            }
        }
    }

    property FileView stateWatcher: FileView {
        path: timerManager.stateFile
        watchChanges: true
        preload: false
        printErrors: false

        onFileChanged: {
            timerManager.loadState()
        }
    }

    property Process readProcess: Process {
        command: []
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => { readProcess.output += data }
        }

        onExited: (exitCode) => {
            if (exitCode === 0 && readProcess.output.trim().length > 0) {
                applyFromJson(readProcess.output)
            }
            readProcess.output = ""
        }
    }

    property Process saveProcess: Process {
        command: []
        running: false
        stdout: SplitParser { onRead: data => {} }
        stderr: SplitParser { onRead: data => {} }
    }

    Component.onCompleted: loadState()
}
