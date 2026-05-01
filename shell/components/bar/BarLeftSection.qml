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

    Item {
        id: clockContainer
        implicitWidth: clockComponent.implicitWidth
        implicitHeight: clockComponent.implicitHeight
        Layout.alignment: Qt.AlignVCenter
        
        property color glowColor: root.theme
            ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.6)
            : Qt.rgba(0.65, 0.55, 0.85, 0.6)

        UI.Clock {
            id: clockComponent
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: scaled(-1)
            modeManager: root.modeManager
            theme: root.theme
            typo: root.typo
            showSeconds: false
            isHovered: clockMouseArea.containsMouse
            glowColor: clockContainer.glowColor
            opacity: clockMouseArea.containsMouse ? 1.0 : 0.6
            scale: clockMouseArea.containsMouse ? 1.3 : 1.0
            
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
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.modeManager) {
                    root.modeManager.switchMode("calendar")
                }
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

