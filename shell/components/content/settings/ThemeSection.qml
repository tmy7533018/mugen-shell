import QtQuick
import QtQuick.Layouts
import "../../common" as Common

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    readonly property bool dark: theme ? theme.themeMode === "dark" : true
    readonly property real glassOpacity: settingsManager
        ? (section.dark ? settingsManager.glassOpacityDark : settingsManager.glassOpacityLight)
        : 0.82

    width: parent ? parent.width : 420
    height: column.implicitHeight + 24
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function commit() {
        if (settingsManager) settingsManager.saveSettings()
        bump()
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Dark mode"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Normal
                font.letterSpacing: 0.5
            }

            Common.Switch {
                checked: section.dark
                theme: section.theme

                onToggled: value => {
                    if (section.theme && section.dark !== value) {
                        section.theme.toggleThemeMode()
                        section.bump()
                    }
                }
            }
        }

        // One slider, two values: it edits the glass of whichever mode is showing.
        Common.SliderRow {
            rowTheme: section.theme
            active: section.settingsManager !== null
            label: "Glass opacity"
            value: section.glassOpacity
            onMoved: nv => {
                if (!section.settingsManager) return
                if (section.dark) section.settingsManager.glassOpacityDark = nv
                else section.settingsManager.glassOpacityLight = nv
                section.bump()
            }
            onReleased: section.commit()
        }
    }
}
