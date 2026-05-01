import QtQuick
import QtQuick.Layouts
import "../../common" as Common

Rectangle {
    id: section

    required property var theme
    required property var modeManager

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
            text: "Dark Mode"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.weight: Font.Normal
            font.letterSpacing: 0.5
        }

        Common.Switch {
            id: themeSwitch
            checked: section.theme ? section.theme.themeMode === "dark" : true
            theme: section.theme

            Connections {
                target: section.theme
                function onThemeModeChanged() {
                    if (section.theme) {
                        themeSwitch.checked = section.theme.themeMode === "dark"
                    }
                }
            }

            onToggled: {
                if (section.theme) {
                    if (checked && section.theme.themeMode !== "dark") {
                        section.theme.toggleThemeMode()
                        section.bump()
                    } else if (!checked && section.theme.themeMode !== "light") {
                        section.theme.toggleThemeMode()
                        section.bump()
                    }
                }
            }
        }
    }
}
