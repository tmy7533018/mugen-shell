import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property real surfaceRadius: 0
    property var theme

    property color baseTop: Qt.rgba(0.09, 0.09, 0.13, 1.0)
    property color baseBottom: Qt.rgba(0.04, 0.04, 0.06, 1.0)
    property color colorA: root.hue(root.theme ? root.theme.glowPrimary : fallback, 0.20)
    property color colorB: root.hue(root.theme ? root.theme.glowSecondary : fallback, 0.13)
    property color colorC: root.hue(root.theme ? root.theme.glowTertiary : fallback, 0.17)
    property color colorD: root.hue(root.theme ? root.theme.glowPrimary : fallback, 0.09)

    property real strength: 0.85
    property real spread: 0.18
    property real speed: 0.45
    property bool running: true

    readonly property color fallback: Qt.rgba(0.65, 0.55, 0.85, 1.0)

    // Keeps the wallpaper's hue but pins lightness, so a bright accent can't
    // wash the surface out and a dark one can't collapse it to black.
    function hue(c, lightness) {
        if (!c) return Qt.hsla(0.72, 0.35, lightness, 1.0)
        return Qt.hsla(c.hslHue, Math.min(0.55, Math.max(0.22, c.hslSaturation)), lightness, 1.0)
    }

    property real time: 0
    NumberAnimation on time {
        running: root.running && root.visible
        loops: Animation.Infinite
        from: 0
        to: 3600
        duration: 3600000
    }

    ShaderEffect {
        id: aurora
        anchors.fill: parent
        blending: true
        visible: false

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

        fragmentShader: Qt.resolvedUrl("../../assets/shaders/aurora.frag.qsb")
    }

    OpacityMask {
        anchors.fill: parent
        source: aurora
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.surfaceRadius
        }
    }
}
