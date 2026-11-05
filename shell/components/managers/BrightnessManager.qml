import QtQuick
import Quickshell.Io

QtObject {
    id: brightnessManager

    property int brightness: 0
    property bool isAvailable: false
    property bool detected: false
    property bool hasSyncedOnce: false
    property int setCount: 0
    property int setCountAtRead: 0
    readonly property int minPercent: 1

    // Never fires for the startup sync, so the panel's auto-close timer only arms on real changes.
    signal userChanged()

    function refresh() {
        // A read that overlaps a write can return the value from before it.
        if (setProcess.running || getProcess.running) return
        setCountAtRead = setCount
        getProcess.running = true
    }

    function setBrightness(percent) {
        let v = Math.max(minPercent, Math.min(100, Math.round(percent)))
        if (v === brightness) return
        brightness = v
        setCount++
        setProcess.payload = String(v) + "%"
        setProcess.running = true
        userChanged()
    }

    function bump(delta) {
        setBrightness(brightness + delta)
    }

    property Process detectProcess: Process {
        running: true
        command: ["bash", "-c", "command -v brightnessctl >/dev/null 2>&1 && [ -n \"$(ls /sys/class/backlight/ 2>/dev/null)\" ] && echo yes || echo no"]
        property string buf: ""
        stdout: SplitParser { onRead: data => detectProcess.buf += data }
        onExited: (exitCode) => {
            let ok = detectProcess.buf.trim() === "yes"
            brightnessManager.isAvailable = ok
            brightnessManager.detected = true
            detectProcess.buf = ""
            if (ok) brightnessManager.refresh()
        }
    }

    property Process getProcess: Process {
        running: false
        // -m's percentage matches brightnessctl's own rounding of `set N%`, so a value just set reads back unchanged.
        command: ["brightnessctl", "--class", "backlight", "-m"]
        property string buf: ""
        stdout: SplitParser { onRead: data => getProcess.buf += data }
        onExited: (exitCode) => {
            let oldValue = brightnessManager.brightness
            const overlappedSet = brightnessManager.setCountAtRead !== brightnessManager.setCount
            if (exitCode === 0 && !overlappedSet) {
                const fields = getProcess.buf.trim().split(",")
                let v = parseInt(fields[fields.length - 2])
                if (!isNaN(v)) brightnessManager.brightness = v
            }
            let alreadySynced = brightnessManager.hasSyncedOnce
            brightnessManager.hasSyncedOnce = true
            if (alreadySynced && oldValue !== brightnessManager.brightness) {
                brightnessManager.userChanged()
            }
            getProcess.buf = ""
        }
    }

    property Process setProcess: Process {
        running: false
        property string payload: ""
        // On a panel with a small max, even 1% rounds to raw 0; -n holds the raw value at 1.
        command: ["brightnessctl", "--class", "backlight", "-n", "set", payload]
    }

    property Timer pollTimer: Timer {
        interval: 2000
        running: brightnessManager.isAvailable
        repeat: true
        onTriggered: brightnessManager.refresh()
    }
}
