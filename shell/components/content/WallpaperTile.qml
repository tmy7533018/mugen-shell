import QtQuick
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root

    required property var theme
    required property var modeManager
    property var wallpaperManager
    property string path: ""
    property bool selected: false
    property bool isAddCell: false
    property bool isVideo: false

    signal activated()

    color: "transparent"
    radius: modeManager.scale(18)

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.modeManager.scale(4)
        color: root.theme ? root.theme.surfaceGlass : Qt.rgba(0.15, 0.15, 0.20, 0.5)
        radius: root.modeManager.scale(18)
        border.width: root.isAddCell ? root.modeManager.scale(2) : 0
        border.color: root.theme
            ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.45)
            : Qt.rgba(0.65, 0.55, 0.85, 0.45)
        visible: root.isAddCell || thumb.status !== Image.Ready

        Canvas {
            id: plusCanvas
            anchors.centerIn: parent
            width: root.modeManager.scale(56)
            height: root.modeManager.scale(56)
            visible: root.isAddCell

            property color strokeColor: root.theme
                ? root.theme.accent
                : Qt.rgba(0.65, 0.55, 0.85, 1.0)

            onStrokeColorChanged: requestPaint()
            onWidthChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                let ctx = getContext("2d")
                ctx.reset()
                let cx = width / 2
                let cy = height / 2
                let arm = width * 0.42
                ctx.lineWidth = width * 0.07
                ctx.lineCap = "round"
                ctx.strokeStyle = strokeColor
                ctx.beginPath()
                ctx.moveTo(cx - arm, cy)
                ctx.lineTo(cx + arm, cy)
                ctx.moveTo(cx, cy - arm)
                ctx.lineTo(cx, cy + arm)
                ctx.stroke()
            }
        }
    }

    Image {
        id: thumb
        anchors.fill: parent
        anchors.margins: root.modeManager.scale(4)
        source: root.isAddCell || !root.wallpaperManager ? "" : root.wallpaperManager.thumbnailSource(root.path)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        cache: false
        visible: false
    }

    OpacityMask {
        anchors.fill: thumb
        source: thumb
        visible: !root.isAddCell && thumb.status === Image.Ready
        maskSource: Rectangle {
            width: thumb.width
            height: thumb.height
            radius: root.modeManager.scale(18)
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: root.modeManager.scale(10)
        width: root.modeManager.scale(24)
        height: root.modeManager.scale(24)
        radius: root.modeManager.scale(12)
        color: Qt.rgba(0, 0, 0, 0.7)
        visible: !root.isAddCell && root.isVideo

        Text {
            anchors.centerIn: parent
            text: "▶"
            color: "white"
            font.pixelSize: root.modeManager.scale(10)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: root.selected && !root.isAddCell ? root.modeManager.scale(2) : 0
        border.color: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
        radius: root.modeManager.scale(18)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
