import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

ColumnLayout {
    id: root

    required property var theme
    property string title: ""
    property string time: ""
    property bool allDay: false
    property bool timeInvalid: false

    signal titleEdited(string value)
    signal timeEdited(string value)
    signal allDayToggled()
    signal submitRequested()

    // The time field's own reformatting writes its text and so detaches it from `time`.
    function clear() {
        timeInput.text = ""
    }

    function formatTimeInput(text) {
        if (text.indexOf(":") >= 0) return text.substring(0, 5)
        let digits = text.replace(/[^\d]/g, "").substring(0, 4)
        if (digits.length === 0) return ""
        if (digits.length <= 2) return digits
        return digits.substring(0, 2) + ":" + digits.substring(2)
    }

    spacing: 12

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        color: titleInput.activeFocus
            ? Qt.rgba(1, 1, 1, 0.04)
            : Qt.rgba(1, 1, 1, 0.02)
        border.width: 1
        border.color: titleInput.activeFocus
            ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
            : Qt.rgba(1, 1, 1, 0.10)
        radius: 10

        Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

        TextInput {
            id: titleInput
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            text: root.title
            onTextChanged: root.titleEdited(text)
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
            selectionColor: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
            font.pixelSize: 13
            font.family: "M PLUS 2"
            verticalAlignment: TextInput.AlignVCenter
            clip: true

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Title"
                visible: !titleInput.text
                color: root.theme ? root.theme.textFaint : Qt.rgba(0.5, 0.5, 0.55, 1)
                font.pixelSize: 13
                font.italic: true
                font.family: "M PLUS 2"
            }

            Keys.onReturnPressed: root.submitRequested()
            Keys.onEnterPressed: root.submitRequested()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 78
            Layout.preferredHeight: 38
            color: timeInput.activeFocus
                ? Qt.rgba(1, 1, 1, 0.04)
                : Qt.rgba(1, 1, 1, 0.02)
            border.width: 1
            border.color: root.timeInvalid
                ? Qt.rgba(1, 0.5, 0.55, 1)
                : timeInput.activeFocus
                    ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                    : Qt.rgba(1, 1, 1, 0.10)
            radius: 10
            opacity: root.allDay ? 0.4 : 1

            Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }
            Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }

            TextInput {
                id: timeInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                enabled: !root.allDay
                text: root.time
                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                selectionColor: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                font.pixelSize: 13
                font.family: "M PLUS 2"
                verticalAlignment: TextInput.AlignVCenter
                maximumLength: 5

                property bool _formatting: false

                onTextChanged: {
                    if (_formatting) return
                    let formatted = root.formatTimeInput(text)
                    if (formatted !== text) {
                        _formatting = true
                        text = formatted
                        cursorPosition = text.length
                        _formatting = false
                    }
                    root.timeEdited(text)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "HH:MM"
                    visible: !timeInput.text
                    color: root.theme ? root.theme.textFaint : Qt.rgba(0.5, 0.5, 0.55, 1)
                    font.pixelSize: 13
                    font.italic: true
                    font.family: "M PLUS 2"
                }

                Keys.onReturnPressed: root.submitRequested()
                Keys.onEnterPressed: root.submitRequested()
            }
        }

        Rectangle {
            Layout.preferredWidth: 80
            Layout.preferredHeight: 38
            color: root.allDay
                ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.22) : Qt.rgba(0.65, 0.55, 0.85, 0.22))
                : (allDayHover.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.02))
            border.width: 1
            border.color: root.allDay
                ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                : Qt.rgba(1, 1, 1, 0.10)
            radius: 10

            Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

            Text {
                anchors.centerIn: parent
                text: "All day"
                color: root.allDay
                    ? (root.theme ? root.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.95))
                    : (root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85))
                font.pixelSize: 11
                font.weight: root.allDay ? Font.Medium : Font.Light
                font.family: "M PLUS 2"
                font.letterSpacing: 0.5

                Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
            }

            MouseArea {
                id: allDayHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.allDayToggled()
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.preferredWidth: 70
            Layout.preferredHeight: 38
            radius: 10
            color: root.theme
                ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, addHover.containsMouse ? 0.42 : 0.30)
                : Qt.rgba(0.65, 0.55, 0.85, addHover.containsMouse ? 0.42 : 0.30)
            border.width: 0

            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

            Text {
                anchors.centerIn: parent
                text: "Add"
                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                font.pixelSize: 13
                font.weight: Font.Medium
                font.family: "M PLUS 2"
                font.letterSpacing: 0.5
            }

            MouseArea {
                id: addHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.submitRequested()
            }
        }
    }
}
