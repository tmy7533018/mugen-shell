pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property var typo
    property color tint: "white"
    property color faintTint: Qt.rgba(1, 1, 1, 0.35)
    property color todayTint: "#7b6cf6"
    property real unit: 16

    // Recomputed by the owner's clock tick; a date is not a live property.
    property date today: new Date()

    readonly property int span: 7
    readonly property real labelWidth: width * 0.3
    readonly property real stripWidth: width - labelWidth
    readonly property real cellGap: unit * 0.28
    // Derived from what is left rather than from `unit`, so the strip can never
    // grow into the month label.
    readonly property real cell:
        Math.max(1, (stripWidth - cellGap * (span - 1)) / span)

    readonly property var days: {
        const out = []
        const anchor = new Date(today.getFullYear(), today.getMonth(), today.getDate())
        // Centred on today rather than aligned to a calendar week, so it never
        // leaves an empty half at the start or end of a month.
        anchor.setDate(anchor.getDate() - Math.floor(span / 2))
        for (let i = 0; i < span; i++) {
            const d = new Date(anchor)
            d.setDate(anchor.getDate() + i)
            out.push(d)
        }
        return out
    }

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.labelWidth
        spacing: root.unit * 0.1

        Text {
            text: Qt.formatDate(root.today, "MMMM")
            color: root.tint
            elide: Text.ElideRight
            width: parent.width
            font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
            font.pixelSize: root.unit
        }

        Text {
            text: Qt.formatDate(root.today, "yyyy")
            color: root.faintTint
            font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
            font.pixelSize: root.unit * 0.7
        }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.cellGap

        Repeater {
            model: root.days

            Column {
                id: dayCell
                required property var modelData

                readonly property bool isToday:
                    modelData.getDate() === root.today.getDate()
                    && modelData.getMonth() === root.today.getMonth()

                width: root.cell
                spacing: root.cell * 0.22

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(dayCell.modelData, "ddd").charAt(0).toUpperCase()
                    color: root.faintTint
                    font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
                    font.pixelSize: root.cell * 0.36
                    font.letterSpacing: root.cell * 0.04
                }

                Rectangle {
                    width: root.cell
                    height: width
                    radius: root.cell * 0.26
                    color: dayCell.isToday ? root.todayTint : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: dayCell.modelData.getDate()
                        color: dayCell.isToday ? "#ffffff" : root.tint
                        font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
                        font.pixelSize: root.cell * 0.5
                    }
                }
            }
        }
    }
}
