// Standalone Quickshell entry for the floating settings window.

//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import "./lib" as Theme
import "./components/content" as Content

ShellRoot {
    id: root

    Theme.Colors {
        id: themeColors
    }

    Theme.SettingsManager {
        id: settingsManager
    }

    QtObject {
        id: modeStub

        function scale(v) {
            return v
        }

        function bump() {
        }
    }

    readonly property string soundsDir: {
        let xdg = Quickshell.env("XDG_DATA_HOME")
        if (!xdg || xdg === "") xdg = Quickshell.env("HOME") + "/.local/share"
        return xdg + "/mugen-shell/sounds"
    }

    property var blurPresets: []
    property bool isLoadingPresets: false
    property string currentPreset: ""

    property var notificationSounds: ["None"]

    function loadBlurPresets() {
        if (isLoadingPresets) return
        isLoadingPresets = true
        listPresetsProcess.running = true
        getCurrentPresetProcess.running = true
    }

    function applyBlurPreset(presetName) {
        applyPresetProcess.command = [
            "bash",
            Quickshell.shellDir + "/scripts/blur-preset.sh",
            presetName
        ]
        applyPresetProcess.running = true
    }

    function loadNotificationSounds() {
        listSoundsProcess.running = true
    }

    function applyNotificationSound(name) {
        if (settingsManager) {
            settingsManager.notificationSound = name
            settingsManager.saveSettings()
        }
        if (name !== "None") {
            previewSoundProcess.command = [
                "paplay",
                root.soundsDir + "/" + name
            ]
            previewSoundProcess.running = true
        }
    }

    function applyTimerSound(name) {
        if (settingsManager) {
            settingsManager.timerSound = name
            settingsManager.saveSettings()
        }
        if (name !== "None") {
            previewSoundProcess.command = [
                "paplay",
                root.soundsDir + "/" + name
            ]
            previewSoundProcess.running = true
        }
    }

    function applyLockTimer(minutes) {
        applyLockTimerProcess.command = [
            "bash",
            Quickshell.shellDir + "/scripts/lock-timer.sh",
            String(minutes)
        ]
        applyLockTimerProcess.running = true
    }

    Process {
        id: listPresetsProcess
        command: ["bash", Quickshell.shellDir + "/scripts/blur-preset.sh", "list"]
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0) listPresetsProcess.output += trimmed + "\n"
            }
        }

        onExited: () => {
            try {
                let presets = listPresetsProcess.output.split("\n").filter(p => p.length > 0)
                root.blurPresets = presets
                root.isLoadingPresets = false
                listPresetsProcess.output = ""
            } catch (e) {
                root.isLoadingPresets = false
            }
        }
    }

    Process {
        id: getCurrentPresetProcess
        command: ["bash", Quickshell.shellDir + "/scripts/blur-preset.sh", "current"]
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => { getCurrentPresetProcess.output += data }
        }

        onExited: () => {
            root.currentPreset = getCurrentPresetProcess.output.trim()
            getCurrentPresetProcess.output = ""
        }
    }

    Process {
        id: applyPresetProcess
        command: []
        running: false
        onExited: () => getCurrentPresetProcess.running = true
    }

    Process {
        id: listSoundsProcess
        command: ["sh", "-c", "d=\"" + root.soundsDir + "\"; mkdir -p \"$d\"; ls -1 \"$d\" 2>/dev/null | grep -E '\\.(wav|ogg|mp3|oga|flac)$' || true"]
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0) listSoundsProcess.output += trimmed + "\n"
            }
        }

        onExited: () => {
            let sounds = ["None"]
            let lines = listSoundsProcess.output.split("\n").filter(s => s.length > 0)
            for (let i = 0; i < lines.length; i++) sounds.push(lines[i])
            root.notificationSounds = sounds
            listSoundsProcess.output = ""
        }
    }

    Process {
        id: previewSoundProcess
        command: []
        running: false
    }

    Process {
        id: applyLockTimerProcess
        command: []
        running: false
    }

    FloatingWindow {
        id: settingsWindow

        visible: true
        title: "Mugen Settings"
        color: "transparent"
        minimumSize: Qt.size(800, 540)

        Content.SettingsFloatingContent {
            anchors.fill: parent
            modeManager: modeStub
            theme: themeColors
            settingsManager: settingsManager
            blurPresets: root.blurPresets
            currentPreset: root.currentPreset
            isLoadingPresets: root.isLoadingPresets
            notificationSounds: root.notificationSounds

            onApplyPreset: name => root.applyBlurPreset(name)
            onApplySound: name => root.applyNotificationSound(name)
            onApplyTimerSound: name => root.applyTimerSound(name)
        }
    }

    Component.onCompleted: {
        loadBlurPresets()
        loadNotificationSounds()
    }

    Connections {
        target: settingsManager
        function onLockTimerMinutesChanged() {
            root.applyLockTimer(settingsManager.lockTimerMinutes)
        }
    }
}
