import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../common" as Common
import "../../../lib" as Theme

Item {
    id: root

    required property var theme
    property string icon: "chevron-left"

    signal clicked()

    Layout.preferredWidth: 26
    Layout.preferredHeight: 26

    Common.GlowSvgIcon {
        anchors.centerIn: parent
        width: 18
        height: 18
        source: Quickshell.shellDir + "/assets/icons/" + root.icon + ".svg"
        color: hover.containsMouse
            ? (root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
            : (root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85))
        opacity: hover.containsMouse ? 1.0 : 0.65

        enableGlow: hover.containsMouse
        glowColor: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5)
        glowSamples: 16
        glowRadius: 8
        glowSpread: 0.4

        Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
        Behavior on opacity { NumberAnimation { duration: Theme.Motion.micro } }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
