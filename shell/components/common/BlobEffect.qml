import QtQuick

// GPU blob: each layer is one ShaderEffect quad evaluating the wavering
// edge analytically (assets/shaders/blob.frag). pointCount is accepted but
// unused — the GLSL edge is resolution-independent — so existing callers
// that still set it keep working.
Item {
    id: root

    property color blobColor: Qt.rgba(0.65, 0.55, 0.85, 0.9)
    property int layers: 3
    property real waveAmplitude: 3.0
    property real baseOpacity: 0.85
    property real animationSpeed: 0.08
    property int pointCount: 16
    property bool running: true
    property real edgeAlpha: 0.0

    // Shared clock in seconds; per-layer speed scales inside the shader.
    // Restarting on visibility keeps hidden blobs truly idle (no uniform
    // churn), matching the old timer's behaviour.
    property real time: 0
    NumberAnimation on time {
        running: root.running && root.visible
        loops: Animation.Infinite
        from: 0
        to: 3600
        duration: 3600000
    }

    Repeater {
        model: root.layers

        ShaderEffect {
            anchors.fill: parent
            opacity: root.baseOpacity - index * 0.12
            blending: true

            readonly property real sizePx: Math.min(width, height)
            readonly property real ampPx: root.waveAmplitude + index * 3.0

            property color blobColor: root.blobColor
            property real time: root.time
            // Floor is proportional (was a fixed 15px in the Canvas days,
            // which overflowed blobs smaller than ~34px).
            property real baseRadius: sizePx > 0 ? Math.max(sizePx * 0.25, sizePx / 2 - ampPx * 2) / sizePx : 0.25
            property real amplitude: sizePx > 0 ? ampPx / sizePx : 0.02
            property real centerAlpha: 0.9 - index * 0.12
            property real edgeAlpha: root.edgeAlpha
            // 13.33 rad/s per animationSpeed unit; inner layers drift faster.
            property real speed: (root.animationSpeed + index * 0.15) * 13.33
            // Random per-instance phases so no two blobs ripple in sync.
            property real phase1: Math.random() * 6.2832
            property real phase2: Math.random() * 6.2832
            property real phase3: Math.random() * 6.2832
            property real aa: sizePx > 0 ? 1.5 / sizePx : 0.01

            fragmentShader: Qt.resolvedUrl("../../assets/shaders/blob.frag.qsb")
        }
    }
}
