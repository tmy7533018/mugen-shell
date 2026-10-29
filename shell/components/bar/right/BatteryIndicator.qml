import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme
import "../../ui" as UI

Item {
    id: root

    required property var theme
    required property var typo
    required property var icons
    required property var modeManager
    required property var batteryManager
    property var settingsManager

    function scaled(value) { return modeManager ? modeManager.barScale(value) : value }

    readonly property bool charging: batteryManager ? batteryManager.isCharging : false
    readonly property bool low: !charging && batteryManager
        && batteryManager.percentage <= batteryManager.warnThresholds[0]
    readonly property color tint: {
        if (charging) return theme && theme.glowPrimary ? theme.glowPrimary : Qt.rgba(0.55, 0.85, 1.0, 1.0)
        if (low) return Qt.rgba(0.95, 0.45, 0.50, 1.0)
        return theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
    }
    readonly property real restOpacity: low ? 1.0 : 0.6
    readonly property bool alwaysShowPercent: settingsManager ? settingsManager.batteryShowPercent : false
    readonly property int percentage: batteryManager ? batteryManager.percentage : 0

    // battery.svg leaves this much empty on each side, as wifi.svg does; the label keeps it too.
    readonly property real iconInset: scaled(2)

    visible: batteryManager && batteryManager.present
    implicitWidth: !visible ? 0 : alwaysShowPercent ? percentLabel.x + percentLabel.implicitWidth + iconInset : scaled(24)
    implicitHeight: scaled(24)
    Layout.alignment: Qt.AlignVCenter

    state: mouseArea.containsMouse && !alwaysShowPercent ? "hovered" : "normal"
    states: [
        State {
            name: "normal"
            PropertyChanges { target: batteryIcon; opacity: root.restOpacity; scale: 1.0 }
            PropertyChanges { target: hoverNumber; opacity: 0; scale: 1.0 }
        },
        State {
            name: "hovered"
            PropertyChanges { target: batteryIcon; opacity: 0; scale: 0.8 }
            PropertyChanges { target: hoverNumber; opacity: 1.0; scale: 1.3 }
        }
    ]
    transitions: Transition {
        PropertyAnimation { properties: "opacity,scale"; duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
    }

    UI.SvgIcon {
        id: batteryIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.scaled(24)
        height: root.scaled(24)
        source: root.icons ? root.icons.batterySvg : ""
        color: root.tint

        // The inside of battery.svg's body, in its 16-unit viewBox.
        Rectangle {
            readonly property real unit: batteryIcon.width / 16
            x: 3.583 * unit
            y: 6.25 * unit
            width: 6.833 * unit * Math.max(0, Math.min(1, root.percentage / 100))
            height: 3.5 * unit
            radius: 0.5 * unit
            color: root.tint
        }
    }

    Text {
        id: hoverNumber
        anchors.centerIn: batteryIcon
        text: root.percentage
        color: root.tint
        font.family: root.typo ? root.typo.clockStyle.family : "M PLUS 2"
        font.pixelSize: root.scaled(root.typo ? root.typo.clockStyle.size : 14)
        font.weight: root.typo ? root.typo.clockStyle.weight : Font.Normal
        font.letterSpacing: root.typo ? root.typo.clockStyle.letterSpacing : 0
    }

    Text {
        id: percentLabel
        visible: root.alwaysShowPercent
        anchors.left: batteryIcon.right
        anchors.leftMargin: root.scaled(1)
        anchors.verticalCenter: parent.verticalCenter
        text: root.percentage + "%"
        color: root.tint
        opacity: root.low ? 1.0 : 0.85
        font.family: root.typo ? root.typo.systemInfoStyle.family : "M PLUS 2"
        font.pixelSize: root.scaled(root.typo ? root.typo.systemInfoStyle.size : 11)
        font.weight: root.typo ? root.typo.weightRegular : Font.Normal
        font.letterSpacing: root.typo ? root.typo.systemInfoStyle.letterSpacing : 0
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
    }
}
