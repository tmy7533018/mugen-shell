import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property real size: 12
    property color tint: "white"
    property alias source: glyph.source

    signal activated

    width: size
    height: size

    Image {
        id: glyph
        anchors.fill: parent
        sourceSize.width: root.size
        sourceSize.height: root.size
        mipmap: true
        visible: false
    }

    ColorOverlay {
        anchors.fill: glyph
        source: glyph
        color: root.tint
    }

    MouseArea {
        // The glyphs are small enough to be awkward targets at their drawn size.
        anchors.centerIn: parent
        width: parent.width * 2.4
        height: parent.height * 2.4
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
