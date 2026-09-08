import QtQuick
import "../../lib" as Theme

Rectangle {
    id: button

    property var theme
    property string label: ""
    property int buttonWidth: 84
    property int buttonHeight: 28
    property int fontSize: 11
    property color tint: Qt.rgba(0.55, 0.55, 0.65, 0.22)
    property color tintHover: Qt.rgba(0.55, 0.55, 0.65, 0.32)

    signal clicked()

    implicitWidth: buttonWidth
    implicitHeight: buttonHeight
    radius: height / 2
    color: buttonMouse.containsMouse ? tintHover : tint

    Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

    Text {
        anchors.centerIn: parent
        text: button.label
        color: button.theme ? button.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        font.pixelSize: button.fontSize
        font.family: "M PLUS 2"
        font.weight: Font.Medium
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
