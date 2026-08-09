pragma ComponentBehavior: Bound

import QtQuick
import "../../lib" as Theme

Item {
    id: root

    property string fontFamily: "M PLUS 2"
    property color tint: "white"
    property color faintTint: Qt.rgba(1, 1, 1, 0.35)
    property color accent: "#a68cd9"

    // Recomputed by the owner's clock tick; a date is not a live property.
    property date today: new Date()
    property int weekStart: 0
    property var events: []

    readonly property real designPx: height / 221

    readonly property color chipTextColor: "#0f1016"

    readonly property string todayKey: Qt.formatDate(today, "yyyy-MM-dd")

    readonly property var weekdayLabels: {
        const names = ["S", "M", "T", "W", "T", "F", "S"]
        const out = []
        for (let i = 0; i < 7; i++) out.push(names[(i + weekStart) % 7])
        return out
    }

    // Keyed off the day, not the clock: a Repeater regenerates every cell on reassignment.
    readonly property var monthCells: Theme.CalendarGrid.cells(
        parseInt(todayKey.slice(0, 4), 10),
        parseInt(todayKey.slice(5, 7), 10) - 1, weekStart, 0)

    readonly property var eventDays: {
        const seen = ({})
        for (const e of events) if (e && e.date) seen[e.date] = true
        return seen
    }

    readonly property var todayEvents: {
        const out = []
        for (const e of events) if (e && e.date === todayKey) out.push(e)
        out.sort((a, b) => String(a.time || "").localeCompare(String(b.time || "")))
        return out
    }

    readonly property int nowMinutes: today.getHours() * 60 + today.getMinutes()

    function isPast(time) {
        const parts = String(time || "").split(":")
        if (parts.length !== 2) return false
        return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10) < nowMinutes
    }

    Column {
        id: monthColumn

        x: 22 * root.designPx
        // Centred: a five-row month under fixed top padding looks top-heavy.
        y: (root.height - height) / 2
        width: 190 * root.designPx
        spacing: 8 * root.designPx

        readonly property real cell: (width - 2 * root.designPx * 6) / 7

        Item {
            width: parent.width
            height: 12 * root.designPx

            Text {
                id: monthLabel
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                text: Qt.formatDate(root.today, "MMMM").toUpperCase()
                color: root.tint
                font.family: root.fontFamily
                font.weight: Font.Medium
                font.pixelSize: 12 * root.designPx
                font.letterSpacing: 12 * root.designPx * 0.04
            }

            Text {
                anchors.right: parent.right
                anchors.baseline: monthLabel.baseline
                text: Qt.formatDate(root.today, "yyyy")
                color: root.faintTint
                font.family: root.fontFamily
                font.pixelSize: 8 * root.designPx
                font.letterSpacing: 8 * root.designPx * 0.16
            }
        }

        Row {
            spacing: 2 * root.designPx

            Repeater {
                model: root.weekdayLabels

                Text {
                    required property string modelData

                    width: monthColumn.cell
                    height: 14 * root.designPx
                    text: modelData
                    color: root.faintTint
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: root.fontFamily
                    font.pixelSize: 8 * root.designPx
                    font.letterSpacing: 8 * root.designPx * 0.1
                }
            }
        }

        Grid {
            columns: 7
            spacing: 2 * root.designPx

            Repeater {
                model: root.monthCells

                Item {
                    id: dayCell
                    required property var modelData

                    readonly property bool isToday: modelData.key === root.todayKey

                    width: monthColumn.cell
                    height: 20 * root.designPx

                    Rectangle {
                        anchors.centerIn: parent
                        width: 20 * root.designPx
                        height: width
                        radius: 6 * root.designPx
                        color: dayCell.isToday ? root.accent : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: dayCell.modelData.day
                            color: dayCell.isToday
                                ? root.chipTextColor
                                : (dayCell.modelData.inMonth ? root.tint : root.faintTint)
                            opacity: dayCell.modelData.inMonth ? 1 : 0.45
                            font.family: root.fontFamily
                            font.weight: dayCell.isToday ? Font.Medium : Font.Normal
                            font.pixelSize: 10 * root.designPx
                        }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: 3 * root.designPx
                        height: width
                        radius: width / 2
                        color: root.accent
                        visible: dayCell.modelData.inMonth && !dayCell.isToday
                            && root.eventDays[dayCell.modelData.key] === true
                    }
                }
            }
        }
    }

    Column {
        id: dayColumn

        anchors.left: monthColumn.right
        anchors.leftMargin: 20 * root.designPx
        anchors.right: parent.right
        anchors.rightMargin: 22 * root.designPx
        // Centred when empty, or the right half sits blank.
        y: root.todayEvents.length > 0
            ? monthColumn.y : (root.height - height) / 2
        spacing: 12 * root.designPx

        Item {
            width: parent.width
            height: 26 * root.designPx

            Text {
                id: dayNumber
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                text: String(root.today.getDate()).padStart(2, "0")
                color: root.tint
                font.family: root.fontFamily
                font.weight: Font.Light
                font.pixelSize: 26 * root.designPx
                font.letterSpacing: -26 * root.designPx * 0.03
            }

            Text {
                id: weekdayLabel
                anchors.left: dayNumber.right
                anchors.leftMargin: 9 * root.designPx
                anchors.baseline: dayNumber.baseline
                text: Qt.formatDate(root.today, "ddd").toUpperCase()
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: 9 * root.designPx
                font.letterSpacing: 9 * root.designPx * 0.16
            }

            Text {
                id: countLabel
                anchors.right: parent.right
                anchors.baseline: dayNumber.baseline
                text: root.todayEvents.length === 0
                    ? "NO EVENTS"
                    : root.todayEvents.length + (root.todayEvents.length === 1
                        ? " EVENT" : " EVENTS")
                color: root.faintTint
                font.family: root.fontFamily
                font.pixelSize: 8 * root.designPx
                font.letterSpacing: 8 * root.designPx * 0.14
            }

            Rectangle {
                anchors.left: weekdayLabel.right
                anchors.leftMargin: 9 * root.designPx
                anchors.right: countLabel.left
                anchors.rightMargin: 9 * root.designPx
                anchors.baseline: dayNumber.baseline
                height: 1
                color: root.faintTint
                opacity: 0.4
            }
        }

        Column {
            width: parent.width
            spacing: 10 * root.designPx

            Repeater {
                model: root.todayEvents.slice(0, 3)

                Row {
                    id: eventRow
                    required property var modelData

                    readonly property bool past: root.isPast(modelData.time)

                    spacing: 10 * root.designPx

                    Rectangle {
                        width: 2 * root.designPx
                        height: 28 * root.designPx
                        color: eventRow.past ? root.faintTint : root.accent
                    }

                    Column {
                        spacing: 3 * root.designPx

                        Text {
                            text: eventRow.modelData.time
                                ? eventRow.modelData.time : "ALL DAY"
                            color: root.faintTint
                            opacity: eventRow.past ? 0.7 : 1
                            font.family: root.fontFamily
                            font.pixelSize: 9 * root.designPx
                            font.letterSpacing: 9 * root.designPx * 0.1
                        }

                        Text {
                            width: dayColumn.width - 12 * root.designPx
                            text: eventRow.modelData.title
                            color: root.tint
                            opacity: eventRow.past ? 0.55 : 0.92
                            elide: Text.ElideRight
                            font.family: root.fontFamily
                            font.pixelSize: 12 * root.designPx
                        }
                    }
                }
            }
        }
    }
}
