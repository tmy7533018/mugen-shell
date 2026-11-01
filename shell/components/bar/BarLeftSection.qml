import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../lib" as Theme
import "../ui" as UI
import "../content/ai" as Ai
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
        const p = aiContainer.mapToItem(null, 0, 0)
        return { x: p.x, y: p.y, size: aiContainer.width }
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

    Item {
        id: aiContainer
        visible: root.yuraShown
        implicitWidth: scaled(24)
        implicitHeight: scaled(24)
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: 0
        Layout.rightMargin: 0

        Ai.AmbientOrb {
            id: aiOrb
            anchors.centerIn: parent
            width: scaled(26)
            height: scaled(26)
            orbColor: root.theme ? root.theme.glowTertiary : Qt.rgba(0.95, 0.72, 0.74, 0.9)
            streaming: root.aiThinking
            showHalo: true
            haloScale: 1.5
            haloOpacity: aiMouseArea.containsMouse ? 0.7 : 0.45
            coreOpacity: aiMouseArea.containsMouse ? 0.9 : 0.72
            corePointCount: 32
            coreWaveAmplitude: 0.8
            haloPointCount: 24
            haloWaveAmplitude: 1.2
            breathEnabled: root.settingsManager ? root.settingsManager.yuraIdleBreath : true
            active: !root.aiPanelOpen
            scale: aiMouseArea.containsMouse ? 1.08 : 1.0
            opacity: root.aiPanelOpen ? 0 : 1

            Behavior on opacity {
                enabled: aiOrb.opacity < 1
                NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.InOutCubic }
            }
            Behavior on haloOpacity { NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic } }
            Behavior on coreOpacity { NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.Motion.slow; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: aiMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.modeManager) {
                    root.modeManager.switchMode("ai")
                }
            }
        }
    }

}

