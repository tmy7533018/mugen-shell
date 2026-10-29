import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../common" as Common
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

    property bool relaunchPending: false

    // The Yura window is Hyprland's exec-once child, not part of the bar's unit.
    function relaunchYuraWindow() {
        const dir = Quickshell.shellDir
        Theme.Hypr.exec("quickshell kill -p '" + dir + "/yura-shell.qml'; '" + dir + "/scripts/yura-window.sh'")
    }

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Yura in the bar and the corner pop-up"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.weight: Font.Normal
            font.letterSpacing: 0.5
        }

        Common.Switch {
            checked: section.settingsManager ? section.settingsManager.yuraEnabled : true
            theme: section.theme

            onToggled: value => {
                if (section.settingsManager) {
                    section.settingsManager.yuraEnabled = value
                    section.relaunchPending = value
                    section.settingsManager.saveSettings()
                    section.bump()
                }
            }
        }
    }

    // yura-shell reads settings.json at startup, so it must not launch before the save lands.
    Connections {
        target: section.settingsManager
        function onSettingsChanged() {
            if (!section.relaunchPending || !section.settingsManager.yuraEnabled) return
            section.relaunchPending = false
            section.relaunchYuraWindow()
        }
    }
}
