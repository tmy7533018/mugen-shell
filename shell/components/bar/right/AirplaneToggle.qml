import QtQuick
import QtQuick.Layouts
import "../../common" as Common

Common.IconButton {
    id: airplaneToggleButton

    required property var theme
    required property var icons
    required property var modeManager
    required property var airplaneManager

    function scaled(v) { return modeManager ? modeManager.scale(v) : v }

    Layout.alignment: Qt.AlignVCenter
    modeManager: airplaneToggleButton.modeManager
    iconSize: scaled(24)
    opacityDuration: 150

    iconSource: airplaneToggleButton.icons ? airplaneToggleButton.icons.airplaneSvg : ""
    iconColor: (airplaneToggleButton.airplaneManager && airplaneToggleButton.airplaneManager.isEnabled)
        ? (airplaneToggleButton.theme ? airplaneToggleButton.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
        : (airplaneToggleButton.theme ? airplaneToggleButton.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))

    onClicked: {
        if (airplaneToggleButton.airplaneManager) {
            airplaneToggleButton.airplaneManager.toggle()
        }
    }
    onRightClicked: {
        if (airplaneToggleButton.airplaneManager) {
            airplaneToggleButton.airplaneManager.refreshStatus()
        }
    }
}
