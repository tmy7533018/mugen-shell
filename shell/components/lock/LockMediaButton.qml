import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property real size: 12
    property real hitPadding: 0
    property color tint: "white"
    property alias source: glyph.source

    signal activated

    width: size
    height: size

    Image {
        id: glyph
        anchors.fill: parent
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
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
        width: parent.width + root.hitPadding * 2
        height: parent.height + root.hitPadding * 2
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
