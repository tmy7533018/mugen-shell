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
    // Drives the bar's looping completion sound and timer panel auto-open.
    property bool alerting: false

    // Reactive clock for remainingSec. The tick Timer advances it, but every
    // function that changes the countdown must refresh it first: tick only
    // runs while the timer does, so until it fires this holds a stale reading.
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
        now = Date.now()
        alerting = false
        durationSec = seconds
        endTime = now + seconds * 1000
        running = true
        paused = false
        pausedRemainingSec = 0
        save()
    }

    function dismissAlert() {
        if (!alerting) return
        alerting = false
        durationSec = 0
        save()
    }

    function pause() {
        if (!running || paused) return
        now = Date.now()
        pausedRemainingSec = remainingSec
        paused = true
        save()
    }

    function resume() {
        if (!running || !paused) return
        now = Date.now()
        endTime = now + pausedRemainingSec * 1000
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
        alerting = false
        save()
    }

    function save() {
        if (_applyingExternal) return

        let payload = {
            "running": running,
            "paused": paused,
            "durationSec": durationSec,
            "endTime": endTime,
            "pausedRemainingSec": pausedRemainingSec,
            "alerting": alerting
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
            now = Date.now()

            if (s.durationSec !== undefined) durationSec = s.durationSec
            if (s.endTime !== undefined) endTime = s.endTime
            if (s.pausedRemainingSec !== undefined) pausedRemainingSec = s.pausedRemainingSec
            if (s.paused !== undefined) paused = s.paused
            if (s.running !== undefined) running = s.running
            if (s.alerting !== undefined) alerting = s.alerting

            if (running && !paused && endTime > 0 && endTime <= now) {
                running = false
                paused = false
                endTime = 0
                pausedRemainingSec = 0
                alerting = true
                _applyingExternal = false
                completed()
                save()
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
                timerManager.running = false
                timerManager.paused = false
                timerManager.endTime = 0
                timerManager.pausedRemainingSec = 0
                timerManager.alerting = true
                timerManager.save()
                timerManager.completed()
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
