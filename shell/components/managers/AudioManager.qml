import QtQuick
import Quickshell.Io

QtObject {
    id: audioManager

    property int volume: 0
    property bool isMuted: false
    property bool isAvailable: false
    property bool isHeadphone: false
    property bool headphoneReady: false

    // Microphone (input source) state
    property int micVolume: 0
    property bool micMuted: false
    property bool micAvailable: false

    property var sinks: []
    property var sources: []
    property string defaultSinkName: ""
    property string defaultSourceName: ""

    // Replaced by D-Bus monitoring; kept as disabled fallback
    property Timer updateTimer: Timer {
        interval: 200
        running: false
        repeat: true
        onTriggered: {
            audioManager.updateVolume()
            audioManager.updateMuteStatus()
            audioManager.updateHeadphoneStatus()
        }
    }

    property Process volumeProcess: Process {
        running: false
        command: ["bash", "-c", "pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\\d+%' | head -1 | tr -d '%'"]

        property string outputData: ""

        stdout: SplitParser {
            onRead: data => volumeProcess.outputData += data
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                let output = outputData.trim()
                if (output !== "") {
                    audioManager.volume = parseInt(output)
                    audioManager.isAvailable = true
                }
            } else {
                audioManager.isAvailable = false
            }
            outputData = ""
        }
    }

    property Process muteProcess: Process {
        running: false
        command: ["bash", "-c", "pactl get-sink-mute @DEFAULT_SINK@ | grep -oP '(yes|no)'"]

        property string outputData: ""

        stdout: SplitParser {
            onRead: data => muteProcess.outputData += data
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                let output = outputData.trim()
                audioManager.isMuted = (output === "yes")
            }
            outputData = ""
        }
    }

    property Process setVolumeProcess: Process {
        running: false
        command: []

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Qt.callLater(() => {
                    audioManager.updateVolume()
                })
            }
        }
    }

    property Process toggleMuteProcess: Process {
        running: false
        command: ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Qt.callLater(() => {
                    audioManager.updateMuteStatus()
                })
            }
        }
    }

    function setVolume(newVolume) {
        let clampedVolume = Math.max(0, Math.min(100, Math.round(newVolume)))

        setVolumeProcess.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", clampedVolume + "%"]
        setVolumeProcess.running = true
    }

    function toggleMute() {
        toggleMuteProcess.running = true
    }

    function updateVolume() {
        if (!volumeProcess.running) {
            volumeProcess.running = true
        }
    }

    function updateMuteStatus() {
        if (!muteProcess.running) {
            muteProcess.running = true
        }
    }

    // Microphone (source) processes & helpers

    property Process micVolumeProcess: Process {
        running: false
        command: ["bash", "-c", "pactl get-source-volume @DEFAULT_SOURCE@ | grep -oP '\\d+%' | head -1 | tr -d '%'"]

        property string outputData: ""

        stdout: SplitParser {
            onRead: data => micVolumeProcess.outputData += data
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                let output = micVolumeProcess.outputData.trim()
                if (output !== "") {
                    audioManager.micVolume = parseInt(output)
                    audioManager.micAvailable = true
                }
            } else {
                audioManager.micAvailable = false
            }
            micVolumeProcess.outputData = ""
        }
    }

    property Process micMuteProcess: Process {
        running: false
        command: ["bash", "-c", "pactl get-source-mute @DEFAULT_SOURCE@ | grep -oP '(yes|no)'"]

        property string outputData: ""

        stdout: SplitParser {
            onRead: data => micMuteProcess.outputData += data
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                let output = micMuteProcess.outputData.trim()
                audioManager.micMuted = (output === "yes")
            }
            micMuteProcess.outputData = ""
        }
    }

    property Process setMicVolumeProcess: Process {
        running: false
        command: []

        onExited: (exitCode) => {
            if (exitCode === 0) {
                Qt.callLater(() => audioManager.updateMicVolume())
            }
        }
    }

    property Process toggleMicMuteProcess: Process {
        running: false
        command: ["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "toggle"]

        onExited: (exitCode) => {
            if (exitCode === 0) {
                Qt.callLater(() => audioManager.updateMicMuteStatus())
            }
        }
    }

    function setMicVolume(newVolume) {
        let clampedVolume = Math.max(0, Math.min(100, Math.round(newVolume)))
        setMicVolumeProcess.command = ["pactl", "set-source-volume", "@DEFAULT_SOURCE@", clampedVolume + "%"]
        setMicVolumeProcess.running = true
    }

    function toggleMicMute() {
        toggleMicMuteProcess.running = true
    }

    function updateMicVolume() {
        if (!micVolumeProcess.running) {
            micVolumeProcess.running = true
        }
    }

    function updateMicMuteStatus() {
        if (!micMuteProcess.running) {
            micMuteProcess.running = true
        }
    }

    property Process headphoneProcess: Process {
        running: false
        command: ["bash", "-c", "DEFAULT_SINK=$(pactl info | grep 'Default Sink:' | cut -d' ' -f3); if [ -n \"$DEFAULT_SINK\" ]; then echo \"NAME:$DEFAULT_SINK\"; pactl list sinks | awk -v sink=\"$DEFAULT_SINK\" '/Name: / {flag=0} \\$0 ~ (\"Name: \" sink) {flag=1} flag {print}' | tr '\\n' ' '; fi"]

        property string outputData: ""

        stdout: SplitParser {
            onRead: data => headphoneProcess.outputData += data
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                let output = headphoneProcess.outputData.trim().toLowerCase()
                audioManager.isHeadphone = output.length > 0 && (
                    output.includes("headphone") ||
                    output.includes("headset") ||
                    output.includes("earphone") ||
                    output.includes("earbud") ||
                    output.includes("ear-piece")
                )
            } else {
                audioManager.isHeadphone = false
            }
            headphoneProcess.outputData = ""
            audioManager.headphoneReady = true
        }
    }

    function updateHeadphoneStatus() {
        if (!headphoneProcess.running) {
            headphoneProcess.running = true
        }
    }

    property Process sinksProcess: Process {
        running: false
        command: ["bash", "-c", "pactl list sinks | grep -E '(Name:|Description:)' | paste - - | sed 's/\\tName: /|/g; s/\\tDescription: /|/g'"]

        property string outputData: ""

        stdout: SplitParser {
            onRead: data => sinksProcess.outputData += data + "\n"
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                let lines = outputData.trim().split("\n")
                let newSinks = []
                for (let line of lines) {
                    let parts = line.split("|")
                    if (parts.length >= 3) {
                        let name = parts[1].trim()
                        let description = parts[2].trim()
                        newSinks.push({
                            name: name,
                            description: description,
                            isDefault: (name === audioManager.defaultSinkName)
                        })
                    }
                }
                audioManager.sinks = newSinks
            }
            outputData = ""
        }
    }

    property Process sourcesProcess: Process {
        running: false
        command: ["bash", "-c", "pactl list sources | grep -E '(Name:|Description:)' | paste - - | sed 's/\\tName: /|/g; s/\\tDescription: /|/g'"]

        property string outputData: ""

        stdout: SplitParser {
            onRead: data => sourcesProcess.outputData += data + "\n"
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                let lines = outputData.trim().split("\n")
                let newSources = []
                for (let line of lines) {
                    let parts = line.split("|")
                    if (parts.length >= 3) {
                        let name = parts[1].trim()
                        let description = parts[2].trim()
                        // Exclude monitor sources (*.monitor)
                        if (!name.endsWith(".monitor")) {
                            newSources.push({
                                name: name,
                                description: description,
                                isDefault: (name === audioManager.defaultSourceName)
                            })
                        }
                    }
                }
                audioManager.sources = newSources
            }
            outputData = ""
        }
    }

    property Process defaultDevicesProcess: Process {
        running: false
        command: ["bash", "-c", "pactl info | grep -E '(Default Sink:|Default Source:)'"]

        property string outputData: ""

        stdout: SplitParser {
            onRead: data => defaultDevicesProcess.outputData += data + "\n"
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                let lines = outputData.trim().split("\n")
                for (let line of lines) {
                    if (line.includes("Default Sink:")) {
                        audioManager.defaultSinkName = line.split(":")[1].trim()
                    } else if (line.includes("Default Source:")) {
                        audioManager.defaultSourceName = line.split(":")[1].trim()
                    }
                }
                if (!sinksProcess.running) sinksProcess.running = true
                if (!sourcesProcess.running) sourcesProcess.running = true
            }
            outputData = ""
        }
    }

    property Process setDefaultSinkProcess: Process {
        running: false
        command: []

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Qt.callLater(() => {
                    updateDevices()
                    updateVolume()
                    updateMuteStatus()
                    updateHeadphoneStatus()
                })
            }
        }
    }

    property Process setDefaultSourceProcess: Process {
        running: false
        command: []

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Qt.callLater(() => {
                    updateDevices()
                })
            }
        }
    }

    function updateDevices() {
        if (!defaultDevicesProcess.running) {
            defaultDevicesProcess.running = true
        }
    }

    function setDefaultSink(sinkName) {
        setDefaultSinkProcess.command = ["pactl", "set-default-sink", sinkName]
        setDefaultSinkProcess.running = true
    }

    function setDefaultSource(sourceName) {
        setDefaultSourceProcess.command = ["pactl", "set-default-source", sourceName]
        setDefaultSourceProcess.running = true
    }

    property Process pulseEventMonitor: Process {
        command: ["pactl", "subscribe"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                if (data.includes("Event") && (
                    data.includes("sink") ||
                    data.includes("source") ||
                    data.includes("server") ||
                    data.includes("card"))) {
                    audioDebounceTimer.restart()
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {
            }
        }
    }

    property Timer audioDebounceTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: {
            if (!volumeProcess.running) {
                updateVolume()
            }
            if (!muteProcess.running) {
                updateMuteStatus()
            }
            if (!micVolumeProcess.running) {
                updateMicVolume()
            }
            if (!micMuteProcess.running) {
                updateMicMuteStatus()
            }
            if (!headphoneProcess.running) {
                updateHeadphoneStatus()
            }
            if (!defaultDevicesProcess.running) {
                updateDevices()
            }
        }
    }

    Component.onCompleted: {
        updateVolume()
        updateMuteStatus()
        updateMicVolume()
        updateMicMuteStatus()
        updateHeadphoneStatus()
        updateDevices()
    }

    Component.onDestruction: {
        if (pulseEventMonitor.running) {
            pulseEventMonitor.running = false
        }
    }
}
