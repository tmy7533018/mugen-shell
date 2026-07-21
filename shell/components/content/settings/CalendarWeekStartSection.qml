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

    function pick(value) {
        if (!settingsManager) return
        if (settingsManager.calendarWeekStart === value) return
        settingsManager.calendarWeekStart = value
        settingsManager.saveSettings()
        section.bump()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Week Starts On"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.weight: Font.Normal
            font.letterSpacing: 0.5
        }

        Row {
            spacing: 6

            Repeater {
                model: [{ label: "Sunday", value: 0 }, { label: "Monday", value: 1 }]

                Rectangle {
                    required property var modelData
                    width: 72
                    height: 28
                    radius: 14

                    readonly property bool isSelected: section.settingsManager && section.settingsManager.calendarWeekStart === modelData.value

                    color: isSelected
                        ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25))
                        : (chipMouse.containsMouse
                            ? (section.theme ? section.theme.chipActiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.20))
                            : "transparent")
                    border.width: 1
                    border.color: isSelected
                        ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
                        : Qt.rgba(1, 1, 1, 0.10)
                    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                    Behavior on border.color { ColorAnimation { duration: Theme.Motion.micro } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: parent.isSelected
                            ? (section.theme ? section.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95))
                            : (section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90))
                        font.pixelSize: 11
                        font.family: "M PLUS 2"
                        font.weight: parent.isSelected ? Font.Medium : Font.Normal
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: section.pick(modelData.value)
                    }
                }
            }
        }
    }
}
