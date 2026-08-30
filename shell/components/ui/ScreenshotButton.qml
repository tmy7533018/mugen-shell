import QtQuick
import "../common" as Common

Common.IconButton {
    id: screenshotButton

    required property var theme
    required property var icons
    required modeManager

    iconSource: icons && icons.iconData.screenshot && icons.iconData.screenshot.type === "svg"
        ? icons.iconData.screenshot.value
        : ""
    iconText: icons && icons.iconData.screenshot && icons.iconData.screenshot.type === "text"
        ? icons.iconData.screenshot.value
        : ""
    iconColor: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)

    onClicked: modeManager.switchMode("screenshot-menu")
}
