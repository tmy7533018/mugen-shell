import QtQuick
import "../../lib" as Theme

Item {
    id: root

    property real surfaceRadius: 0
    property var moduleContext: null
    property var theme: moduleContext ? moduleContext.theme : null

    property real satMin: 0.22
    property real satMax: 0.55
    // Degrees around the wheel per source; the seed only ever carries one or two hues, so the rest are built here.
    property var hueOffsets: [0, 0, 0, 0]
    property var levels: [0.24, 0.10, 0.19, 0.06]
    property var sourceIndex: [0, 1, 2, 0]

    readonly property color fallback: Qt.rgba(0.65, 0.55, 0.85, 1.0)

    readonly property var sources: [
        root.theme ? root.theme.glowPrimary : root.fallback,
        root.theme ? root.theme.glowSecondary : root.fallback,
        root.theme ? root.theme.glowTertiary : root.fallback
    ]

    // Below 1 the compositor's blur of the desktop reads through the backdrop.
    property real faceAlpha: 1.0

    property color baseTop: Qt.rgba(0.09, 0.09, 0.13, 1.0)
    property color baseBottom: Qt.rgba(0.04, 0.04, 0.06, 1.0)
    property color colorA: root.slot(0)
    property color colorB: root.slot(1)
    property color colorC: root.slot(2)
    property color colorD: root.slot(3)

    property real strength: 0.85
    property real spread: 0.06
    property real speed: 5.0
    property bool running: true

    // Keeps the wallpaper's hue but pins lightness, so an accent can't wash out or collapse it.
    function hue(c, lightness, degrees) {
        if (!c) return Qt.hsla(0.72, 0.35, lightness, 1.0)
        return Qt.hsla((c.hslHue + (degrees || 0) / 360 + 1) % 1,
                       Math.min(root.satMax, Math.max(root.satMin, c.hslSaturation)),
                       lightness, 1.0)
    }

    function slot(i) {
        return root.hue(root.sources[root.sourceIndex[i]],
                        root.levels[i],
                        root.hueOffsets[i])
    }

    Behavior on baseTop { ColorAnimation { duration: Theme.Motion.slow; easing.type: Easing.InOutCubic } }
    Behavior on baseBottom { ColorAnimation { duration: Theme.Motion.slow; easing.type: Easing.InOutCubic } }
    Behavior on colorA { ColorAnimation { duration: Theme.Motion.slow; easing.type: Easing.InOutCubic } }
    Behavior on colorB { ColorAnimation { duration: Theme.Motion.slow; easing.type: Easing.InOutCubic } }
    Behavior on colorC { ColorAnimation { duration: Theme.Motion.slow; easing.type: Easing.InOutCubic } }
    Behavior on colorD { ColorAnimation { duration: Theme.Motion.slow; easing.type: Easing.InOutCubic } }

    property real time: 0
    NumberAnimation on time {
        running: root.running && root.visible
        loops: Animation.Infinite
        from: 0
        to: 3600
        duration: 3600000
    }

    ShaderEffect {
        anchors.fill: parent
        blending: true
        // Only the mesh: overlays such as the album art stay as opaque as their own alpha says.
        opacity: root.faceAlpha

        property color baseTop: root.baseTop
        property color baseBottom: root.baseBottom
        property color colorA: root.colorA
        property color colorB: root.colorB
        property color colorC: root.colorC
        property color colorD: root.colorD
        property real time: root.time
        property real speed: root.speed
        property real spread: root.spread
        property real strength: root.strength
        property real aspect: height > 0 ? width / height : 1.0
        property real radiusN: height > 0
            ? Math.min(root.surfaceRadius / height, 0.5, 0.5 * width / height)
            : 0
        property real aaN: height > 0 ? 1.0 / height : 0.002

        fragmentShader: Qt.resolvedUrl("../../assets/shaders/aurora.frag.qsb")
    }
}
