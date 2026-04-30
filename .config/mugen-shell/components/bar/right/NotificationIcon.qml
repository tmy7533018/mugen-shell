import QtQuick
import QtQuick.Layouts
import "../../ui" as UI

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

    Item {
        id: notificationRippleContainer
        anchors.centerIn: parent
        width: notificationIconContainer.scaled(60)
        height: notificationIconContainer.scaled(60)
        visible: notificationIconContainer.hasUnreadNotifications
        z: 0

        Repeater {
            model: 3

            Rectangle {
                id: ripple
                anchors.centerIn: parent
                width: notificationIconContainer.scaled(20)
                height: notificationIconContainer.scaled(20)
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: notificationIconContainer.notificationBlueColor

                property real rippleScale: 1.0
                property real rippleOpacity: 0.0

                scale: rippleScale
                opacity: rippleOpacity

                SequentialAnimation on rippleScale {
                    loops: Animation.Infinite
                    running: notificationRippleContainer.visible

                    PauseAnimation { duration: index * 300 }
                    NumberAnimation {
                        from: 1.0; to: 2.0
                        duration: 1200
                        easing.type: Easing.OutCubic
                    }
                    PauseAnimation { duration: 4000 - 1200 - index * 300 }
                }

                SequentialAnimation on rippleOpacity {
                    loops: Animation.Infinite
                    running: notificationRippleContainer.visible

                    PauseAnimation { duration: index * 300 }
                    NumberAnimation { from: 0.0; to: 0.5; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { from: 0.5; to: 0.0; duration: 1000; easing.type: Easing.OutCubic }
                    PauseAnimation { duration: 4000 - 1200 - index * 300 }
                }
            }
        }
    }

    UI.SvgIcon {
        id: notificationIcon
        anchors.centerIn: parent
        width: notificationIconContainer.scaled(24)
        height: notificationIconContainer.scaled(24)
        source: notificationIconContainer.icons
            ? (notificationIconContainer.notificationManager && !notificationIconContainer.notificationManager.notificationsEnabled
                ? notificationIconContainer.icons.notificationOffSvg
                : notificationIconContainer.icons.notificationSvg)
            : ""
        color: {
            if (!notificationIconContainer.theme) {
                return Qt.rgba(0.92, 0.92, 0.96, 0.90)
            }

            if (notificationIconContainer.hasUnreadNotifications) {
                let base = notificationIconContainer.theme.textPrimary

                let accentBase = notificationIconContainer.theme.accent
                let h = accentBase.hsvHue
                let s = accentBase.hsvSaturation
                let v = accentBase.hsvValue
                let a = accentBase.a

                let themedHueShift = -0.35
                let themedH = (h + themedHueShift + 1.0) % 1.0
                let themed = Qt.hsva(themedH, s, Math.min(1.0, v + 0.5), a)

                let t = notificationIcon.highlightPulse
                let r = base.r + (themed.r - base.r) * t
                let g = base.g + (themed.g - base.g) * t
                let b = base.b + (themed.b - base.b) * t
                let finalA = base.a + (themed.a - base.a) * t
                return Qt.rgba(r, g, b, finalA)
            }

            return notificationIconContainer.theme.textPrimary
        }
        opacity: notificationMouseArea.containsMouse ? 1.0 : 0.6
        z: 1

        property real baseScale: 1.0
        property real hoverScale: notificationMouseArea.containsMouse ? 0.3 : 0.0
        property real gentleScale: 0.0
        property real highlightPulse: 0.0

        scale: baseScale + hoverScale + gentleScale

        SequentialAnimation on highlightPulse {
            id: highlightBreath
            loops: Animation.Infinite
            running: notificationIconContainer.hasUnreadNotifications && !notificationMouseArea.containsMouse

            NumberAnimation { from: 0.0; to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.0; to: 0.0; duration: 1200; easing.type: Easing.InOutSine }
            PauseAnimation { duration: 800 }
        }

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }
        Behavior on hoverScale {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        id: notificationMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        z: 2

        onEntered: {
            notificationIcon.gentleScale = 0.0
        }
        onClicked: {
            if (notificationIconContainer.modeManager) {
                notificationIconContainer.modeManager.switchMode("notification")
            }
        }
    }
}
