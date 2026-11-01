import QtQuick
import "../../common" as Common

Common.IconButton {
    id: root

    property var theme
    property var typo
    property var icons

    rig: Common.LauncherRig {}
    iconSource: root.icons ? (root.icons.iconData.launcher.type === "svg" ? root.icons.iconData.launcher.value : "") : ""
    iconText: root.icons ? (root.icons.iconData.launcher.type === "text" ? root.icons.iconData.launcher.value : "") : ""
    iconColor: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
    fontSize: root.typo ? root.typo.clockStyle.size : 14
    fontFamily: root.typo ? root.typo.clockStyle.family : "M PLUS 2"
    fontWeight: root.typo ? root.typo.clockStyle.weight : Font.Normal
    letterSpacing: root.typo ? root.typo.clockStyle.letterSpacing : 0

    onClicked: {
        if (root.modeManager) {
            root.modeManager.switchMode("launcher")
        }
    }
}
