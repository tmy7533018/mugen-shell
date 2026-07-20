import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    width: parent ? parent.width : 420
    height: 64
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function toggle() {
        if (!settingsManager) return
        settingsManager.barThinking = !settingsManager.barThinking
        settingsManager.saveSettings()
        section.bump()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            // Without a 0 minimum the long description pushes the pill off-screen.
            Layout.minimumWidth: 0
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: "Bar Yura thinking"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Normal
                font.letterSpacing: 0.5
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: "Internal reasoning before reply (capable models only)"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
                font.pixelSize: 10
                font.family: "M PLUS 2"
                opacity: 0.6
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: pill
            Layout.preferredWidth: 44
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter
            radius: 12

            readonly property bool on: section.settingsManager && section.settingsManager.barThinking

            color: pill.on
                ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                : Qt.rgba(0.3, 0.3, 0.36, 0.5)
            border.width: 1
            border.color: pill.on
                ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95))
                : Qt.rgba(1, 1, 1, 0.10)
            Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

            Rectangle {
                width: 18
                height: 18
                radius: 9
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                y: 3
                x: pill.on ? pill.width - width - 3 : 3
                Behavior on x { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: section.toggle()
            }
        }
    }
}
