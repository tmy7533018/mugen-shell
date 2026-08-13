import QtQuick
import "./settings" as Settings

Item {
    id: root

    required property var modeManager
    property var theme
    required property var settingsManager
    required property var blurPresets
    required property string currentPreset
    required property bool isLoadingPresets
    required property var notificationSounds
    required property var timerSounds
    property string soundsDir: ""
    property string timerSoundsDir: ""

    signal applyPreset(string name)
    signal applySound(string name)
    signal applyTimerSound(string name)
    signal openYuraSettings()

    readonly property var categories: [
        { id: "appearance", label: "Appearance",   types: ["theme", "moduleBackground", "blur", "animation", "dateFormat", "clock", "weather", "calendarWeekStart", "barLayout"] },
        { id: "sound",      label: "Sound",        types: ["notificationSound", "timerSound"] },
        { id: "notifications", label: "Notifications", types: ["doNotDisturb", "notificationTimeout"] },
        { id: "timer",      label: "Timer & Lock", types: ["timer", "lockTimer", "idlePower"] },
        { id: "system",     label: "System",       types: ["battery", "workspaces", "launcherTerminal", "displayMonitor", "shortcuts"] },
        { id: "yura",       label: "Yura →",       action: "yura-settings" },
        { id: "reset",      label: "Reset",        types: ["reset"], danger: true }
    ]

    function sectionFor(type) {
        switch (type) {
            case "theme":             return themeSection
            case "blur":              return blurSection
            case "timer":             return timerSection
            case "moduleBackground":  return moduleBackgroundSection
            case "battery":           return batterySection
            case "animation":         return animationSection
            case "notificationSound": return notificationSoundSection
            case "timerSound":        return timerSoundSection
            case "lockTimer":         return lockTimerSection
            case "idlePower":         return idlePowerSection
            case "dateFormat":        return dateFormatSection
            case "clock":             return clockSection
            case "weather":           return weatherSection
            case "calendarWeekStart": return calendarWeekStartSection
            case "barLayout":         return barLayoutSection
            case "doNotDisturb":      return doNotDisturbSection
            case "notificationTimeout": return notificationTimeoutSection
            case "launcherTerminal":  return launcherTerminalSection
            case "workspaces":        return workspaceSection
            case "displayMonitor":    return displayMonitorSection
            case "shortcuts":         return shortcutsSection
            case "reset":             return resetSection
            default:                  return null
        }
    }

    Settings.SettingsFrame {
        anchors.fill: parent
        theme: root.theme
        categories: root.categories
        resolveSection: root.sectionFor
        onCategoryAction: action => {
            if (action === "yura-settings") root.openYuraSettings()
        }
    }

    Component { id: themeSection; Settings.ThemeSection {
        theme: root.theme
        modeManager: root.modeManager
    }}
    Component { id: blurSection; Settings.BlurSection {
        theme: root.theme
        modeManager: root.modeManager
        presets: root.blurPresets
        currentPreset: root.currentPreset
        isLoadingPresets: root.isLoadingPresets
        onApplyPreset: name => root.applyPreset(name)
    }}
    Component { id: timerSection; Settings.TimerSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: moduleBackgroundSection; Settings.ModuleBackgroundSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: batterySection; Settings.BatterySection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: animationSection; Settings.AnimationSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: notificationSoundSection; Settings.SoundSection {
        theme: root.theme
        modeManager: root.modeManager
        label: "Notification Sound"
        currentSound: root.settingsManager ? root.settingsManager.notificationSound : "None"
        sounds: root.notificationSounds
        folderPath: root.soundsDir
        onApplySound: name => root.applySound(name)
    }}
    Component { id: timerSoundSection; Settings.SoundSection {
        theme: root.theme
        modeManager: root.modeManager
        label: "Timer Sound"
        currentSound: root.settingsManager ? root.settingsManager.timerSound : "None"
        sounds: root.timerSounds
        folderPath: root.timerSoundsDir
        onApplySound: name => root.applyTimerSound(name)
    }}
    Component { id: lockTimerSection; Settings.LockTimerSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: dateFormatSection; Settings.DateFormatSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: clockSection; Settings.ClockSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: weatherSection; Settings.WeatherSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: calendarWeekStartSection; Settings.CalendarWeekStartSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: barLayoutSection; Settings.BarLayoutSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: idlePowerSection; Settings.IdlePowerSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: doNotDisturbSection; Settings.DoNotDisturbSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: notificationTimeoutSection; Settings.NotificationTimeoutSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: launcherTerminalSection; Settings.LauncherTerminalSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: workspaceSection; Settings.WorkspaceSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: displayMonitorSection; Settings.DisplayMonitorSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
    Component { id: shortcutsSection; Settings.KeyboardShortcutsSection {
        theme: root.theme
        modeManager: root.modeManager
    }}
    Component { id: resetSection; Settings.ResetSection {
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }}
}
