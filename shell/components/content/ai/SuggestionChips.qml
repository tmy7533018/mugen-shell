import QtQuick
import "../../../lib" as Theme

Column {
    id: root

    required property var modeManager
    required property var theme
    property var prompts: []

    signal promptChosen(string text)

    spacing: modeManager.scale(7)

    Repeater {
        model: root.prompts

        delegate: Rectangle {
            id: pill
            required property var modelData

            anchors.horizontalCenter: parent.horizontalCenter
            width: label.implicitWidth + root.modeManager.scale(30)
            height: root.modeManager.scale(30)
            radius: height / 2
            color: pillMouse.containsMouse
                ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.18) : Qt.rgba(0.65, 0.55, 0.85, 0.18))
                : Qt.rgba(1, 1, 1, 0.045)
            border.width: 1
            border.color: pillMouse.containsMouse
                ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5))
                : Qt.rgba(1, 1, 1, 0.09)

            Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

            Text {
                id: label
                anchors.centerIn: parent
                text: pill.modelData
                color: pillMouse.containsMouse
                    ? (root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))
                    : (root.theme ? root.theme.textSecondary : Qt.rgba(0.80, 0.80, 0.88, 0.80))
                font.pixelSize: root.modeManager.scale(12)
                font.family: "M PLUS 2"
                font.letterSpacing: 0.3

                Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
            }

            MouseArea {
                id: pillMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.promptChosen(pill.modelData)
            }
        }
    }
}
