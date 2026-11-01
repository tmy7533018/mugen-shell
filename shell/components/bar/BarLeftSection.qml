import QtQuick
import QtQuick.Layouts
import "../ui" as UI
import "./left" as Left

RowLayout {
    id: root
    
    spacing: 4
    Layout.alignment: Qt.AlignVCenter
    
    property var theme
    property var typo
    property var icons
    property var modeManager
    property var audioManager
    property var musicPlayerManager
    property var cavaManager
    property var settingsManager
    property var timerManager
    property var weatherManager
    property bool aiThinking: false
    property bool aiPanelOpen: false
    readonly property bool yuraShown: !root.settingsManager || root.settingsManager.yuraEnabled

    function aiOrbScreenRect() {
        return yuraOrb.screenRect()
    }

    function scaled(val) {
        if (modeManager) return modeManager.barScale(val)
        return val
    }
    
    Left.LauncherButton {
        theme: root.theme
        typo: root.typo
        icons: root.icons
        modeManager: root.modeManager
    }
    
    BarSeparator { theme: root.theme; modeManager: root.modeManager }

    Left.ClockDate {
        theme: root.theme
        typo: root.typo
        modeManager: root.modeManager
        settingsManager: root.settingsManager
    }

    Left.TimerPill {
        Layout.leftMargin: root.scaled(8)
        theme: root.theme
        typo: root.typo
        modeManager: root.modeManager
        timerManager: root.timerManager
    }

    BarSeparator { theme: root.theme; modeManager: root.modeManager; visible: root.weatherManager && root.weatherManager.enabled && root.weatherManager.ready }

    Left.WeatherIndicator {
        theme: root.theme
        typo: root.typo
        icons: root.icons
        modeManager: root.modeManager
        weatherManager: root.weatherManager
    }

    BarSeparator { theme: root.theme; modeManager: root.modeManager }

    Left.WallpaperButton {
        theme: root.theme
        typo: root.typo
        icons: root.icons
        modeManager: root.modeManager
    }
    
    UI.ScreenshotButton {
        Layout.leftMargin: root.scaled(4)
        theme: root.theme
        icons: root.icons
        modeManager: root.modeManager
    }
    
    BarSeparator { theme: root.theme; modeManager: root.modeManager }

    Left.VolumeIndicator {
        theme: root.theme
        typo: root.typo
        icons: root.icons
        modeManager: root.modeManager
        audioManager: root.audioManager
    }
    
    Left.MusicButton {
        Layout.leftMargin: root.scaled(4)
        theme: root.theme
        typo: root.typo
        icons: root.icons
        modeManager: root.modeManager
        musicPlayerManager: root.musicPlayerManager
        cavaManager: root.cavaManager
    }

    BarSeparator { theme: root.theme; modeManager: root.modeManager; visible: root.yuraShown }

    Left.YuraOrb {
        id: yuraOrb
        theme: root.theme
        modeManager: root.modeManager
        settingsManager: root.settingsManager
        aiThinking: root.aiThinking
        aiPanelOpen: root.aiPanelOpen
    }

}

