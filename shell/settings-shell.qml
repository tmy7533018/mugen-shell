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

        function isMode(name) {
            return false
        }

        function bump() {
        }
    }

    readonly property string soundsDir: Theme.Paths.soundsDir
    readonly property string timerSoundsDir: Theme.Paths.timerSoundsDir

    property var blurPresets: []
    property bool isLoadingPresets: false
    property string currentPreset: ""

    property var notificationSounds: ["None"]
    property var timerSounds: ["None"]

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

    function loadTimerSounds() {
        listTimerSoundsProcess.running = true
    }

    function applyNotificationSound(name) {
        if (settingsManager) {
            settingsManager.notificationSound = name
            settingsManager.saveSettings()
        }
        if (name !== "None") {
            previewSoundProcess.running = false
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
            previewSoundProcess.running = false
            previewSoundProcess.command = [
                "paplay",
                root.timerSoundsDir + "/" + name
            ]
            previewSoundProcess.running = true
        }
    }

    // Only lock/suspend/dpms write hypridle.conf, so they're queued through one
    // Process: two of these firing together (e.g. Reset to Default) would
    // otherwise race as concurrent read-modify-writes of the same file, and
    // setting `running = true` on an already-running Process is a silent no-op
    // that would drop whichever call lost the race.
    property var _hyprIdleQueue: []
    property bool _hyprIdleBusy: false

    function _queueHyprIdleScript(kind, args) {
        root._hyprIdleQueue = root._hyprIdleQueue.filter(q => q.kind !== kind)
        root._hyprIdleQueue.push({ kind: kind, args: args })
        root._drainHyprIdleQueue()
    }

    function _drainHyprIdleQueue() {
        if (root._hyprIdleBusy || root._hyprIdleQueue.length === 0) return
        root._hyprIdleBusy = true
        let next = root._hyprIdleQueue.shift()
        hyprIdleQueueProcess.command = next.args
        hyprIdleQueueProcess.running = true
    }

    function applyLockTimer(minutes) {
        root._queueHyprIdleScript("lock", [
            "bash",
            Quickshell.shellDir + "/scripts/lock-timer.sh",
            String(minutes)
        ])
    }

    function applyIdleSuspend(minutes) {
        root._queueHyprIdleScript("suspend", [
            "bash",
            Quickshell.shellDir + "/scripts/idle-timer.sh",
            "suspend",
            String(minutes)
        ])
    }

    function applyIdleDpms(minutes) {
        root._queueHyprIdleScript("dpms", [
            "bash",
            Quickshell.shellDir + "/scripts/idle-timer.sh",
            "dpms",
            String(minutes)
        ])
    }

    function openAiConfig() {
        let cfgHome = Quickshell.env("XDG_CONFIG_HOME")
        if (!cfgHome || cfgHome === "") cfgHome = Quickshell.env("HOME") + "/.config"
        openAiConfigProcess.command = ["xdg-open", cfgHome + "/mugen-ai/config.toml"]
        openAiConfigProcess.running = true
    }

    function restartAi() {
        restartAiProcess.command = ["systemctl", "--user", "restart", "mugen-ai.service"]
        restartAiProcess.running = true
    }

    Process {
        id: openAiConfigProcess
        command: []
        running: false
    }

    Process {
        id: restartAiProcess
        command: []
        running: false
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
        id: listTimerSoundsProcess
        command: ["sh", "-c", "d=\"" + root.timerSoundsDir + "\"; mkdir -p \"$d\"; ls -1 \"$d\" 2>/dev/null | grep -E '\\.(wav|ogg|mp3|oga|flac)$' || true"]
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0) listTimerSoundsProcess.output += trimmed + "\n"
            }
        }

        onExited: () => {
            let sounds = ["None"]
            let lines = listTimerSoundsProcess.output.split("\n").filter(s => s.length > 0)
            for (let i = 0; i < lines.length; i++) sounds.push(lines[i])
            root.timerSounds = sounds
            listTimerSoundsProcess.output = ""
        }
    }

    Process {
        id: previewSoundProcess
        command: []
        running: false
    }

    Process {
        id: hyprIdleQueueProcess
        command: []
        running: false
        onExited: {
            root._hyprIdleBusy = false
            root._drainHyprIdleQueue()
        }
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
            timerSounds: root.timerSounds
            soundsDir: root.soundsDir
            timerSoundsDir: root.timerSoundsDir

            onApplyPreset: name => root.applyBlurPreset(name)
            onApplySound: name => root.applyNotificationSound(name)
            onApplyTimerSound: name => root.applyTimerSound(name)
            onEditAiConfig: root.openAiConfig()
            onRestartAi: root.restartAi()
        }
    }

    Component.onCompleted: {
        loadBlurPresets()
        loadNotificationSounds()
        loadTimerSounds()
    }

    // The settings file's very first load fires these same property-changed
    // signals for every value that differs from the QML defaults, which would
    // otherwise rewrite hypridle.conf and restart hypridle just from opening
    // the settings window. settingsChanged() fires at the end of that first
    // load (still inside the same synchronous pass, before this flag flips),
    // so it suppresses exactly that load without blocking later real edits —
    // including a later Reset to Default, which reloads through the same path.
    property bool _settingsReady: false

    Connections {
        target: settingsManager
        function onSettingsChanged() {
            root._settingsReady = true
        }
        function onLockTimerMinutesChanged() {
            if (root._settingsReady) root.applyLockTimer(settingsManager.lockTimerMinutes)
        }
        function onIdleSuspendMinutesChanged() {
            if (root._settingsReady) root.applyIdleSuspend(settingsManager.idleSuspendMinutes)
        }
        function onIdleDpmsMinutesChanged() {
            if (root._settingsReady) root.applyIdleDpms(settingsManager.idleDpmsMinutes)
        }
    }
}
