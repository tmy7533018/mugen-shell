pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property var typo
    property color tint: "white"
    property color faintTint: Qt.rgba(1, 1, 1, 0.35)
    property color accent: "#a68cd9"
    property bool running: true
    property string textureSource: ""

    // Recomputed by the owner's clock tick; a date is not a live property.
    property date today: new Date()

    readonly property real designPx: height / 221

    readonly property real synodicMonth: 29.530588853
    readonly property real unixEpochJulian: 2440587.5
    readonly property real referenceNewMoonJulian: 2451550.1

    readonly property real moonAge: {
        const julian = today.getTime() / 86400000 + unixEpochJulian
        const age = (julian - referenceNewMoonJulian) % synodicMonth
        return (age + synodicMonth) % synodicMonth
    }

    readonly property real moonPhase: moonAge / synodicMonth
    readonly property int illumination:
        Math.round((1 - Math.cos(2 * Math.PI * moonPhase)) / 2 * 100)

    readonly property string moonName: {
        const age = moonAge
        return age < 1.5 ? "新月" : age < 5.5 ? "三日月" : age < 9.5 ? "上弦の月"
            : age < 13.5 ? "十三夜月" : age < 16.5 ? "満月" : age < 20.5 ? "居待月"
            : age < 24.5 ? "下弦の月" : "有明月"
    }

    readonly property real discRadius: 61 * designPx
    readonly property real ringRadius: discRadius + 14 * designPx
    readonly property real discX: width * 0.72
    readonly property real discY: height * 0.5

    property real time: 0
    property real driftTime: 0
    property real spin: 0

    // Integer multipliers only: `time` wraps at 2π and a fraction jumps.
    NumberAnimation on time {
        running: root.running && root.visible
        loops: Animation.Infinite
        from: 0
        to: 2 * Math.PI
        duration: 5700
    }

    NumberAnimation on driftTime {
        running: root.running && root.visible
        loops: Animation.Infinite
        from: 0
        to: 2 * Math.PI
        duration: 47000
    }

    NumberAnimation on spin {
        running: root.running && root.visible
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: 20900
    }

    Repeater {
        model: 52

        Rectangle {
            id: star
            required property int index

            // Hashed: fixed strides lay the field out on a visible diagonal lattice.
            readonly property real seedX: (Math.sin(index * 12.9898) + 1) / 2
            readonly property real seedY: (Math.sin(index * 78.233) + 1) / 2
            readonly property real seedSize: (Math.sin(index * 39.417) + 1) / 2
            readonly property real seedPhase:
                (Math.sin(index * 4.271) + 1) / 2 * 2 * Math.PI

            readonly property real twinkle:
                0.25 + 0.75 * (Math.sin(root.time + seedPhase) * 0.5 + 0.5)

            // Inset past the drift, so no star leaves the box or enters a corner.
            readonly property real inset: root.designPx * 11

            width: root.designPx * (1.1 + seedSize * 2.3)
            height: width
            radius: width / 2
            color: "#ffffff"
            x: inset + seedX * (root.width - width - inset * 2)
                + Math.sin(root.driftTime + seedPhase) * root.designPx * 3
            y: inset + seedY * (root.height - height - inset * 2)
                + Math.cos(root.driftTime + seedPhase) * root.designPx * 2
            opacity: star.twinkle * (0.2 + seedSize * 0.35)
        }
    }

    Rectangle {
        id: meteor

        width: root.designPx * 38
        height: root.designPx * 1.1
        radius: height / 2
        opacity: 0
        rotation: 24
        transformOrigin: Item.Center
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: "#ffffff" }
        }
    }

    ParallelAnimation {
        id: meteorRun

        NumberAnimation { target: meteor; property: "x"; duration: 950 }
        NumberAnimation { target: meteor; property: "y"; duration: 950 }
        SequentialAnimation {
            NumberAnimation {
                target: meteor; property: "opacity"; to: 0.7; duration: 200
            }
            NumberAnimation {
                target: meteor; property: "opacity"; to: 0; duration: 600
            }
        }
    }

    // Rare enough that catching one still feels like catching one.
    Timer {
        running: root.running && root.visible
        repeat: true
        interval: 11000 + Math.random() * 17000

        onTriggered: {
            const travel = root.width * 0.42
            const startX = root.width * (0.1 + Math.random() * 0.4)
            const startY = root.height * Math.random() * 0.45
            meteorRun.stop()
            meteor.x = startX
            meteor.y = startY
            meteorRun.animations[0].from = startX
            meteorRun.animations[0].to = startX + travel
            meteorRun.animations[1].from = startY
            meteorRun.animations[1].to = startY + travel * 0.45
            meteorRun.start()
            interval = 11000 + Math.random() * 17000
        }
    }

    Item {
        id: moonGroup

        width: root.width
        height: root.height

        SequentialAnimation on y {
            running: root.running && root.visible
            loops: Animation.Infinite
            NumberAnimation {
                from: -3 * root.designPx; to: 3 * root.designPx
                duration: 6300; easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: 3 * root.designPx; to: -3 * root.designPx
                duration: 6300; easing.type: Easing.InOutSine
            }
        }

        // Painted once a day and moved by the group above, not redrawn per frame.
        Canvas {
            id: disc
            anchors.fill: parent

            readonly property real phase: root.moonPhase
            onPhaseChanged: requestPaint()

            property bool textureReady: false

            readonly property string source: root.textureSource
            onSourceChanged: loadTexture()

            function loadTexture() {
                textureReady = false
                if (source === "") {
                    requestPaint()
                    return
                }
                if (isImageLoaded(source)) {
                    textureReady = true
                    requestPaint()
                    return
                }
                loadImage(source)
            }

            onImageLoaded: {
                textureReady = isImageLoaded(source)
                requestPaint()
            }

            Component.onCompleted: loadTexture()

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()

                const cx = root.discX
                const cy = root.discY
                const r = root.discRadius
                const phase = root.moonPhase

                // Kept tight: a wide halo pulls the eye off the orb.
                const glow = ctx.createRadialGradient(cx, cy, r * 0.6, cx, cy, r * 1.8)
                glow.addColorStop(0, Qt.rgba(0.91, 0.933, 1, 0.07))
                glow.addColorStop(1, Qt.rgba(0.91, 0.933, 1, 0))
                ctx.fillStyle = glow
                ctx.fillRect(cx - r * 1.8, cy - r * 1.8, r * 3.6, r * 3.6)

                const surface = () => {
                    if (textureReady) ctx.drawImage(root.textureSource,
                                                    cx - r, cy - r, r * 2, r * 2)
                    else {
                        ctx.fillStyle = Qt.rgba(0.929, 0.945, 0.984, 1)
                        ctx.fillRect(cx - r, cy - r, r * 2, r * 2)
                    }
                }

                // Earthshine: a solid disc of shadow sits on the face like a hole.
                const shadow = () => {
                    ctx.fillStyle = Qt.rgba(0.055, 0.062, 0.088, 1)
                    ctx.fillRect(cx - r, cy - r, r * 2, r * 2)
                    if (!textureReady) return
                    ctx.globalAlpha = 0.13
                    ctx.drawImage(root.textureSource, cx - r, cy - r, r * 2, r * 2)
                    ctx.globalAlpha = 1
                }

                ctx.save()
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, Math.PI * 2)
                ctx.clip()

                shadow()

                ctx.save()
                ctx.beginPath()
                if (phase < 0.5) ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2)
                else ctx.arc(cx, cy, r, Math.PI / 2, -Math.PI / 2)
                ctx.clip()
                surface()
                ctx.restore()

                const half = Math.abs(Math.cos(2 * Math.PI * phase)) * r
                ctx.save()
                ctx.beginPath()
                ctx.ellipse(cx - half, cy - r, half * 2, r * 2)
                ctx.clip()
                if (phase < 0.25 || phase > 0.75) shadow()
                else surface()
                ctx.restore()

                ctx.restore()

                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.16)
                ctx.lineWidth = 1
                ctx.setLineDash([2, 5])
                ctx.beginPath()
                ctx.arc(cx, cy, root.ringRadius, 0, Math.PI * 2)
                ctx.stroke()
            }
        }

        Canvas {
            id: tracer
            anchors.fill: parent

            readonly property color stroke: root.accent
            onStrokeChanged: requestPaint()

            transform: Rotation {
                origin.x: root.discX
                origin.y: root.discY
                angle: root.spin
            }

            // A tail behind a head at angle zero, so the spin reads as travel.
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()

                const cx = root.discX
                const cy = root.discY
                const r = root.ringRadius
                const span = 2.6
                const segments = 48

                ctx.strokeStyle = root.accent
                for (let i = 0; i < segments; i++) {
                    const along = (i + 1) / segments
                    ctx.globalAlpha = 0.9 * Math.pow(along, 2.6)
                    ctx.lineWidth = root.designPx * (0.4 + along * 1.4)
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, -span * (1 - i / segments),
                            -span * (1 - along))
                    ctx.stroke()
                }

                const headGlow = ctx.createRadialGradient(
                    cx + r, cy, 0, cx + r, cy, root.designPx * 8)
                headGlow.addColorStop(0, Qt.rgba(root.accent.r, root.accent.g,
                                                 root.accent.b, 0.55))
                headGlow.addColorStop(1, Qt.rgba(root.accent.r, root.accent.g,
                                                 root.accent.b, 0))
                ctx.globalAlpha = 1
                ctx.fillStyle = headGlow
                ctx.fillRect(cx + r - root.designPx * 8, cy - root.designPx * 8,
                             root.designPx * 16, root.designPx * 16)

                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.92)
                ctx.beginPath()
                ctx.arc(cx + r, cy, root.designPx * 1.9, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 18 * root.designPx
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16 * root.designPx
        spacing: 8 * root.designPx

        Text {
            text: root.moonName
            color: root.tint
            font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
            font.weight: Font.Medium
            font.pixelSize: 27 * root.designPx
        }

        Row {
            spacing: 16 * root.designPx

            Repeater {
                model: [
                    { label: "AGE", value: root.moonAge.toFixed(1) },
                    { label: "LIT", value: root.illumination + "%" }
                ]

                Row {
                    id: readout
                    required property var modelData

                    spacing: 4 * root.designPx

                    Text {
                        text: readout.modelData.label
                        color: root.faintTint
                        font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
                        font.pixelSize: 11 * root.designPx
                        font.letterSpacing: 11 * root.designPx * 0.16
                    }

                    Text {
                        text: readout.modelData.value
                        color: root.accent
                        font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
                        font.pixelSize: 11 * root.designPx
                        font.letterSpacing: 11 * root.designPx * 0.16
                    }
                }
            }
        }
    }
}
