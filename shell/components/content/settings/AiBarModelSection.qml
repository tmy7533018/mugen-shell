import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    // Local instance — AiBackend is stateless, threading it through the
    // Settings Loader chain just to share one would be noisier than this.
    Theme.AiBackend { id: aiBackend }

    width: parent ? parent.width : 420
    height: section.isExpanded ? 64 + Math.min(section.options.length, 6) * 36 + 12 : 64
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)
    clip: true

    property bool isExpanded: false
    property var availableModels: []

    // The dropdown lists "Default" (= follow the backend's last-set model)
    // plus every available model. Keyed by the saved barAiModel value: ""
    // means "default".
    readonly property var options: ["", ...availableModels]

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function labelFor(value) {
        return value === "" ? "Default (last used in float)" : value
    }

    function pick(value) {
        if (settingsManager) {
            settingsManager.barAiModel = value
            settingsManager.saveSettings()
        }
        section.isExpanded = false
        section.bump()
    }

    Behavior on height {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    MouseArea {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 64
        cursorShape: Qt.PointingHandCursor

        TapHandler {
            onTapped: {
                section.isExpanded = !section.isExpanded
                section.bump()
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Bar AI model"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Normal
                font.letterSpacing: 0.5
            }

            Text {
                text: section.labelFor(section.settingsManager ? section.settingsManager.barAiModel : "")
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: 11
                font.family: "M PLUS 2"
                font.italic: section.settingsManager && section.settingsManager.barAiModel === ""
                opacity: 0.85
            }

            Text {
                text: section.isExpanded ? "▴" : "▾"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                opacity: 0.7
            }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 4
        spacing: 2
        visible: section.isExpanded

        Repeater {
            model: section.options

            Rectangle {
                required property string modelData
                width: parent ? parent.width : 0
                height: 32
                radius: 10
                color: itemMouse.containsMouse
                    ? (section.theme ? section.theme.chipActiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.25))
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                readonly property bool isSelected: section.settingsManager && section.settingsManager.barAiModel === modelData

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    text: section.labelFor(modelData)
                    color: parent.isSelected
                        ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.85, 1.0, 1.0))
                        : (section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                    font.weight: parent.isSelected ? Font.Medium : Font.Normal
                    font.italic: modelData === ""
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.pick(modelData)
                }
            }
        }
    }

    Process {
        id: modelsProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "2", aiBackend.baseUrl + "/models"]

        stdout: SplitParser { onRead: data => { modelsProcess.buf += data } }
        onRunningChanged: { if (running) buf = "" }

        onExited: (exitCode) => {
            if (exitCode !== 0) return
            try {
                let obj = JSON.parse(modelsProcess.buf)
                if (obj.models) section.availableModels = obj.models
            } catch (e) {}
        }
    }

    Component.onCompleted: modelsProcess.running = true
}
