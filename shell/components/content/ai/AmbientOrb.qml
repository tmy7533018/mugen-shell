import QtQuick
import Qt5Compat.GraphicalEffects
import "../../common" as Common

Item {
    id: root

    property color orbColor: Qt.rgba(0.65, 0.55, 0.85, 0.9)
    property bool streaming: false
    property bool active: true
    property bool showHalo: true
    property real haloScale: 1.5
    property real haloOpacity: 0.5
    property real coreOpacity: 0.9
    property int corePointCount: 16
    property int haloPointCount: 14
    property real coreWaveAmplitude: 4.0
    property real haloWaveAmplitude: 5.0

    property real pulseScale: 1.0

    SequentialAnimation {
        id: idleBreath
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "pulseScale"; to: 1.06; duration: 1800; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "pulseScale"; to: 1.0; duration: 1800; easing.type: Easing.InOutSine }
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
        else idleBreath.start()
    }

    onActiveChanged: refresh()
    onStreamingChanged: refresh()
    Component.onCompleted: refresh()

    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.pulseScale
        yScale: root.pulseScale
    }

    // Outer halo — softer blob giving the orb a subtle glowing field.
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
        running: root.active && root.showHalo

        Behavior on baseOpacity { NumberAnimation { duration: 600; easing.type: Easing.InOutCubic } }
    }

    // Core blob — the orb itself
    Common.BlobEffect {
        anchors.fill: parent
        blobColor: root.orbColor
        layers: 3
        waveAmplitude: root.coreWaveAmplitude
        baseOpacity: root.coreOpacity
        animationSpeed: root.streaming ? 0.13 : 0.04
        pointCount: root.corePointCount
        running: root.active
    }
}
