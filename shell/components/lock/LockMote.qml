import QtQuick

Rectangle {
    id: root
    required property int index

    property real orbSize: 0
    property color orbBase: "#a68cd9"
    property real orbCX: 0
    property real orbCY: 0

    property real progress: 1
    property real angle: 0
    property real travel: 0

    function launch(moteInner, moteOuter) {
        angle = Math.random() * Math.PI * 2
        // Clamped: a long password leaves only a sliver to start in.
        const inner = Math.min(moteInner,
                               moteOuter * 0.96)
        travel = inner + (moteOuter - inner) * Math.random()
        flight.restart()
    }

    NumberAnimation {
        id: flight
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 620
        // Accelerating inwards, so it reads as pulled rather than drifting.
        easing.type: Easing.InCubic
    }

    width: Math.max(2, root.orbSize * 0.024)
    height: width
    radius: width / 2
    color: root.orbBase
    visible: progress < 1
    opacity: Math.min(1, (1 - progress) * 2.4) * 0.4
    scale: 0.45 + (1 - progress) * 0.6
    x: root.orbCX - width / 2
        + Math.cos(angle) * travel * (1 - progress)
    y: root.orbCY - height / 2
        + Math.sin(angle) * travel * (1 - progress)
}
