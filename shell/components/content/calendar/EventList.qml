pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../lib" as Theme

Flickable {
    id: root

    required property var theme
    property var events: []
    property string loadError: ""

    signal deleteRequested(var eventId)

    contentWidth: width
    contentHeight: eventsColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        width: 4
        contentItem: Rectangle {
            implicitWidth: 4
            radius: 2
            color: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
        }
    }

    Column {
        id: eventsColumn
        width: parent.width
        spacing: 8

        Repeater {
            model: root.events

            delegate: Rectangle {
                id: eventRow

                required property var modelData

                width: parent.width
                height: 40
                radius: 10
                color: rowHover.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.025)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, rowHover.containsMouse ? 0.10 : 0.05)

                opacity: 0
                property real entryShift: -8
                transform: Translate { y: eventRow.entryShift }

                Component.onCompleted: entryAnim.start()

                ParallelAnimation {
                    id: entryAnim
                    NumberAnimation { target: eventRow; property: "opacity"; from: 0; to: 1; duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
                    NumberAnimation { target: eventRow; property: "entryShift"; from: -8; to: 0; duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
                }

                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                Behavior on border.color { ColorAnimation { duration: Theme.Motion.micro } }

                MouseArea {
                    id: rowHover
                    anchors.fill: parent
                    hoverEnabled: true
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 6
                    spacing: 10

                    Text {
                        text: eventRow.modelData.time || "All day"
                        Layout.preferredWidth: 56
                        color: eventRow.modelData.time
                            ? (root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                            : (root.theme ? root.theme.textFaint : Qt.rgba(0.55, 0.55, 0.6, 1))
                        font.pixelSize: 12
                        font.weight: eventRow.modelData.time ? Font.Medium : Font.Light
                        font.italic: !eventRow.modelData.time
                        font.family: "M PLUS 2"
                        font.letterSpacing: 0.4
                        verticalAlignment: Text.AlignVCenter
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 18
                        color: Qt.rgba(1, 1, 1, 0.10)
                    }

                    Text {
                        text: eventRow.modelData.title
                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        Layout.leftMargin: 2
                        color: root.theme ? root.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                        font.pixelSize: 13
                        font.family: "M PLUS 2"
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    Item {
                        Layout.preferredWidth: 28
                        Layout.fillHeight: true

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: deleteHover.containsMouse
                                ? Qt.rgba(1, 0.5, 0.55, 1)
                                : (root.theme ? root.theme.textFaint : Qt.rgba(0.55, 0.55, 0.6, 1))
                            opacity: deleteHover.containsMouse ? 1 : 0.55
                            font.pixelSize: 12

                            Behavior on opacity { NumberAnimation { duration: Theme.Motion.micro } }
                        }

                        MouseArea {
                            id: deleteHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.deleteRequested(eventRow.modelData.id)
                        }
                    }
                }
            }
        }

        Text {
            visible: root.events.length === 0 && root.loadError === ""
            text: "Nothing scheduled"
            color: root.theme ? root.theme.textFaint : Qt.rgba(0.55, 0.55, 0.6, 1)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.italic: true
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
