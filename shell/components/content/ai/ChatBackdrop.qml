import QtQuick
import "../../../lib" as Theme

Item {
    id: root

    required property var theme

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.06, 0.04, 0.12, 1.0) }
            GradientStop { position: 0.5; color: Qt.rgba(0.04, 0.025, 0.09, 1.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.025, 0.015, 0.07, 1.0) }
        }
    }

    Item {
        anchors.fill: parent
        Canvas {
            id: nebula
            anchors.fill: parent
            opacity: 0.55
            property color glow: root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.85)
            onGlowChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                let ctx = getContext("2d")
                ctx.reset()
                let cx = width / 2
                let cy = height * 0.45
                let r = Math.max(width, height) * 0.55
                let g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                g.addColorStop(0, Qt.rgba(glow.r, glow.g, glow.b, 0.18))
                g.addColorStop(0.6, Qt.rgba(glow.r, glow.g, glow.b, 0.04))
                g.addColorStop(1, Qt.rgba(glow.r, glow.g, glow.b, 0))
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
            }
        }
    }

    Canvas {
        id: particles
        anchors.fill: parent
        opacity: 0.5

        property var points: []
        property color particleColor: root.theme ? root.theme.glowPrimary : Qt.rgba(0.85, 0.78, 1.0, 0.85)

        Component.onCompleted: {
            points = []
            for (let i = 0; i < 22; i++) {
                points.push({
                    x: Math.random(),
                    y: Math.random(),
                    r: 0.6 + Math.random() * 1.4,
                    phase: Math.random() * Math.PI * 2,
                    speed: 0.0006 + Math.random() * 0.0014,
                    drift: 0.00015 + Math.random() * 0.00035
                })
            }
            requestPaint()
        }

        onPaint: {
            let ctx = getContext("2d")
            ctx.reset()
            for (let i = 0; i < points.length; i++) {
                let p = points[i]
                let alpha = 0.25 + 0.55 * (0.5 + 0.5 * Math.sin(p.phase))
                let x = p.x * width
                let y = p.y * height
                ctx.beginPath()
                ctx.arc(x, y, p.r, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(particleColor.r, particleColor.g, particleColor.b, alpha)
                ctx.fill()
            }
        }

        Timer {
            interval: 60
            running: Theme.Motion.ambient && particles.visible
            repeat: true
            onTriggered: {
                let pts = particles.points
                for (let i = 0; i < pts.length; i++) {
                    pts[i].phase += pts[i].speed * 60
                    pts[i].y -= pts[i].drift
                    if (pts[i].y < -0.02) {
                        pts[i].y = 1.02
                        pts[i].x = Math.random()
                    }
                }
                particles.requestPaint()
            }
        }
    }
}
