import QtQuick
import QtQuick.Layouts
import "../../common" as Common
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    width: parent ? parent.width : 420
    height: 168
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function commit() {
        if (!section.settingsManager) return
        if (section.settingsManager.weatherLocation !== locationInput.text) {
            section.settingsManager.weatherLocation = locationInput.text
            section.settingsManager.saveSettings()
        }
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
                text: "Weather"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Normal
                font.letterSpacing: 0.5
            }

            Common.Switch {
                checked: section.settingsManager ? section.settingsManager.weatherEnabled : true
                theme: section.theme

                onToggled: value => {
                    if (section.settingsManager) {
                        section.settingsManager.weatherEnabled = value
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
                text: "Location"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Normal
                font.letterSpacing: 0.5
            }

            Rectangle {
                Layout.preferredWidth: 140
                Layout.preferredHeight: 26
                color: "transparent"
                border.width: 1
                border.color: locationInput.activeFocus
                    ? (section.theme ? section.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                    : (section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18))
                radius: 8

                Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

                TextInput {
                    id: locationInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    text: section.settingsManager ? section.settingsManager.weatherLocation : ""
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                    selectionColor: section.theme ? Qt.rgba(section.theme.glowPrimary.r, section.theme.glowPrimary.g, section.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true

                    Text {
                        anchors.fill: parent
                        text: "Auto (IP-based)"
                        color: section.theme ? section.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.6)
                        font.pixelSize: 12
                        font.family: "M PLUS 2"
                        verticalAlignment: Text.AlignVCenter
                        visible: locationInput.text.length === 0 && !locationInput.activeFocus
                    }

                    onEditingFinished: {
                        section.commit()
                        section.bump()
                    }
                    Keys.onReturnPressed: {
                        section.commit()
                        section.bump()
                        focus = false
                    }
                    Keys.onEnterPressed: {
                        section.commit()
                        section.bump()
                        focus = false
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "°C / °F"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Normal
                font.letterSpacing: 0.5
            }

            Common.Switch {
                checked: section.settingsManager ? section.settingsManager.weatherUnit === "fahrenheit" : false
                theme: section.theme

                onToggled: value => {
                    if (section.settingsManager) {
                        section.settingsManager.weatherUnit = value ? "fahrenheit" : "celsius"
                        section.settingsManager.saveSettings()
                        section.bump()
                    }
                }
            }
        }
    }

    Connections {
        target: section.settingsManager
        function onWeatherLocationChanged() {
            if (!locationInput.activeFocus && locationInput.text !== section.settingsManager.weatherLocation) {
                locationInput.text = section.settingsManager.weatherLocation
            }
        }
    }
}
