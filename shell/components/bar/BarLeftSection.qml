import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../ui" as UI
import "../common" as Common
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
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
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
                format: root.settingsManager ? root.settingsManager.dateFormat : "M/d"
                isHovered: dateMouseArea.containsMouse
                glowColor: timeBlock.glowColor
                opacity: dateMouseArea.containsMouse ? 1.0 : 0.6
                scale: dateMouseArea.containsMouse ? 1.15 : 1.0

                Behavior on opacity {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                id: dateMouseArea
                anchors.fill: parent
                anchors.margins: scaled(-4)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.modeManager) {
                        root.modeManager.switchMode("calendar")
                    }
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
        visible: root.timerManager && root.timerManager.running

        function _formatRemaining(sec) {
            if (sec < 0) sec = 0
            const h = Math.floor(sec / 3600)
            const m = Math.floor((sec % 3600) / 60)
            const s = sec % 60
            const pad = n => n < 10 ? "0" + n : "" + n
            if (h > 0) return h + ":" + pad(m) + ":" + pad(s)
            return pad(m) + ":" + pad(s)
        }

        Rectangle {
            anchors.fill: parent
            radius: scaled(13)
            property color accent: root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
            color: pillHover.containsMouse
                ? Qt.rgba(accent.r, accent.g, accent.b, 0.30)
                : Qt.rgba(accent.r, accent.g, accent.b, 0.18)
            border.width: 1
            border.color: Qt.rgba(accent.r, accent.g, accent.b, root.timerManager && root.timerManager.paused ? 0.30 : 0.50)
            opacity: root.timerManager && root.timerManager.paused ? 0.65 : 1.0

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        Text {
            id: pillText
            anchors.centerIn: parent
            text: root.timerManager ? timerPill._formatRemaining(root.timerManager.remainingSec) : "00:00"
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
            font.pixelSize: root.typo ? scaled(root.typo.clockStyle.size * 0.78) : scaled(11)
            font.weight: Font.Medium
            font.family: root.typo ? root.typo.clockStyle.family : "M PLUS 2"
            font.letterSpacing: 0.5
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

        UI.SvgIcon {
            id: aiIconSvg
            anchors.centerIn: parent
            width: scaled(24)
            height: scaled(24)
            source: root.icons ? root.icons.aiSvg : ""
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            opacity: aiMouseArea.containsMouse ? 1.0 : 0.6
            scale: aiMouseArea.containsMouse ? 1.3 : 1.0

            Behavior on opacity {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }

            Behavior on scale {
                NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
            }
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

