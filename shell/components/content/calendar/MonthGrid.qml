pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

GridLayout {
    id: root

    required property var theme
    property int year: 1970
    property int month: 1
    property int weekStart: 0
    property int todayDay: 0
    property int todayMonth: 0
    property int todayYear: 0
    property string selectedDate: ""
    property var eventsByDate: ({})

    signal daySelected(int day)

    columns: 7
    rowSpacing: 4
    columnSpacing: 0

    Repeater {
        // 42 keeps the six rows from reflowing on a short month.
        model: Theme.CalendarGrid.cells(root.year, root.month - 1, root.weekStart, 42)

        delegate: Item {
            id: cell

            required property var modelData

            Layout.fillWidth: true
            Layout.preferredHeight: 46

            readonly property int dayNumber: modelData.day
            readonly property bool isCurrentMonth: modelData.inMonth

            property bool isToday: isCurrentMonth
                && dayNumber === root.todayDay
                && root.month === root.todayMonth
                && root.year === root.todayYear

            property string cellDateKey: isCurrentMonth ? modelData.key : ""
            property bool isSelected: cellDateKey === root.selectedDate
            property bool hasEvents: cellDateKey ? (root.eventsByDate[cellDateKey] || []).length > 0 : false

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 4
                width: 28
                height: 28
                radius: 14
                color: cellHover.containsMouse && !cell.isToday && !cell.isSelected
                    ? Qt.rgba(1, 1, 1, 0.06)
                    : "transparent"
                border.width: cell.isToday ? 1.4 : (cell.isSelected ? 1 : 0)
                border.color: cell.isToday
                    ? (root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                    : Qt.rgba(0.75, 0.75, 0.8, 0.5)

                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                Behavior on border.color { ColorAnimation { duration: Theme.Motion.micro } }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 4 + 14 - implicitHeight / 2
                text: cell.dayNumber > 0 ? cell.dayNumber : ""
                color: {
                    if (cell.isToday) return Qt.rgba(0.98, 0.98, 1.0, 1.0)
                    return root.theme ? root.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.85)
                }
                opacity: cell.isCurrentMonth ? 1.0 : 0.45
                font.pixelSize: 13
                font.weight: cell.isToday || cell.isSelected ? Font.Medium : Font.Light
                font.family: "M PLUS 2"
            }

            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 38
                anchors.horizontalCenter: parent.horizontalCenter
                width: 4
                height: 4
                radius: 2
                color: root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
                visible: cell.hasEvents && cell.isCurrentMonth
                opacity: 0.8
            }

            MouseArea {
                id: cellHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: cell.dayNumber > 0 && cell.isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: cell.dayNumber > 0 && cell.isCurrentMonth
                onClicked: root.daySelected(cell.dayNumber)
            }
        }
    }
}
