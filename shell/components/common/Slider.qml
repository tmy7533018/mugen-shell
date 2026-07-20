import QtQuick
import "../../lib" as Theme

// Continuous slider with a trailing value label. `display` is an overridable
// value formatter.
//
// The slider never assigns its own `value`: callers bind it to their source of
// truth, and an imperative write here would sever that binding for good. It
// reports the candidate through moved(newValue) instead and lets the caller's
// write flow back in through the binding. released() fires once at the end of a
// drag so callers can persist there rather than on every pixel.
Item {
    id: root

    property var theme
    property real from: 0.0
    property real to: 1.0
    property real stepSize: 0.01
    property real value: 0.5
    property string display: value.toFixed(2)

    signal moved(real newValue)
    signal released()

    implicitWidth: 180
    implicitHeight: 24

    // Pointer slop around the 6px track, added back when mapping a press to a
    // position — the MouseArea origin sits above/left of the track by this much.
    readonly property int _grab: 8

    readonly property real _ratio: (to > from) ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: valueLabel.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: root.theme ? Qt.rgba(root.theme.textFaint.r, root.theme.textFaint.g, root.theme.textFaint.b, 0.2) : Qt.rgba(0.62, 0.62, 0.72, 0.2)

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * root._ratio
            height: parent.height
            radius: parent.radius
            color: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
        }

        Rectangle {
            id: handle
            width: 16
            height: 16
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: (parent.width - width) * root._ratio
            color: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.35)
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -root._grab
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            // Snapping by step count keeps the result on the step grid; the
            // decimal re-round drops the float noise that would otherwise land
            // values like 0.7000000000000001 in settings.json.
            function quantize(mx) {
                const r = Math.max(0, Math.min(1, mx / track.width))
                const steps = Math.round((r * (root.to - root.from)) / root.stepSize)
                const raw = root.from + steps * root.stepSize
                const dp = Math.max(0, Math.ceil(-Math.log(root.stepSize) / Math.LN10))
                const snapped = parseFloat(raw.toFixed(dp))
                return Math.max(root.from, Math.min(root.to, snapped))
            }

            function apply(mx) {
                const v = quantize(mx - root._grab)
                if (v !== root.value) root.moved(v)
            }

            onPressed: mouse => apply(mouse.x)
            onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
            onReleased: root.released()
        }
    }

    Text {
        id: valueLabel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 42
        horizontalAlignment: Text.AlignRight
        text: root.display
        color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        font.pixelSize: 11
        font.family: "M PLUS 2"
        opacity: 0.85
    }
}
