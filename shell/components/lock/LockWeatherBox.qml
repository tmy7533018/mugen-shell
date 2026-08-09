pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property string fontFamily: "M PLUS 2"
    property color tint: "white"
    property color faintTint: Qt.rgba(1, 1, 1, 0.4)
    property real unit: 20

    property string iconSource: ""
    property string temperature: ""
    property string highLow: ""
    property string condition: ""

    Item {
        id: glyph
        width: root.unit * 1.6
        height: width
        anchors.left: parent.left
        anchors.top: parent.top

        Image {
            id: icon
            anchors.fill: parent
            source: root.iconSource
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            visible: false
        }

        ColorOverlay {
            anchors.fill: icon
            source: icon
            color: root.tint
            opacity: 0.85
            visible: root.iconSource !== ""
        }
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        text: root.highLow
        color: root.faintTint
        horizontalAlignment: Text.AlignRight
        font.family: root.fontFamily
        font.pixelSize: root.unit * 0.62
    }

    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        spacing: root.unit * 0.2

        Text {
            text: root.temperature
            color: root.tint
            font.family: root.fontFamily
            font.weight: Font.Light
            font.pixelSize: root.unit * 2.4
        }

        Text {
            text: root.condition
            color: root.faintTint
            font.family: root.fontFamily
            font.pixelSize: root.unit * 0.68
        }
    }
}
