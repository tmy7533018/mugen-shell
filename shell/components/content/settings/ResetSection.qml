import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    width: parent ? parent.width : 420
    implicitHeight: layout.implicitHeight + 40
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: Qt.rgba(0.95, 0.55, 0.65, 0.25)

    property bool armed: false

    Timer {
        id: disarmTimer
        interval: 5000
        onTriggered: section.armed = false
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Reset all settings"
            color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.92)
            font.pixelSize: 14
            font.weight: Font.Medium
            font.family: "M PLUS 2"
        }

        Text {
            Layout.fillWidth: true
            text: "Restores theme, blur, animations, sounds, lock timer, date format, Yura panel side, and bar Yura model to their defaults. Existing wallpapers, calendar events, conversations, and notification history are not touched."
            color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.80)
            font.pixelSize: 11
            font.weight: Font.Light
            font.family: "M PLUS 2"
            wrapMode: Text.WordWrap
            lineHeight: 1.4
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 10

            Rectangle {
                Layout.preferredWidth: resetText.implicitWidth + 28
                Layout.preferredHeight: 32
                radius: 16
                color: section.armed
                    ? Qt.rgba(0.95, 0.55, 0.65, resetMouseArea.containsMouse ? 0.42 : 0.30)
                    : (resetMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                border.width: 1
                border.color: section.armed
                    ? Qt.rgba(0.95, 0.55, 0.65, 0.85)
                    : Qt.rgba(0.95, 0.55, 0.65, 0.45)

                Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

                Text {
                    id: resetText
                    anchors.centerIn: parent
                    text: section.armed ? "Confirm reset" : "Reset to defaults"
                    color: Qt.rgba(0.95, 0.55, 0.65, 1.0)
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.family: "M PLUS 2"
                    font.letterSpacing: 0.5
                }

                MouseArea {
                    id: resetMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!section.armed) {
                            section.armed = true
                            disarmTimer.restart()
                        } else {
                            if (settingsManager) settingsManager.resetToDefault()
                            section.armed = false
                            disarmTimer.stop()
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: section.armed ? "Click again within 5 s to confirm" : ""
                color: theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.65)
                font.pixelSize: 11
                font.family: "M PLUS 2"
                font.italic: true
                visible: section.armed
            }
        }
    }
}
