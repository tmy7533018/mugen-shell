import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    readonly property var screenOptions: {
        let opts = [{ label: "Auto (first)", value: "" }]
        for (let i = 0; i < Quickshell.screens.length; i++) {
            let s = Quickshell.screens[i]
            let label = s.name
            if (typeof s.model === "string" && s.model.length > 0) label += " — " + s.model
            opts.push({ label: label, value: s.name })
        }
        return opts
    }

    width: parent ? parent.width : 420
    height: optionsColumn.implicitHeight + 24
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function pick(value) {
        if (!settingsManager) return
        if (settingsManager.displayMonitor === value) return
        settingsManager.displayMonitor = value
        settingsManager.saveSettings()
        section.bump()
    }

    ColumnLayout {
        id: optionsColumn
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: "Bar Monitor"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.weight: Font.Normal
            font.letterSpacing: 0.5
        }

        Column {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: section.screenOptions

                Rectangle {
                    required property var modelData
                    width: parent ? parent.width : 380
                    height: 32
                    radius: 10

                    readonly property bool isSelected: section.settingsManager && section.settingsManager.displayMonitor === modelData.value

                    color: isSelected
                        ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25))
                        : (optionMouse.containsMouse
                            ? (section.theme ? section.theme.chipActiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.20))
                            : "transparent")
                    border.width: 1
                    border.color: isSelected
                        ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
                        : Qt.rgba(1, 1, 1, 0.10)
                    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                    Behavior on border.color { ColorAnimation { duration: Theme.Motion.micro } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: parent.isSelected
                            ? (section.theme ? section.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95))
                            : (section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90))
                        font.pixelSize: 11
                        font.family: "M PLUS 2"
                        font.weight: parent.isSelected ? Font.Medium : Font.Normal
                    }

                    MouseArea {
                        id: optionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: section.pick(modelData.value)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Restart the shell for a monitor change to take effect."
            color: section.theme ? section.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.55)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            font.letterSpacing: 0.3
        }
    }
}
