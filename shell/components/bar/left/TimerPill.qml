import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

Item {
    id: root

    property var theme
    property var typo
    property var modeManager
    property var timerManager

    function scaled(val) {
        if (root.modeManager) return root.modeManager.barScale(val)
        return val
    }

    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: visible ? pillText.implicitWidth + root.scaled(22) : 0
    Layout.preferredHeight: root.scaled(26)
    readonly property bool available: root.timerManager && (root.timerManager.running || root.timerManager.alerting)
    visible: root.available

    function _formatRemaining(sec) {
        if (sec < 0) sec = 0
        const h = Math.floor(sec / 3600)
        const m = Math.floor((sec % 3600) / 60)
        const s = sec % 60
        const pad = n => n < 10 ? "0" + n : "" + n
        if (h > 0) return h + ":" + pad(m) + ":" + pad(s)
        return pad(m) + ":" + pad(s)
    }

    readonly property bool urgent: root.timerManager
        && root.timerManager.running
        && !root.timerManager.paused
        && root.timerManager.remainingSec > 0
        && root.timerManager.remainingSec <= 10

    Rectangle {
        anchors.fill: parent
        radius: root.scaled(13)
        property color accent: root.urgent
            ? Qt.rgba(0.95, 0.40, 0.45, 1)
            : (root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
        color: root.urgent
            ? Qt.rgba(accent.r, accent.g, accent.b, pillHover.containsMouse ? 0.42 : 0.32)
            : (pillHover.containsMouse
                ? Qt.rgba(accent.r, accent.g, accent.b, 0.30)
                : Qt.rgba(accent.r, accent.g, accent.b, 0.18))
        border.width: 1
        border.color: root.urgent
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.72)
            : Qt.rgba(accent.r, accent.g, accent.b, root.timerManager && root.timerManager.paused ? 0.30 : 0.50)
        opacity: root.timerManager && root.timerManager.paused ? 0.65 : 1.0

        Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }
        Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }
    }

    Text {
        id: pillText
        anchors.centerIn: parent
        text: {
            if (!root.timerManager) return "00:00"
            if (root.timerManager.alerting) return "DONE"
            return root._formatRemaining(root.timerManager.remainingSec)
        }
        color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
        opacity: pillHover.containsMouse ? 1.0 : 0.6
        font.pixelSize: root.typo ? root.scaled(root.typo.clockStyle.size * 0.78) : root.scaled(11)
        font.weight: Font.Medium
        font.family: root.typo ? root.typo.clockStyle.family : "M PLUS 2"
        font.letterSpacing: 0.5

        Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }
    }

    MouseArea {
        id: pillHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.modeManager) root.modeManager.switchMode("timer")
        }
    }
}
