import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../lib" as Theme
import "../ui" as UI
import "../common" as Common
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
    property var screenshotManager
    property var audioManager
    property var musicPlayerManager
    property var cavaManager
    property var settingsManager
    property var timerManager
    property bool aiThinking: false
    property bool aiListening: false
    property bool aiSpeaking: false

    function scaled(val) {
        if (modeManager) return modeManager.scale(val)
        return val
    }
    
    component Separator: UI.SvgIcon {
        width: 1
        height: scaled(16)
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: scaled(-4)
        Layout.rightMargin: scaled(-4)
        source: Quickshell.shellDir + "/assets/icons/divider.svg"
        color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.40)
        opacity: 0.5
    }
    
    Common.IconButton {
        modeManager: root.modeManager
        iconSource: root.icons ? (root.icons.iconData.launcher.type === "svg" ? root.icons.iconData.launcher.value : "") : ""
        iconText: root.icons ? (root.icons.iconData.launcher.type === "text" ? root.icons.iconData.launcher.value : "") : ""
        iconColor: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        fontSize: root.typo ? root.typo.clockStyle.size : 14
        fontFamily: root.typo ? root.typo.clockStyle.family : "M PLUS 2"
        fontWeight: root.typo ? root.typo.clockStyle.weight : Font.Normal
        letterSpacing: root.typo ? root.typo.clockStyle.letterSpacing : 0
        
        onClicked: {
            if (root.modeManager) {
                root.modeManager.switchMode("launcher")
            }
        }
    }
    
    Separator {}

    ColumnLayout {
        id: timeBlock
        Layout.alignment: Qt.AlignVCenter
        spacing: scaled(-2)

        property color glowColor: root.theme
            ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.6)
            : Qt.rgba(0.65, 0.55, 0.85, 0.6)

        Item {
            id: clockContainer
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: clockComponent.implicitWidth
            Layout.preferredHeight: clockComponent.implicitHeight

            UI.Clock {
                id: clockComponent
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                modeManager: root.modeManager
                theme: root.theme
                typo: root.typo
                showSeconds: false
                isHovered: clockMouseArea.containsMouse
                glowColor: timeBlock.glowColor
                opacity: clockMouseArea.containsMouse ? 1.0 : 0.6
                scale: clockMouseArea.containsMouse ? 1.15 : 1.0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: Theme.Motion.slow; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                id: clockMouseArea
                anchors.fill: parent
                anchors.margins: scaled(-4)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.modeManager) root.modeManager.switchMode("timer")
                }
            }
        }

        Item {
            id: dateContainer
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: dateComponent.implicitWidth
            Layout.preferredHeight: dateComponent.implicitHeight

            UI.DateLabel {
                id: dateComponent
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                modeManager: root.modeManager
                theme: root.theme
                typo: root.typo
                format: root.settingsManager ? root.settingsManager.dateFormat : "ddd M/d"
                isHovered: dateMouseArea.containsMouse
                glowColor: timeBlock.glowColor
                opacity: dateMouseArea.containsMouse ? 1.0 : 0.6
                scale: dateMouseArea.containsMouse ? 1.15 : 1.0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: Theme.Motion.slow; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                id: dateMouseArea
                anchors.fill: parent
                anchors.margins: scaled(-4)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.modeManager) root.modeManager.closeAllModes()
                    Theme.Hypr.exec("~/.config/quickshell/mugen-shell/scripts/toggle-calendar.sh")
                }
            }
        }
    }

    Item {
        id: timerPill
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: scaled(8)
        Layout.preferredWidth: visible ? pillText.implicitWidth + scaled(22) : 0
        Layout.preferredHeight: scaled(26)
        visible: root.timerManager && (root.timerManager.running || root.timerManager.alerting)

        function _formatRemaining(sec) {
            if (sec < 0) sec = 0
            const h = Math.floor(sec / 3600)
            const m = Math.floor((sec % 3600) / 60)
            const s = sec % 60
            const pad = n => n < 10 ? "0" + n : "" + n
            if (h > 0) return h + ":" + pad(m) + ":" + pad(s)
            return pad(m) + ":" + pad(s)
        }

        readonly property bool urgent: root.timerManager
            && root.timerManager.running
            && !root.timerManager.paused
            && root.timerManager.remainingSec > 0
            && root.timerManager.remainingSec <= 10

        Rectangle {
            anchors.fill: parent
            radius: scaled(13)
            property color accent: timerPill.urgent
                ? Qt.rgba(0.95, 0.40, 0.45, 1)
                : (root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
            color: timerPill.urgent
                ? Qt.rgba(accent.r, accent.g, accent.b, pillHover.containsMouse ? 0.42 : 0.32)
                : (pillHover.containsMouse
                    ? Qt.rgba(accent.r, accent.g, accent.b, 0.30)
                    : Qt.rgba(accent.r, accent.g, accent.b, 0.18))
            border.width: 1
            border.color: timerPill.urgent
                ? Qt.rgba(accent.r, accent.g, accent.b, 0.72)
                : Qt.rgba(accent.r, accent.g, accent.b, root.timerManager && root.timerManager.paused ? 0.30 : 0.50)
            opacity: root.timerManager && root.timerManager.paused ? 0.65 : 1.0

            Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }
            Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }
        }

        Text {
            id: pillText
            anchors.centerIn: parent
            text: {
                if (!root.timerManager) return "00:00"
                if (root.timerManager.alerting) return "DONE"
                return timerPill._formatRemaining(root.timerManager.remainingSec)
            }
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
            opacity: pillHover.containsMouse ? 1.0 : 0.6
            font.pixelSize: root.typo ? scaled(root.typo.clockStyle.size * 0.78) : scaled(11)
            font.weight: Font.Medium
            font.family: root.typo ? root.typo.clockStyle.family : "M PLUS 2"
            font.letterSpacing: 0.5

            Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }
        }

        MouseArea {
            id: pillHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.modeManager) root.modeManager.switchMode("timer")
            }
        }
    }

    Separator {}

    Common.IconButton {
        modeManager: root.modeManager
        iconSource: root.icons ? (root.icons.iconData.wallpaper.type === "svg" ? root.icons.iconData.wallpaper.value : "") : ""
        iconText: root.icons ? (root.icons.iconData.wallpaper.type === "text" ? root.icons.iconData.wallpaper.value : "") : ""
        iconColor: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        fontSize: root.typo ? root.typo.clockStyle.size : 14
        fontFamily: root.typo ? root.typo.clockStyle.family : "M PLUS 2"
        fontWeight: root.typo ? root.typo.clockStyle.weight : Font.Normal
        letterSpacing: root.typo ? root.typo.clockStyle.letterSpacing : 0
        
        onClicked: {
            if (root.modeManager) {
                root.modeManager.switchMode("wallpaper")
            }
        }
    }
    
    UI.ScreenshotButton {
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: scaled(4)
        theme: root.theme
        icons: root.icons
        modeManager: root.modeManager
        screenshotManager: root.screenshotManager
    }
    
    Separator {}

    Left.VolumeIndicator {
        theme: root.theme
        typo: root.typo
        icons: root.icons
        modeManager: root.modeManager
        audioManager: root.audioManager
    }
    
    Left.MusicButton {
        theme: root.theme
        typo: root.typo
        icons: root.icons
        modeManager: root.modeManager
        musicPlayerManager: root.musicPlayerManager
        cavaManager: root.cavaManager
    }

    Separator {}

    Item {
        id: aiContainer
        implicitWidth: scaled(24)
        implicitHeight: scaled(24)
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: 0
        Layout.rightMargin: 0

        // The orb itself is the bar icon (no separate glyph), so it stays
        // active and drives every Yura state off its own properties below.
        Ai.AmbientOrb {
            id: aiOrb
            anchors.centerIn: parent
            width: scaled(26)
            height: scaled(26)
            orbColor: root.aiListening
                ? (root.theme ? root.theme.glowSecondary : Qt.rgba(0.55, 0.75, 0.85, 0.9))
                : (root.theme ? root.theme.glowTertiary : Qt.rgba(0.95, 0.72, 0.74, 0.9))
            streaming: root.aiThinking
            speaking: root.aiSpeaking
            showHalo: true
            haloScale: 1.5
            haloOpacity: aiMouseArea.containsMouse ? 0.7 : 0.45
            coreOpacity: aiMouseArea.containsMouse ? 0.9 : 0.72
            corePointCount: 32
            coreWaveAmplitude: 0.8
            haloPointCount: 24
            haloWaveAmplitude: 1.2
            rippleMaxScale: 1.8
            breathEnabled: root.settingsManager ? root.settingsManager.yuraIdleBreath : true
            active: true
            scale: aiMouseArea.containsMouse ? 1.08 : 1.0

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

