import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import "../ui" as UI
import "../../lib" as Theme

Item {
    id: root
    
    property var musicManager
    property var cavaManager
    property var theme
    property var icons
    required property var modeManager
    
    readonly property color extractedColor: musicManager ? musicManager.accentColor : (theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))

    width: modeManager.scale(96)
    height: modeManager.scale(96)
    Layout.preferredWidth: width
    Layout.preferredHeight: height
    
    property bool hasArt: root.musicManager && root.musicManager.artUrl !== ""

    Rectangle {
        id: artBackground
        anchors.centerIn: parent
        width: modeManager.scale(80)
        height: modeManager.scale(80)
        radius: root.hasArt ? modeManager.scale(12) : width / 2
        color: "transparent"
        border.width: 0
        z: 1

        Behavior on radius {
            NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
        }

        scale: 1.0

        Image {
            id: albumArt
            anchors.fill: parent
            source: root.musicManager && root.musicManager.artUrl ? root.musicManager.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: true
            cache: true

            onStatusChanged: {
                if (status === Image.Error && root.musicManager) {
                    root.musicManager.reportArtFailure(source.toString())
                }
            }
        }

        OpacityMask {
            anchors.fill: albumArt
            source: albumArt
            maskSource: Rectangle {
                width: albumArt.width
                height: albumArt.height
                radius: artBackground.radius
            }
            visible: root.hasArt
        }

        UI.SvgIcon {
            anchors.centerIn: parent
            width: modeManager.scale(48)
            height: modeManager.scale(48)
            source: root.icons ? root.icons.musicSvg : ""
            color: root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
            opacity: 0.5
            visible: !root.hasArt
        }
    }
}

