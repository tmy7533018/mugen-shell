import QtQuick

Item {
    id: part

    property string source: ""
    property real pivotX: 12
    property real pivotY: 12
    property real rot: 0
    property real dx: 0
    property real dy: 0
    property real sx: 1
    property real sy: 1
    property real alpha: 1

    readonly property real unit: width / 24

    anchors.fill: parent
    opacity: alpha
    transform: [
        Scale { origin.x: part.pivotX * part.unit; origin.y: part.pivotY * part.unit; xScale: part.sx; yScale: part.sy },
        Rotation { origin.x: part.pivotX * part.unit; origin.y: part.pivotY * part.unit; angle: part.rot },
        Translate { x: part.dx * part.unit; y: part.dy * part.unit }
    ]

    Image {
        anchors.fill: parent
        source: part.source
        fillMode: Image.PreserveAspectFit
        smooth: true
        // Both from height: Quickshell's icon provider decodes 2x2 when either dimension is 0.
        sourceSize.width: Math.max(height, 24) * 2
        sourceSize.height: Math.max(height, 24) * 2
    }
}
