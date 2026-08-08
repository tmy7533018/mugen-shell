pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property var typo
    property color tint: "white"
    property string source: ""
    property string label: ""
    property real unit: 20

    signal activated

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
            sourceSize.width: width
            sourceSize.height: height
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
        font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
        font.pixelSize: root.unit * 0.5
        font.letterSpacing: root.unit * 0.09

        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.InOutCubic }
        }
    }

    HoverHandler { id: hover }

    TapHandler {
        onTapped: root.activated()
    }
}
