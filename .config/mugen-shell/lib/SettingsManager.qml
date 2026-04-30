import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: settingsManager
    
    property string defaultSettingsFile: Quickshell.shellDir + "/settings.default.json"
    property string userSettingsFile: Quickshell.shellDir + "/.cache/settings.json"
    
    // 0 = disabled, otherwise the idle timeout (ms) before a mode auto-closes.
    property int autoCloseTimerInterval: 5000
    property bool barGradientEnabled: true
    property bool batteryIndicatorEnabled: false
    property string animationSpeed: "normal"  // "slow", "normal", "fast", "instant"
    property real animationDurationMultiplier: 1.0
    property string notificationSound: "None"  // filename in assets/sounds/, or "None"
    
    signal settingsChanged()
    
    Component.onCompleted: {
        loadSettings()
    }
    
    function loadSettings() {
        readSettingsProcess.command = ["cat", userSettingsFile]
        readSettingsProcess.running = true
    }
    
    function saveSettings() {
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
            }
        }
        
        let jsonString = JSON.stringify(settings, null, 2)
        
        saveSettingsProcess.command = [
            "bash", "-c",
            "mkdir -p \"" + Quickshell.shellDir + "/.cache\" && echo '" + jsonString + "' > \"" + userSettingsFile + "\""
        ]
        saveSettingsProcess.running = true
    }
    
    function resetToDefault() {
        resetProcess.command = [
            "bash", "-c",
            "cp \"" + defaultSettingsFile + "\" \"" + userSettingsFile + "\""
        ]
        resetProcess.running = true
    }
    
    function applySettingsFromJson(jsonString) {
        try {
            let settings = JSON.parse(jsonString)
            
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

            updateAnimationMultiplier()
            
            settingsChanged()
        } catch (e) {
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

