import QtQuick
import QtQuick.Layouts
import "../ui" as UI
import "../../lib" as Theme

Rectangle {
    id: chip

    property var theme
    property string label: ""
    property bool selected: false
    property int chipHeight: 22
    property int hPadding: 16
    property int fontSize: 10
    property string iconSource: ""
    property real iconRotation: 0
    readonly property int iconSize: Math.round(chipHeight * 0.40)
    signal clicked()

    width: chipRow.implicitWidth + hPadding
    height: chipHeight
    radius: height / 2
    color: selected
        ? (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.45) : Qt.rgba(0.65, 0.55, 0.85, 0.45))
        : (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
    border.width: 1
    border.color: selected
        ? (theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95))
        : Qt.rgba(1, 1, 1, 0.10)

    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

    RowLayout {
        id: chipRow
        anchors.centerIn: parent
        spacing: chip.iconSource === "" ? 0 : Math.round(chip.hPadding * 0.4)

        Text {
            id: chipText
            text: chip.label
            color: chip.theme ? chip.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            font.pixelSize: chip.fontSize
            font.family: "M PLUS 2"
        }

        UI.SvgIcon {
            Layout.preferredWidth: chip.iconSize
            Layout.preferredHeight: chip.iconSize
            visible: chip.iconSource !== ""
            source: chip.iconSource
            color: chip.theme ? chip.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            rotation: chip.iconRotation

            Behavior on rotation {
                NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
            }
        }
    }

    MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
