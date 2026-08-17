pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property string fontFamily: "M PLUS 2"
    property color tint: "white"
    property color faintTint: Qt.rgba(1, 1, 1, 0.35)
    property color accent: "#a68cd9"
    property color glow: "#a68cd9"
    property color subTone: "#a68cd9"
    property bool running: true


    // Recomputed by the owner's clock tick; a date is not a live property.
    property date today: new Date()

    readonly property real designPx: height / 221

    readonly property real cell: Math.max(3, Math.round(6 * designPx))

    readonly property real orbRadius: 46 * designPx
    // Not the glow's edge: it reaches a fifth further, the wobble further still.
    readonly property real margin: orbRadius * 1.2 + 9 * designPx

    property int keystrokes: 0
    property var stamps: []

    property real energy: 0
    property real time: 0

    property real posX: width * 0.5
    property real posY: height * 0.5
    property real velX: 0
    property real velY: 0

    // Monotonic: typing shoves the wander on rather than firing over it.
    property real advance: 0

    property real orbX: 0
    property real orbY: 0

    property var trail: []
    property real trailClock: 0

    // Time-based: one point per frame makes the tail 4x shorter at 240Hz than at 60.
    readonly property real trailSpan: 3.0
    readonly property int trailPoints: 48
    readonly property real trailFloor: 0.35
    readonly property real trailGain: 1.8

    // Time counts as much as typing, or Yura sits at LV.1 all evening.
    readonly property int level:
        Math.min(99, 1 + Math.floor(keystrokes / 12 + time / 45))

    readonly property string mood:
        energy > 0.72 ? "ごきげん" : energy > 0.34 ? "おきた"
            : energy > 0.08 ? "うとうと" : "ねむい"

    function bump() {
        if (!running) return
        keystrokes += 1

        const now = Date.now()
        const kept = stamps.filter(t => now - t < 6000)
        kept.push(now)
        stamps = kept

        advanceAnim.stop()
        advanceAnim.from = advance
        advanceAnim.to = advance + 1
        advanceAnim.start()

        const kick = (70 + Math.random() * 55) * designPx
        // Spent sideways as the ceiling nears, or repeated kicks outrun the drag and pin the orb there.
        const headroom = height > 2 * margin
            ? Math.max(0, Math.min(1, (posY - margin) / (height - 2 * margin)))
            : 0
        const inward = posX < width * 0.5 ? 1 : -1
        velY -= kick * headroom
        velX += (Math.random() - 0.5) * 150 * designPx + inward * kick * (1 - headroom)
        spawnSparks()
    }

    // Lowest around 4am and highest mid-afternoon.
    readonly property real daylight: {
        const hour = today.getHours() + today.getMinutes() / 60
        return 0.5 - 0.5 * Math.cos((hour - 4) / 24 * 2 * Math.PI)
    }

    // Yura has moods of its own; without this it is asleep unless typed at.
    function restingEnergy() {
        const breath = 0.5 + 0.5
            * Math.sin(time * 0.11 + Math.sin(time * 0.047) * 1.3)
        return 0.02 + 0.2 * breath + 0.22 * daylight
    }

    function measuredEnergy() {
        const now = Date.now()
        const recent = stamps.filter(t => now - t < 6000)
        if (recent.length < 3) return 0
        const minutes = (now - recent[0]) / 60000
        const wpm = Math.min(220, (recent.length / 5) / Math.max(minutes, 0.02))
        return Math.min(1, wpm / 90)
    }

    function step(dt) {
        time += dt
        energy = Math.min(1, Math.max(restingEnergy(), measuredEnergy()))

        // Invisible sparks keep re-evaluating six time-bound expressions every frame.
        if (sparks.length > 0 && time - sparks[sparks.length - 1].t0 > 2.2) sparks = []

        // Incommensurable rates, so the path never closes into a visible loop.
        const phase = time + advance * 1.7
        const spanX = Math.max(0, width * 0.5 - margin)
        const spanY = Math.max(0, height * 0.5 - margin)

        const targetX = width * 0.5 + spanX
            * (Math.sin(phase * 0.23) * 0.62 + Math.sin(phase * 0.41 + 1.7) * 0.38)
        const targetY = height * 0.5 - energy * 14 * designPx + spanY
            * (Math.sin(phase * 0.19 + 0.5) * 0.6 + Math.sin(phase * 0.33 + 2.1) * 0.4)

        velX += (targetX - posX) * 3.4 * dt
        velY += (targetY - posY) * 3.4 * dt
        velX *= Math.pow(0.12, dt)
        velY *= Math.pow(0.12, dt)
        posX += velX * dt
        posY += velY * dt

        const heldX = Math.max(margin, Math.min(width - margin, posX))
        const heldY = Math.max(margin, Math.min(height - margin, posY))
        // Keeping the velocity a clamp just absorbed leaves the orb pressed against the wall.
        if (heldX !== posX) velX = 0
        if (heldY !== posY) velY = 0
        posX = heldX
        posY = heldY

        orbX = posX + Math.sin(time * 0.32) * 9 * designPx
        orbY = posY + Math.sin(time * 0.52) * 6 * designPx

        trailClock += dt
        const interval = trailSpan / (trailPoints - 1)
        if (trailClock >= interval) {
            trailClock -= interval
            const points = trail.slice()
            points.push({ x: orbX, y: orbY })
            if (points.length > trailPoints) points.shift()
            trail = points
        }
    }

    // Six samples read the same as the whole history at this size.
    function trailPoint(slot) {
        const count = trail.length
        if (count === 0) return Qt.vector4d(-1000, -1000, 0, 0)
        const index = Math.min(count - 1, Math.round(slot * (count - 1) / 5))
        const point = trail[index]
        const age = index / Math.max(1, count - 1)
        return Qt.vector4d(point.x, point.y,
                           (trailFloor + (1 - trailFloor) * age) * trailGain, 0)
    }

    NumberAnimation {
        id: advanceAnim
        target: root
        property: "advance"
        duration: 1500
        easing.type: Easing.OutCubic
    }

    FrameAnimation {
        running: root.running && root.visible
        onTriggered: root.step(Math.min(0.05, frameTime))
    }

    ShaderEffect {
        anchors.fill: parent
        blending: true

        readonly property real pulse:
            1 + Math.sin(root.time * 0.55) * 0.05 + root.energy * 0.08
        readonly property real radius: root.orbRadius * pulse
        readonly property real coreRadius:
            (7 + root.energy * 2 + Math.sin(root.time * 0.9) * 0.9) * root.designPx

        property color mainColor: root.accent
        property color subColor: root.subTone
        property vector2d res: Qt.vector2d(width, height)
        property vector2d orb: Qt.vector2d(root.orbX, root.orbY)
        property vector2d light: Qt.vector2d(
            root.orbX + Math.sin(root.time * 0.85) * 6 * root.designPx,
            root.orbY + Math.cos(root.time * 0.68) * 6 * root.designPx)
        property real time: root.time
        property real cell: root.cell
        property real sigmaMain: 2 * Math.pow(radius * 0.5, 2)
        property real sigmaCore: 2 * Math.pow(coreRadius, 2)
        property real sigmaLight: 2 * Math.pow(radius * 0.72 * 0.5, 2)
        property real sigmaTrail: 500 * root.designPx * root.designPx

        property vector4d trail0: root.trailPoint(0)
        property vector4d trail1: root.trailPoint(1)
        property vector4d trail2: root.trailPoint(2)
        property vector4d trail3: root.trailPoint(3)
        property vector4d trail4: root.trailPoint(4)
        property vector4d trail5: root.trailPoint(5)

        fragmentShader: Qt.resolvedUrl("../../assets/shaders/glow-orb.frag.qsb")
    }

    property var sparks: []

    function spawnSparks() {
        const born = sparks.filter(s => time - s.t0 < 2.2)
        for (let i = 0; i < 3; i++) {
            const angle = Math.random() * 2 * Math.PI
            born.push({
                x: orbX, y: orbY,
                vx: Math.cos(angle) * (0.4 + Math.random() * 0.8),
                vy: Math.sin(angle) * (0.4 + Math.random() * 0.8),
                t0: time
            })
        }
        sparks = born.slice(-24)
    }

    Repeater {
        model: root.sparks

        Rectangle {
            id: spark
            required property var modelData

            readonly property real travel: root.time - modelData.t0
            readonly property real life: Math.max(0, 1 - travel / 2.2)

            width: life > 0.6 ? root.cell * 0.66 : root.cell * 0.34
            height: width
            color: travel < 0.35 ? "#ffffff" : root.accent
            opacity: life * 0.55
            visible: life > 0

            x: Math.floor((modelData.x + modelData.vx * travel * 16 * root.designPx)
                / root.cell) * root.cell + (root.cell - width) / 2
            y: Math.floor((modelData.y + modelData.vy * travel * 16 * root.designPx
                + 6 * travel * travel * root.designPx) / root.cell) * root.cell
                + (root.cell - height) / 2
        }
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: 18 * root.designPx
        anchors.rightMargin: 18 * root.designPx
        anchors.topMargin: 16 * root.designPx
        anchors.bottomMargin: 16 * root.designPx

        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            width: nameLabel.width + levelLabel.width + 9 * root.designPx
            height: nameLabel.height

            Text {
                id: nameLabel
                text: "Yura"
                color: root.tint
                font.family: root.fontFamily
                font.weight: Font.Medium
                font.pixelSize: 16 * root.designPx
                font.letterSpacing: 16 * root.designPx * 0.06
            }

            Text {
                id: levelLabel
                anchors.left: nameLabel.right
                anchors.leftMargin: 9 * root.designPx
                anchors.baseline: nameLabel.baseline
                text: "LV." + root.level
                color: root.faintTint
                font.family: root.fontFamily
                font.pixelSize: 10 * root.designPx
                font.letterSpacing: 10 * root.designPx * 0.18
            }
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            text: root.mood
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: 12 * root.designPx
            font.letterSpacing: 12 * root.designPx * 0.1
        }

        Row {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            spacing: 8 * root.designPx

            Text {
                text: "MOOD"
                color: root.faintTint
                font.family: root.fontFamily
                font.pixelSize: 10 * root.designPx
                font.letterSpacing: 10 * root.designPx * 0.18
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 96 * root.designPx
                height: 5 * root.designPx
                color: Qt.rgba(1, 1, 1, 0.14)

                Rectangle {
                    width: parent.width * (0.14 + root.energy * 0.86)
                    height: parent.height
                    color: root.glow

                    Behavior on width {
                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
