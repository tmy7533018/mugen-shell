import QtQuick

// Sonar rings pinging outward from center. Shared by the notification icon's
// unread pulse and Yura's orb while she speaks. Opacity is gated on `running`
// so a burst in flight vanishes the instant it clears instead of finishing.
Item {
    id: rings

    property color color: "white"
    property real ringSize: 20        // base diameter before it scales out
    property real borderWidth: 1
    property real maxScale: 2.0
    property int cycleMs: 2000         // full ping period per ring
    property int ringCount: 3
    property bool running: false

    Repeater {
        model: rings.ringCount
        delegate: Rectangle {
            id: ring
            required property int index
            anchors.centerIn: parent
            width: rings.ringSize
            height: rings.ringSize
            radius: width / 2
            color: "transparent"
            border.width: rings.borderWidth
            border.color: rings.color

            property real rippleScale: 1.0
            property real rippleOpacity: 0.0
            scale: rippleScale
            opacity: rings.running ? rippleOpacity : 0

            SequentialAnimation on rippleScale {
                loops: Animation.Infinite
                running: rings.running
                PauseAnimation { duration: ring.index * 300 }
                NumberAnimation { from: 1.0; to: rings.maxScale; duration: 1200; easing.type: Easing.OutCubic }
                PauseAnimation { duration: Math.max(0, rings.cycleMs - 1200 - ring.index * 300) }
            }
            SequentialAnimation on rippleOpacity {
                loops: Animation.Infinite
                running: rings.running
                PauseAnimation { duration: ring.index * 300 }
                NumberAnimation { from: 0.0; to: 0.5; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { from: 0.5; to: 0.0; duration: 1000; easing.type: Easing.OutCubic }
                PauseAnimation { duration: Math.max(0, rings.cycleMs - 1200 - ring.index * 300) }
            }
        }
    }
}
