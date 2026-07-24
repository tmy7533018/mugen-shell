import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

Item {
    id: weatherContainer

    required property var theme
    required property var typo
    required property var icons
    required property var modeManager
    required property var weatherManager

    function scaled(v) { return modeManager ? modeManager.scale(v) : v }

    visible: weatherManager ? (weatherManager.enabled && weatherManager.ready) : false
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    opacity: weatherMouseArea.containsMouse ? 1.0 : 0.6
    scale: weatherMouseArea.containsMouse ? 1.15 : 1.0

    Behavior on opacity {
        NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: Theme.Motion.slow; easing.type: Easing.OutCubic }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: weatherContainer.scaled(5)

        Text {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            text: (weatherContainer.icons && weatherContainer.weatherManager)
                ? weatherContainer.icons.weatherGlyph(weatherContainer.weatherManager.weatherCode, weatherContainer.weatherManager.isDay)
                : ""
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: weatherContainer.scaled(15)
            color: weatherContainer.theme ? weatherContainer.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            renderType: Text.QtRendering
        }

        Text {
            id: temp
            anchors.verticalCenter: parent.verticalCenter
            text: weatherContainer.weatherManager
                ? Math.round(weatherContainer.weatherManager.temperature) + "°"
                : ""
            font.family: weatherContainer.typo ? weatherContainer.typo.clockStyle.family : "M PLUS 2"
            font.pixelSize: weatherContainer.scaled(13)
            font.weight: Font.Medium
            color: weatherContainer.theme ? weatherContainer.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            renderType: Text.QtRendering
        }
    }

    MouseArea {
        id: weatherMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (weatherContainer.modeManager) {
                weatherContainer.modeManager.switchMode("weather")
            }
        }
    }
}
