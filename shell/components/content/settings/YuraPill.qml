import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

Rectangle {
    id: root

    property var theme
    property bool on: false
    property int pillWidth: 36
    property int pillHeight: 20
    property int knobSize: 14
    property bool interactive: true
    property color onFill: root.theme
        ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.55)
        : Qt.rgba(0.65, 0.55, 0.85, 0.55)
    property color onBorder: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95)

    signal clicked()

    Layout.preferredWidth: root.pillWidth
    Layout.preferredHeight: root.pillHeight
    Layout.alignment: Qt.AlignVCenter
    radius: root.pillHeight / 2

    color: root.on ? root.onFill : Qt.rgba(0.3, 0.3, 0.36, 0.5)
    border.width: 1
    border.color: root.on ? root.onBorder : Qt.rgba(1, 1, 1, 0.10)
    Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

    Rectangle {
        width: root.knobSize
        height: root.knobSize
        radius: root.knobSize / 2
        color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
        y: 3
        x: root.on ? root.width - width - 3 : 3
        Behavior on x { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        visible: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
