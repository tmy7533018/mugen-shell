import QtQuick
import QtQuick.Layouts
import "../../common" as Common

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    width: parent ? parent.width : 420
    height: 104
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "24-Hour Clock"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Normal
                font.letterSpacing: 0.5
            }

            Common.Switch {
                id: hourSwitch
                checked: section.settingsManager ? section.settingsManager.clockShow24Hour : true
                theme: section.theme

                Connections {
                    target: section.settingsManager
                    function onClockShow24HourChanged() {
                        if (section.settingsManager) {
                            hourSwitch.checked = section.settingsManager.clockShow24Hour
                        }
                    }
                }

                onToggled: {
                    if (section.settingsManager) {
                        section.settingsManager.clockShow24Hour = checked
                        section.settingsManager.saveSettings()
                        section.bump()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Show Seconds"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Normal
                font.letterSpacing: 0.5
            }

            Common.Switch {
                id: secondsSwitch
                checked: section.settingsManager ? section.settingsManager.clockShowSeconds : false
                theme: section.theme

                Connections {
                    target: section.settingsManager
                    function onClockShowSecondsChanged() {
                        if (section.settingsManager) {
                            secondsSwitch.checked = section.settingsManager.clockShowSeconds
                        }
                    }
                }

                onToggled: {
                    if (section.settingsManager) {
                        section.settingsManager.clockShowSeconds = checked
                        section.settingsManager.saveSettings()
                        section.bump()
                    }
                }
            }
        }
    }
}
