import QtQuick
import Qt5Compat.GraphicalEffects
import "../../../lib" as Theme
import "../../common" as Common

Item {
    id: root

    property color orbColor: Qt.rgba(0.65, 0.55, 0.85, 0.9)
    property bool streaming: false
    property bool speaking: false
    // Peak radius of the speaking ripple, as a multiple of the ring's base
    // size. Lower it in height-constrained hosts (the bar) so rings stay
    // within the visible strip instead of spilling into the margin.
    property real rippleMaxScale: 2.0
    property bool active: true
    property bool breathEnabled: true
    property bool showHalo: true
    property real haloScale: 1.5
    property real haloOpacity: 0.5
    property real coreOpacity: 0.9
    property int corePointCount: 16
    property int haloPointCount: 14
    property real coreWaveAmplitude: 4.0
    property real haloWaveAmplitude: 5.0
    property real coreEdgeAlpha: 0.0
    property real haloEdgeAlpha: 0.0
    property real idleBreathPeak: 1.06
    property int idleBreathDuration: 1800

    property real pulseScale: 1.0

    SequentialAnimation {
        id: idleBreath
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "pulseScale"; to: root.idleBreathPeak; duration: root.idleBreathDuration; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "pulseScale"; to: 1.0; duration: root.idleBreathDuration; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        id: streamPulse
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "pulseScale"; to: 1.18; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "pulseScale"; to: 1.0; duration: 600; easing.type: Easing.InOutSine }
    }

    function refresh() {
        idleBreath.stop()
        streamPulse.stop()
        if (!active) {
            pulseScale = 1.0
            return
        }
        if (streaming) streamPulse.start()
        else if (breathEnabled) idleBreath.start()
        else pulseScale = 1.0
    }

    onActiveChanged: refresh()
    onStreamingChanged: refresh()
    onBreathEnabledChanged: refresh()
    Component.onCompleted: refresh()

    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.pulseScale
        yScale: root.pulseScale
    }

    // Sonar rings ping outward while Yura speaks (TTS playback). Gated on
    // `speaking` so a burst in flight vanishes the instant playback ends.
    Common.RippleRings {
        anchors.centerIn: parent
        width: root.width
        height: root.height
        z: -1
        color: root.orbColor
        ringSize: root.width * 0.83
        borderWidth: Math.max(1, root.width * 0.02)
        maxScale: root.rippleMaxScale
        cycleMs: 2000
        running: root.active && root.speaking
    }

    Common.BlobEffect {
        id: halo
        visible: root.showHalo
        width: root.width * root.haloScale
        height: root.height * root.haloScale
        anchors.centerIn: parent
        blobColor: Qt.rgba(root.orbColor.r, root.orbColor.g, root.orbColor.b, root.streaming ? 0.4 : 0.25)
        layers: 2
        waveAmplitude: root.haloWaveAmplitude
        baseOpacity: root.haloOpacity * (root.streaming ? 1.2 : 0.9)
        animationSpeed: root.streaming ? 0.07 : 0.025
        pointCount: root.haloPointCount
        edgeAlpha: root.haloEdgeAlpha
        running: root.active && root.showHalo

        Behavior on baseOpacity { NumberAnimation { duration: Theme.Motion.slow; easing.type: Theme.Motion.easeMove } }
    }

    Common.BlobEffect {
        anchors.fill: parent
        blobColor: root.orbColor
        layers: 3
        waveAmplitude: root.coreWaveAmplitude
        baseOpacity: root.coreOpacity
        animationSpeed: root.streaming ? 0.13 : 0.04
        pointCount: root.corePointCount
        edgeAlpha: root.coreEdgeAlpha
        running: root.active
    }
}
