import QtQuick
import Quickshell
import "../../common" as Common

Item {
    id: root

    required property var theme
    property bool reduceMotion: false

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.30, 0.15, 0.45, 0.40) }
            GradientStop { position: 0.55; color: Qt.rgba(0.15, 0.08, 0.30, 0.20) }
            GradientStop { position: 1.0; color: Qt.rgba(0.05, 0.03, 0.12, 0.0) }
        }
    }

    Canvas {
        id: starField
        anchors.fill: parent
        antialiasing: true

        property var stars: []
        property real twinkleTime: 0

        function regenerate() {
            const list = []
            const count = 70
            const ceiling = height * 0.35
            for (let i = 0; i < count; i++) {
                list.push({
                    x: Math.random() * width,
                    y: Math.random() * ceiling,
                    r: 0.4 + Math.random() * 1.4,
                    a: 0.18 + Math.random() * 0.55,
                    twinkle: Math.random() < 0.35,
                    phase: Math.random() * Math.PI * 2,
                    speed: 0.7 + Math.random() * 0.9
                })
            }
            stars = list
            requestPaint()
        }

        Timer {
            interval: 80
            repeat: true
            running: !root.reduceMotion
            onTriggered: {
                starField.twinkleTime += 0.18
                starField.requestPaint()
            }
        }

        onWidthChanged: regenerate()
        onHeightChanged: regenerate()
        Component.onCompleted: regenerate()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            for (let i = 0; i < stars.length; i++) {
                const s = stars[i]
                let alpha = s.a
                let radius = s.r
                if (s.twinkle) {
                    const phase = Math.sin(twinkleTime * s.speed + s.phase)
                    const m = 0.7 + 0.3 * phase
                    alpha = s.a * m
                    radius = s.r * (1 + 0.2 * Math.max(0, phase))
                }
                ctx.beginPath()
                ctx.arc(s.x, s.y, radius, 0, Math.PI * 2)
                ctx.fillStyle = "rgba(245, 240, 255, " + alpha + ")"
                ctx.fill()
            }
        }
    }

    Item {
        id: moonContainer
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 32
        anchors.topMargin: 28
        width: 36
        height: 36
        transformOrigin: Item.Center

        property real bobY: 0

        SequentialAnimation on rotation {
            loops: Animation.Infinite
            running: !root.reduceMotion
            NumberAnimation { from: -55; to: 5; duration: 2800; easing.type: Easing.InOutSine }
            NumberAnimation { from: 5; to: -55; duration: 2800; easing.type: Easing.InOutSine }
        }

        SequentialAnimation on bobY {
            loops: Animation.Infinite
            running: !root.reduceMotion
            NumberAnimation { from: -6; to: 6; duration: 1800; easing.type: Easing.InOutSine }
            NumberAnimation { from: 6; to: -6; duration: 1800; easing.type: Easing.InOutSine }
        }

        transform: Translate { y: moonContainer.bobY }

        Common.GlowSvgIcon {
            anchors.fill: parent
            source: Quickshell.shellDir + "/assets/icons/moon.svg"
            color: root.theme
                ? Qt.rgba(root.theme.textPrimary.r, root.theme.textPrimary.g, root.theme.textPrimary.b, 0.85)
                : Qt.rgba(0.95, 0.93, 0.98, 0.85)

            enableGlow: true
            glowColor: root.theme
                ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.45)
                : Qt.rgba(0.65, 0.55, 0.85, 0.45)
            glowSamples: 24
            glowRadius: 12
            glowSpread: 0.4
        }
    }
}
