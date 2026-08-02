import QtQuick
import Quickshell
import Quickshell.Io
import "../../lib" as Theme
import "../common" as Common

Common.IconButton {
    id: screenshotButton

    required property var theme
    required property var icons
    required property var screenshotManager
    required modeManager

    readonly property string screenshotScript: Quickshell.shellDir + "/scripts/take-screenshot.sh"

    iconSource: icons && icons.iconData.screenshot && icons.iconData.screenshot.type === "svg"
        ? icons.iconData.screenshot.value
        : ""
    iconText: icons && icons.iconData.screenshot && icons.iconData.screenshot.type === "text"
        ? icons.iconData.screenshot.value
        : ""
    iconColor: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)

    Process {
        id: screenshotProcess
        command: Theme.Hypr.execArgv(screenshotButton.screenshotScript)
        running: false

        stdout: SplitParser { }
        stderr: SplitParser {
            onRead: data => {
            }
        }

        onExited: {
            running = false
            if (screenshotButton.screenshotManager) {
                screenshotButton.screenshotManager.refresh()
            }
        }
    }

    onClicked: {
        if (!screenshotProcess.running) {
            screenshotProcess.running = true
        }
    }

    onRightClicked: {
        if (screenshotButton.modeManager) {
            screenshotButton.modeManager.switchMode("screenshot-gallery")
        }
    }
}

