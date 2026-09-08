import QtQuick
import QtQuick.Layouts
import "../../lib" as Theme

Rectangle {
    id: pill

    property var theme
    property string label: ""

    signal clicked()

    Layout.preferredWidth: pillText.implicitWidth + 20
    Layout.preferredHeight: 24
    radius: 12
    z: 3
    color: pillArea.containsMouse
        ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.18) : Qt.rgba(0.65, 0.55, 0.85, 0.18))
        : "transparent"
    border.width: 1
    border.color: theme
        ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, pillArea.containsMouse ? 0.65 : 0.3)
        : Qt.rgba(0.65, 0.55, 0.85, pillArea.containsMouse ? 0.65 : 0.3)

    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
    Behavior on border.color { ColorAnimation { duration: Theme.Motion.micro } }

    Text {
        id: pillText
        anchors.centerIn: parent
        text: pill.label
        textFormat: Text.PlainText
        color: pill.theme ? pill.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
        font.pixelSize: 11
        font.weight: Font.Medium
        font.family: "M PLUS 2"
        font.letterSpacing: 0.3
    }

    MouseArea {
        id: pillArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }
}
