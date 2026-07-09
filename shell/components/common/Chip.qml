import QtQuick
import "../../lib" as Theme

Rectangle {
    id: chip

    property var theme
    property string label: ""
    property bool selected: false
    signal clicked()

    width: chipText.implicitWidth + 16
    height: 22
    radius: 11
    color: selected
        ? (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.45) : Qt.rgba(0.65, 0.55, 0.85, 0.45))
        : (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
    border.width: 1
    border.color: selected
        ? (theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95))
        : Qt.rgba(1, 1, 1, 0.10)

    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

    Text {
        id: chipText
        anchors.centerIn: parent
        text: chip.label
        color: chip.theme ? chip.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        font.pixelSize: 10
        font.family: "M PLUS 2"
    }

    MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
