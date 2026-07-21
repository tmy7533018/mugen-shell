import QtQuick
import QtQuick.Layouts
import "../../common" as Common

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

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Workspace Count"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.weight: Font.Normal
            font.letterSpacing: 0.5
        }

        Common.Slider {
            Layout.preferredWidth: 180
            theme: section.theme
            from: 1
            to: 10
            stepSize: 1
            value: section.settingsManager ? section.settingsManager.workspaceCount : 5
            display: Math.round(value).toString()

            onMoved: nv => {
                if (section.settingsManager) section.settingsManager.workspaceCount = Math.round(nv)
                section.bump()
            }
            onReleased: {
                if (section.settingsManager) section.settingsManager.saveSettings()
                section.bump()
            }
        }
    }
}
