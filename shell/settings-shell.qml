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
        settings: settingsManager

        // This is a window over other apps, not glass over the wallpaper, so it takes the bar's colour.
        windowTint: settingsManager.barSurfaceCustom
            ? Qt.hsla(settingsManager.barSurfaceHue,
                      settingsManager.barSurfaceSaturation,
                      settingsManager.barSurfaceLightness,
                      settingsManager.barSurfaceOpacity)
            : (themeColors.themeMode === "light" ? themeColors.surfaceBaseLight
                                                : themeColors.surfaceBaseDark)
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

    property var notificationSounds: ["None"]
    property var timerSounds: ["None"]


    // Drag previews go straight to the compositor; the file only changes on release.
    property var pendingBlurPreview: null

    function blurLua(params) {
        const b = v => v ? "true" : "false"
        return "hl.config({ decoration = { blur = { enabled = " + b(params.enabled)
            + ", size = " + Math.round(params.size) + ", passes = " + Math.round(params.passes)
            + ", noise = " + params.noise + ", contrast = " + params.contrast
            + ", brightness = " + params.brightness + ", vibrancy = " + params.vibrancy
            + ", xray = " + b(params.xray) + ", ignore_opacity = " + b(params.ignoreOpacity)
            + ", new_optimizations = true } } })"
    }

    function previewBlur(params) {
        pendingBlurPreview = params
        if (!blurPreviewProcess.running) blurPreviewTimer.restart()
    }

    function applyBlur(params) {
        settingsManager.saveSettings()
        applyBlurProcess.command = ["bash", Quickshell.shellDir + "/scripts/blur.sh", "apply", JSON.stringify(params)]
        applyBlurProcess.running = true
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

    // Queued because concurrent writes to hypridle.conf would race.
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

    Process {
        id: openYuraSettingsProcess
        command: []
        running: false
    }

    Process {
        id: openUrlProcess
        command: []
        running: false
    }

    Process {
        id: applyBlurProcess
        command: []
        running: false
    }

    Timer {
        id: blurPreviewTimer
        interval: 50
        onTriggered: {
            if (!root.pendingBlurPreview || blurPreviewProcess.running) return
            blurPreviewProcess.command = ["hyprctl", "eval", root.blurLua(root.pendingBlurPreview)]
            root.pendingBlurPreview = null
            blurPreviewProcess.running = true
        }
    }

    Process {
        id: blurPreviewProcess
        command: []
        running: false
        onExited: () => { if (root.pendingBlurPreview) blurPreviewTimer.restart() }
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
        // Without an implicit size the window opens at its minimum, which fits four rows.
        implicitWidth: 1100
        implicitHeight: 740
        minimumSize: Qt.size(800, 540)

        Content.SettingsFloatingContent {
            id: settingsContent
            anchors.fill: parent
            modeManager: modeStub
            theme: themeColors
            settingsManager: settingsManager
            notificationSounds: root.notificationSounds
            timerSounds: root.timerSounds
            soundsDir: root.soundsDir
            timerSoundsDir: root.timerSoundsDir
            initialCategory: Quickshell.env("MUGEN_SETTINGS_CATEGORY") || ""

            onPreviewBlur: params => root.previewBlur(params)
            onApplyBlur: params => root.applyBlur(params)
            onApplySound: name => root.applyNotificationSound(name)
            onApplyTimerSound: name => root.applyTimerSound(name)
            onOpenYuraSettings: {
                openYuraSettingsProcess.command =
                    ["bash", Quickshell.shellDir + "/scripts/toggle-yura-settings.sh"]
                openYuraSettingsProcess.running = true
            }
            onOpenUrl: url => {
                openUrlProcess.command = ["xdg-open", url]
                openUrlProcess.running = true
            }
        }
    }

    Component.onCompleted: {
        loadNotificationSounds()
        loadTimerSounds()
    }

    // Without this the first load's property-changed storm would rewrite hypridle.conf and restart it.
    // Applied on save rather than on every slider step: each script restarts hypridle.
    property var _appliedHyprIdle: null

    Connections {
        target: settingsManager
        function onSettingsChanged() {
            let now = {
                lock: settingsManager.lockTimerMinutes,
                suspend: settingsManager.idleSuspendMinutes,
                dpms: settingsManager.idleDpmsMinutes
            }
            let prev = root._appliedHyprIdle
            root._appliedHyprIdle = now
            if (prev === null) return
            if (now.lock !== prev.lock) root.applyLockTimer(now.lock)
            if (now.suspend !== prev.suspend) root.applyIdleSuspend(now.suspend)
            if (now.dpms !== prev.dpms) root.applyIdleDpms(now.dpms)
        }
    }

    // Called by toggle-settings.sh so Super+/ switches category on an already-open window.
    IpcHandler {
        target: "settings"
        function openCategory(category: string) { settingsContent.openCategory(category) }
    }
}
