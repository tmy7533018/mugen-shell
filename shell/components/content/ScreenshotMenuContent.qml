import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../lib" as Theme

FocusScope {
    id: root

    required property var modeManager
    required property var screenshotManager
    property var theme

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(96),
        "leftMargin": modeManager.scale(700),
        "rightMargin": modeManager.scale(700),
        "topMargin": modeManager.normalBarSize.topMargin,
        "bottomMargin": modeManager.normalBarSize.bottomMargin
    })

    readonly property string screenshotScript: Quickshell.shellDir + "/scripts/take-screenshot.sh"

    readonly property var entries: [
        { label: "Region", mode: "region" },
        { label: "Window", mode: "window" },
        { label: "Full Screen", mode: "screen" },
        { label: "Gallery", mode: "" }
    ]

    property int currentIndex: -1

    // Resolved here so each pill crosses the delegate scope once instead of many times.
    readonly property color pillText: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
    readonly property color pillAccent: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
    readonly property color pillFill: Qt.rgba(pillAccent.r, pillAccent.g, pillAccent.b, 0.18)
    readonly property color pillBorderOn: Qt.rgba(pillAccent.r, pillAccent.g, pillAccent.b, 0.65)
    readonly property color pillBorderOff: Qt.rgba(pillAccent.r, pillAccent.g, pillAccent.b, 0.28)

    function choose(mode) {
        modeManager.closeAllModes()
        if (mode === "") {
            modeManager.switchMode("screenshot-gallery")
            return
        }
        if (!captureProcess.running) {
            captureProcess.command = Theme.Hypr.execArgv(root.screenshotScript + " " + mode)
            captureProcess.running = true
        }
    }

    Component.onCompleted: modeManager.registerMode("screenshot-menu", root)

    Connections {
        target: root.modeManager
        function onCurrentModeChanged() {
            if (root.modeManager.isMode("screenshot-menu")) {
                root.currentIndex = -1
                focusTimer.restart()
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 500
        onTriggered: pillRow.forceActiveFocus()
    }

    Process {
        id: captureProcess
        command: []
        running: false

        onRunningChanged: {
            if (!captureProcess.running && root.screenshotManager) root.screenshotManager.refresh()
        }
    }

    RowLayout {
        id: pillRow
        anchors.centerIn: parent
        spacing: root.modeManager.scale(12)
        focus: root.modeManager.isMode("screenshot-menu")

        Keys.onPressed: (event) => {
            root.modeManager.bump()
            if (event.key === Qt.Key_Escape) {
                root.modeManager.closeAllModes()
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.currentIndex >= 0) root.choose(root.entries[root.currentIndex].mode)
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                root.currentIndex = (root.currentIndex + 1) % root.entries.length
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                root.currentIndex = root.currentIndex <= 0 ? root.entries.length - 1 : root.currentIndex - 1
            } else {
                event.accepted = false
                return
            }
            event.accepted = true
        }

        Repeater {
            model: root.entries

            delegate: Rectangle {
                id: pill

                required property var modelData
                required property int index

                readonly property bool active: pillArea.containsMouse || root.currentIndex === pill.index

                Layout.preferredWidth: pillLabel.implicitWidth + root.modeManager.scale(32)
                Layout.preferredHeight: root.modeManager.scale(40)
                radius: height / 2
                color: pill.active ? root.pillFill : "transparent"
                border.width: 1
                border.color: pill.active ? root.pillBorderOn : root.pillBorderOff
                scale: pill.active ? 1.05 : 1.0

                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                Behavior on border.color { ColorAnimation { duration: Theme.Motion.micro } }
                Behavior on scale { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }

                Text {
                    id: pillLabel
                    anchors.centerIn: parent
                    text: pill.modelData.label
                    color: pill.active ? root.pillAccent : root.pillText
                    font.pixelSize: root.modeManager.scale(13)
                    font.weight: Font.Medium
                    font.family: "M PLUS 2"
                    font.letterSpacing: 0.4

                    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                }

                MouseArea {
                    id: pillArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.currentIndex = pill.index
                    onClicked: root.choose(pill.modelData.mode)
                }
            }
        }
    }
}
