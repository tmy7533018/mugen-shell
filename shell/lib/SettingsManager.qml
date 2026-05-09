import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: settingsManager

    readonly property string configDir: {
        let xdg = Quickshell.env("XDG_CONFIG_HOME")
        if (!xdg || xdg === "") xdg = Quickshell.env("HOME") + "/.config"
        return xdg + "/mugen-shell"
    }

    // defaultSettingsFile stays in shellDir — it's a read-only template
    // shipped with the project (will become a /nix/store path under flake).
    property string defaultSettingsFile: Quickshell.shellDir + "/settings.default.json"
    property string userSettingsFile: configDir + "/settings.json"

    // 0 = disabled, otherwise the idle timeout (ms) before a mode auto-closes.
    property int autoCloseTimerInterval: 5000
    property bool barGradientEnabled: true
    property bool batteryIndicatorEnabled: false
    property string animationSpeed: "normal"  // "slow", "normal", "fast", "instant"
    property real animationDurationMultiplier: 1.0
    property string notificationSound: "None"  // filename in assets/sounds/, or "None"
    property string timerSound: "None"  // filename in assets/sounds/, played when a countdown finishes
    property int lockTimerMinutes: 10  // hypridle screen-lock idle timeout in minutes
    property string dateFormat: "ddd M/d"  // Qt date tokens: d, dd, ddd, dddd, M, MM, MMM, MMMM, yy, yyyy
    property string barAiModel: ""  // "" = follow the backend default (last model selected in float)
    property string yuraPanelSide: "left"  // "left" | "right"

    // Suppress save while we are applying values that just came in from disk
    // (either initial load or an external write detected by the file watcher).
    property bool _applyingExternal: false

    signal settingsChanged()

    Component.onCompleted: {
        loadSettings()
    }

    function loadSettings() {
        readSettingsProcess.command = ["cat", userSettingsFile]
        readSettingsProcess.running = true
    }

    function saveSettings() {
        if (_applyingExternal) return

        let settings = {
            "autoCloseTimer": {
                "interval": autoCloseTimerInterval
            },
            "barBackground": {
                "gradientEnabled": barGradientEnabled
            },
            "batteryIndicator": {
                "enabled": batteryIndicatorEnabled
            },
            "animations": {
                "speed": animationSpeed,
                "durationMultiplier": animationDurationMultiplier
            },
            "notification": {
                "sound": notificationSound
            },
            "timer": {
                "sound": timerSound
            },
            "lockTimer": {
                "minutes": lockTimerMinutes
            },
            "date": {
                "format": dateFormat
            },
            "ai": {
                "barModel": barAiModel
            },
            "yura": {
                "panelSide": yuraPanelSide
            }
        }

        let jsonString = JSON.stringify(settings, null, 2)

        saveSettingsProcess.command = [
            "bash", "-c",
            "mkdir -p \"" + configDir + "\" && echo '" + jsonString + "' > \"" + userSettingsFile + "\""
        ]
        saveSettingsProcess.running = true
    }

    function resetToDefault() {
        resetProcess.command = [
            "bash", "-c",
            "mkdir -p \"" + configDir + "\" && cp \"" + defaultSettingsFile + "\" \"" + userSettingsFile + "\""
        ]
        resetProcess.running = true
    }

    function applySettingsFromJson(jsonString) {
        try {
            let settings = JSON.parse(jsonString)

            _applyingExternal = true

            if (settings.autoCloseTimer) {
                if (settings.autoCloseTimer.interval !== undefined) {
                    autoCloseTimerInterval = settings.autoCloseTimer.interval
                }
                // Migrate legacy "enabled: false" to interval = 0
                if (settings.autoCloseTimer.enabled === false) {
                    autoCloseTimerInterval = 0
                }
            }

            if (settings.barBackground) {
                if (settings.barBackground.gradientEnabled !== undefined) {
                    barGradientEnabled = settings.barBackground.gradientEnabled
                }
            }

            if (settings.batteryIndicator) {
                if (settings.batteryIndicator.enabled !== undefined) {
                    batteryIndicatorEnabled = settings.batteryIndicator.enabled
                }
            }

            if (settings.animations) {
                if (settings.animations.speed !== undefined) {
                    animationSpeed = settings.animations.speed
                }
                if (settings.animations.durationMultiplier !== undefined) {
                    animationDurationMultiplier = settings.animations.durationMultiplier
                }
            }

            if (settings.notification) {
                if (settings.notification.sound !== undefined) {
                    notificationSound = settings.notification.sound
                }
            }

            if (settings.timer) {
                if (settings.timer.sound !== undefined) {
                    timerSound = settings.timer.sound
                }
            }

            if (settings.lockTimer) {
                if (settings.lockTimer.minutes !== undefined) {
                    lockTimerMinutes = settings.lockTimer.minutes
                }
            }

            if (settings.date) {
                if (settings.date.format !== undefined) {
                    dateFormat = settings.date.format
                }
            }

            if (settings.ai) {
                if (settings.ai.barModel !== undefined) {
                    barAiModel = settings.ai.barModel
                }
            }

            if (settings.yura) {
                if (settings.yura.panelSide !== undefined) {
                    yuraPanelSide = settings.yura.panelSide
                }
            }

            updateAnimationMultiplier()

            _applyingExternal = false

            settingsChanged()
        } catch (e) {
            _applyingExternal = false
            console.error("Failed to parse settings JSON:", e)
        }
    }

    function updateAnimationMultiplier() {
        switch (animationSpeed) {
            case "slow":
                animationDurationMultiplier = 1.5
                break
            case "normal":
                animationDurationMultiplier = 1.0
                break
            case "fast":
                animationDurationMultiplier = 0.6
                break
            case "instant":
                animationDurationMultiplier = 0.0
                break
            default:
                animationDurationMultiplier = 1.0
        }
    }

    // Re-read on external writes (e.g. from the floating Settings window
    // in a separate Quickshell process) so every shell instance stays in sync.
    property FileView settingsWatcher: FileView {
        path: settingsManager.userSettingsFile
        watchChanges: true
        preload: false
        printErrors: false

        onFileChanged: {
            settingsManager.loadSettings()
        }
    }

    property Process readSettingsProcess: Process {
        command: []
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => {
                readSettingsProcess.output += data
            }
        }

        onExited: (exitCode) => {
            if (exitCode === 0 && readSettingsProcess.output.trim().length > 0) {
                applySettingsFromJson(readSettingsProcess.output)
            } else {
                readDefaultSettingsProcess.running = true
            }
            readSettingsProcess.output = ""
        }
    }

    property Process readDefaultSettingsProcess: Process {
        command: ["cat", settingsManager.defaultSettingsFile]
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => {
                readDefaultSettingsProcess.output += data
            }
        }

        onExited: (exitCode) => {
            if (exitCode === 0 && readDefaultSettingsProcess.output.trim().length > 0) {
                applySettingsFromJson(readDefaultSettingsProcess.output)
                // Copy defaults to user settings so future loads use the user file
                saveSettings()
            }
            readDefaultSettingsProcess.output = ""
        }
    }

    property Process saveSettingsProcess: Process {
        command: []
        running: false

        stdout: SplitParser {
            onRead: data => {}
        }

        stderr: SplitParser {
            onRead: data => {}
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                settingsChanged()
            }
        }
    }

    property Process resetProcess: Process {
        command: []
        running: false

        stdout: SplitParser {
            onRead: data => {}
        }

        stderr: SplitParser {
            onRead: data => {}
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                loadSettings()
            }
        }
    }
}
