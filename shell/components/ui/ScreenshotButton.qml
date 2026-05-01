import QtQuick
import Quickshell
import Quickshell.Io
import "../common" as Common

Common.IconButton {
    id: screenshotButton

    required property var theme
    required property var icons
    required property var modeManager
    required property var screenshotManager

    readonly property string screenshotScript: Quickshell.shellDir + "/scripts/take-screenshot.sh"

    function scaled(val) {
        if (modeManager) return modeManager.scale(val)
        return val
    }

    iconSource: icons && icons.iconData.screenshot && icons.iconData.screenshot.type === "svg"
        ? icons.iconData.screenshot.value
        : ""
    iconText: icons && icons.iconData.screenshot && icons.iconData.screenshot.type === "text"
        ? icons.iconData.screenshot.value
        : ""
    iconColor: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
    iconSize: scaled(24)
    normalOpacity: 0.6
    hoverOpacity: 1.0
    normalScale: 1.0
    hoverScale: 1.3

    Process {
        id: screenshotProcess
        command: ["hyprctl", "dispatch", "exec", screenshotButton.screenshotScript]
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

