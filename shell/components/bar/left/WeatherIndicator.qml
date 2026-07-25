import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../../ui" as UI
import "../../../lib" as Theme

Item {
    id: root

    required property var theme
    required property var typo
    required property var icons
    required property var modeManager
    required property var weatherManager

    function scaled(v) { return modeManager ? modeManager.scale(v) : v }

    visible: weatherManager ? (weatherManager.enabled && weatherManager.ready) : false
    implicitWidth: content.implicitWidth
    implicitHeight: scaled(28)
    Layout.alignment: Qt.AlignVCenter

    readonly property string wtype: (icons && weatherManager) ? icons.weatherType(weatherManager.weatherCode, weatherManager.isDay) : "clouds"
    readonly property var pal: icons ? icons.weatherPalette(wtype) : null
    readonly property color accentC: pal ? pal.accent : (theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 1))
    readonly property color glowC: pal ? pal.glow : Qt.rgba(0.65, 0.55, 0.85, 0.45)

    opacity: ma.containsMouse ? 1.0 : 0.6
    scale: ma.containsMouse ? 1.15 : 1.0
    Behavior on opacity { NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Theme.Motion.slow; easing.type: Easing.OutCubic } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: root.scaled(3)

        UI.SvgIcon {
            anchors.verticalCenter: parent.verticalCenter
            source: (root.icons && root.weatherManager) ? root.icons.weatherIcon(root.weatherManager.weatherCode, root.weatherManager.isDay) : ""
            color: root.accentC
            width: root.scaled(22)
            height: root.scaled(22)
            layer.enabled: true
            layer.effect: Glow {
                color: root.glowC
                radius: 5
                samples: 11
                spread: 0.15
                transparentBorder: true
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -root.scaled(1)
            text: root.weatherManager ? Math.round(root.weatherManager.temperature) + "°" : ""
            font.family: root.typo ? root.typo.clockStyle.family : "M PLUS 2"
            font.pixelSize: root.scaled(15)
            font.weight: Font.Medium
            // Same brightening the clock applies: Text renders darker than
            // icons at the same color.
            color: {
                let base = root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.9)
                return Qt.rgba(Math.min(1.0, base.r * 1.05), Math.min(1.0, base.g * 1.05), Math.min(1.0, base.b * 1.05), base.a)
            }
            renderType: Text.QtRendering
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.modeManager) root.modeManager.switchMode("weather")
        }
    }
}
