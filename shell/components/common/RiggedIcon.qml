import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import "../../lib" as Theme

Item {
    id: root

    property color color: Qt.rgba(0.92, 0.92, 0.96, 0.90)
    property string rigDir: Quickshell.shellDir + "/assets/icons/rig"
    property real progress: 0
    readonly property alias playing: runner.running
    default property alias parts: canvas.data

    implicitWidth: 24
    implicitHeight: 24

    function play() {
        runner.restart()
    }

    function freeze(t) {
        runner.stop()
        progress = t
    }

    SequentialAnimation {
        id: runner
        NumberAnimation {
            target: root
            property: "progress"
            from: 0
            to: 1
            duration: Theme.Rig.duration
            easing.type: Easing.Linear
        }
    }

    // The layer is padded so a swinging part is not clipped at the icon's edge.
    Item {
        id: padded
        anchors.fill: parent
        anchors.margins: -Math.round(root.width * 0.3)
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(width * 2, height * 2)
        layer.effect: ColorOverlay { color: root.color }

        Item {
            id: canvas
            anchors.centerIn: parent
            width: root.width
            height: root.height
        }
    }
}
