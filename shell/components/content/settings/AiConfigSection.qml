import QtQuick
import QtQuick.Layouts

Rectangle {
    id: section

    required property var theme
    required property var modeManager

    signal editConfig()
    signal restartService()

    width: parent ? parent.width : 420
    height: 64
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "AI Assistant"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.weight: Font.Normal
            font.letterSpacing: 0.5
        }

        Rectangle {
            Layout.preferredWidth: editAiConfigText.implicitWidth + 24
            Layout.preferredHeight: 28
            radius: height / 2
            color: editAiConfigArea.containsMouse
                ? Qt.rgba(0.45, 0.65, 0.90, 0.4)
                : Qt.rgba(0.45, 0.65, 0.90, 0.3)

            Behavior on color {
                ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Text {
                id: editAiConfigText
                anchors.centerIn: parent
                text: "Edit Config"
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: 11
                font.family: "M PLUS 2"
                font.weight: Font.Medium
            }

            MouseArea {
                id: editAiConfigArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    section.editConfig()
                    section.bump()
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: restartAiText.implicitWidth + 24
            Layout.preferredHeight: 28
            radius: height / 2
            color: restartAiArea.containsMouse
                ? Qt.rgba(0.90, 0.45, 0.55, 0.4)
                : Qt.rgba(0.90, 0.45, 0.55, 0.25)

            Behavior on color {
                ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Text {
                id: restartAiText
                anchors.centerIn: parent
                text: "Restart AI"
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: 11
                font.family: "M PLUS 2"
                font.weight: Font.Medium
            }

            MouseArea {
                id: restartAiArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    section.restartService()
                    section.bump()
                }
            }
        }
    }
}
