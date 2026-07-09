import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager

    width: parent ? parent.width : 420
    height: 64
    color: linkArea.containsMouse
        ? (theme ? theme.surfaceInsetCardHover : Qt.rgba(0, 0, 0, 0.45))
        : (theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25))
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function openShortcuts() {
        Hyprland.dispatch("exec ~/.config/quickshell/mugen-shell/scripts/toggle-shortcuts.sh")
    }

    MouseArea {
        id: linkArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: section.openShortcuts()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Keyboard Shortcuts"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.weight: Font.Normal
            font.letterSpacing: 0.5
        }

        Text {
            text: "Super+/"
            color: section.theme ? section.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
            font.pixelSize: 11
            font.family: "M PLUS 2"
            font.weight: Font.Medium
            font.letterSpacing: 0.5
            opacity: 0.85
        }

        Text {
            text: "›"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 18
            font.family: "M PLUS 2"
            opacity: linkArea.containsMouse ? 1.0 : 0.6

            Behavior on opacity { NumberAnimation { duration: Theme.Motion.micro } }
        }
    }
}
