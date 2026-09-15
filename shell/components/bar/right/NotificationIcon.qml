import QtQuick
import QtQuick.Layouts
import "../../common" as Common
import "../../../lib" as Theme

Item {
    id: notificationIconContainer

    required property var theme
    required property var icons
    required property var modeManager
    required property var notificationManager

    function scaled(v) { return modeManager ? modeManager.scale(v) : v }

    implicitWidth: scaled(24)
    implicitHeight: scaled(24)
    Layout.alignment: Qt.AlignVCenter

    property bool hasUnreadNotifications: notificationManager ? notificationManager.unreadCount > 0 : false

    property real highlightPulse: 0.0

    SequentialAnimation on highlightPulse {
        loops: Animation.Infinite
        running: notificationIconContainer.hasUnreadNotifications && !notificationMouseArea.containsMouse

        NumberAnimation { from: 0.0; to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.0; to: 0.0; duration: 1200; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 800 }
    }

    readonly property color iconColor: {
        if (!theme) return Qt.rgba(0.92, 0.92, 0.96, 0.90)
        if (!hasUnreadNotifications) return theme.textPrimary

        let base = theme.textPrimary
        let accentBase = theme.accent
        let themedH = (accentBase.hsvHue - 0.35 + 1.0) % 1.0
        let themed = Qt.hsva(themedH, accentBase.hsvSaturation, Math.min(1.0, accentBase.hsvValue + 0.5), accentBase.a)
        let t = highlightPulse
        return Qt.rgba(base.r + (themed.r - base.r) * t,
                       base.g + (themed.g - base.g) * t,
                       base.b + (themed.b - base.b) * t,
                       base.a + (themed.a - base.a) * t)
    }

    readonly property bool notificationsOff: notificationManager && !notificationManager.notificationsEnabled

    property color notificationBlueColor: {
        if (!theme) return Qt.rgba(0.65, 0.55, 0.85, 0.9)
        let accentBase = theme.accent
        let h = accentBase.hsvHue
        let s = accentBase.hsvSaturation
        let v = accentBase.hsvValue
        let a = accentBase.a
        let themedHueShift = -0.35
        let themedH = (h + themedHueShift + 1.0) % 1.0

        let isLightMode = theme.themeMode === "light"
        let finalV = isLightMode
            ? Math.max(0.0, v - 0.2)
            : Math.min(1.0, v + 0.5)

        return Qt.hsva(themedH, s, finalV, a)
    }

    Common.RippleRings {
        anchors.centerIn: parent
        width: notificationIconContainer.scaled(60)
        height: notificationIconContainer.scaled(60)
        z: 0
        color: notificationIconContainer.notificationBlueColor
        ringSize: notificationIconContainer.scaled(20)
        borderWidth: 1
        maxScale: 2.0
        cycleMs: 4000
        running: notificationIconContainer.hasUnreadNotifications
    }

    Component {
        id: bellRig
        Common.BellRig { color: notificationIconContainer.iconColor }
    }
    Component {
        id: offRig
        Common.ShakeRig {
            color: notificationIconContainer.iconColor
            source: notificationIconContainer.icons ? notificationIconContainer.icons.notificationOffSvg : ""
        }
    }

    Loader {
        id: notificationIcon
        anchors.centerIn: parent
        width: notificationIconContainer.scaled(24)
        height: notificationIconContainer.scaled(24)
        sourceComponent: notificationIconContainer.notificationsOff ? offRig : bellRig
        opacity: notificationMouseArea.containsMouse ? 1.0 : 0.6
        z: 1

        Behavior on opacity {
            NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        id: notificationMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        z: 2

        onEntered: if (notificationIcon.item) notificationIcon.item.play()
        onClicked: {
            if (notificationIconContainer.modeManager) {
                notificationIconContainer.modeManager.switchMode("notification")
            }
        }
    }
}
