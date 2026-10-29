import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var theme
    required property var typo
    required property var modeManager
    required property var batteryManager
    required property var settingsManager

    function scaled(value) { return modeManager ? modeManager.barScale(value) : value }

    readonly property color foreground: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
    readonly property bool enabledInSettings: settingsManager && settingsManager.batteryIndicatorEnabled
    visible: enabledInSettings && batteryManager && batteryManager.present
    implicitWidth: visible ? scaled(48) : 0
    implicitHeight: scaled(24)
    Layout.alignment: Qt.AlignVCenter

    Canvas {
        id: batteryIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.scaled(18)
        height: root.scaled(14)

        property real level: root.batteryManager ? root.batteryManager.percentage / 100 : 0

        onLevelChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        Connections {
            target: root.theme
            function onTextPrimaryChanged() { batteryIcon.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const bodyWidth = width - 3
            const bodyHeight = height - 2
            const fillWidth = Math.max(0, (bodyWidth - 5) * Math.max(0, Math.min(1, level)))
            ctx.lineWidth = 1.4
            ctx.strokeStyle = root.foreground
            ctx.fillStyle = root.foreground
            ctx.beginPath()
            ctx.roundedRect(0.7, 1, bodyWidth, bodyHeight, 2)
            ctx.stroke()
            ctx.fillRect(width - 2, height * 0.34, 2, height * 0.32)
            if (fillWidth > 0) ctx.fillRect(3, 3, fillWidth, bodyHeight - 4)
        }
    }

    Text {
        anchors.left: batteryIcon.right
        anchors.leftMargin: root.scaled(5)
        anchors.verticalCenter: parent.verticalCenter
        text: root.batteryManager ? root.batteryManager.percentage + "%" : ""
        color: root.foreground
        font.family: root.typo ? root.typo.clockStyle.family : "M PLUS 2"
        font.pixelSize: root.scaled(root.typo ? root.typo.clockStyle.size : 12)
        font.weight: root.typo ? root.typo.clockStyle.weight : Font.Normal
        font.letterSpacing: root.typo ? root.typo.clockStyle.letterSpacing : 0
    }
}
