import QtQuick
import QtQuick.Layouts
import "../common" as Common

Common.IconButton {
    id: screenshotButton

    required property var theme
    required property var icons
    required modeManager

    Layout.alignment: Qt.AlignVCenter

    rig: Common.ScreenshotRig {}

    iconSource: icons && icons.iconData.screenshot && icons.iconData.screenshot.type === "svg"
        ? icons.iconData.screenshot.value
        : ""
    iconText: icons && icons.iconData.screenshot && icons.iconData.screenshot.type === "text"
        ? icons.iconData.screenshot.value
        : ""
    iconColor: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)

    onClicked: modeManager.switchMode("screenshot-menu")
}
