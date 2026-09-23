pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property string fontFamily: "M PLUS 2"
    property color tint: "white"
    property color fillColor: "#a68cd9"
    property real cornerRadius: 24
    property string source: ""
    property string label: ""
    property real unit: 20
    // Not scaled by animation speed: at speed 0 a scaled hold would fire on a click.
    property int holdDuration: 700

    property real holdProgress: 0
    property real flash: 0

    signal activated

    function beginHold() {
        if (confirmAnim.running) return
        drainAnim.stop()
        fillAnim.duration = Math.max(1, (1 - holdProgress) * holdDuration)
        fillAnim.start()
    }

    function endHold() {
        if (!fillAnim.running) return
        fillAnim.stop()
        drainAnim.start()
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * root.holdProgress
        clip: true

        Rectangle {
            anchors.bottom: parent.bottom
            width: root.width
            height: root.height
            radius: root.cornerRadius
            color: root.fillColor
            opacity: 0.32 + root.flash * 0.4
        }
    }

    Item {
        id: glyph
        width: root.unit * 1.4
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        scale: hover.hovered ? 1.22 : 1

        Behavior on scale {
            NumberAnimation { duration: 380; easing.type: Easing.InOutCubic }
        }

        Image {
            id: icon
            anchors.fill: parent
            source: root.source
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            visible: false
        }

        ColorOverlay {
            anchors.fill: icon
            source: icon
            color: root.tint
            opacity: hover.hovered ? 1 : 0.75

            Behavior on opacity {
                NumberAnimation { duration: 380; easing.type: Easing.InOutCubic }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: glyph.bottom
        anchors.topMargin: root.unit * 0.45
        text: root.label
        color: root.tint
        opacity: hover.hovered ? 0.75 : 0
        font.family: root.fontFamily
        font.pixelSize: root.unit * 0.5
        font.letterSpacing: root.unit * 0.09

        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.InOutCubic }
        }
    }

    HoverHandler { id: hover }

    TapHandler {
        onPressedChanged: pressed ? root.beginHold() : root.endHold()
    }

    NumberAnimation {
        id: fillAnim
        target: root
        property: "holdProgress"
        to: 1
        onFinished: if (root.holdProgress >= 1) confirmAnim.start()
    }

    NumberAnimation {
        id: drainAnim
        target: root
        property: "holdProgress"
        to: 0
        duration: 280
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: confirmAnim

        NumberAnimation {
            target: root; property: "flash"; to: 1
            duration: 90; easing.type: Easing.OutCubic
        }
        ScriptAction { script: root.activated() }
        // Emptied here too: after sleep the tile would otherwise wake up full.
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "flash"; to: 0
                duration: 420; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root; property: "holdProgress"; to: 0
                duration: 520; easing.type: Easing.OutCubic
            }
        }
    }
}
