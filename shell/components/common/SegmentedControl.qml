import QtQuick
import "../../lib" as Theme

// One rounded face holding equal-width segments, with the selection sliding between them.
Rectangle {
    id: control

    property var theme
    property var typo
    property var labels: []
    property string current: ""
    property int controlHeight: 50

    readonly property int inset: 4
    // The widest label sets every segment, measured imperatively: a binding feeding TextMetrics would loop.
    property int naturalWidth: 0
    readonly property int segmentWidth: labels.length > 0 ? Math.floor((width - inset * 2) / labels.length) : 0

    readonly property int currentIndex: {
        let i = labels.indexOf(current)
        return i < 0 ? 0 : i
    }

    signal selected(string label)

    implicitWidth: naturalWidth
    implicitHeight: controlHeight

    radius: height / 2
    color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.10)

    TextMetrics {
        id: labelMetrics
        font.family: control.typo ? control.typo.fontFamily : "M PLUS 2"
        font.pixelSize: control.typo ? control.typo.sizeSmall : 11
        onFontChanged: control.measureSegments()
    }

    function measureSegments() {
        let widest = 0
        for (let i = 0; i < labels.length; i++) {
            labelMetrics.text = labels[i]
            widest = Math.max(widest, labelMetrics.width)
        }
        naturalWidth = (Math.ceil(widest) + 30) * labels.length + inset * 2
    }

    onLabelsChanged: measureSegments()
    Component.onCompleted: measureSegments()

    Rectangle {
        // Equal-width segments mean the selection is arithmetic, no itemAt() lookup.
        x: segmentsRow.x + control.currentIndex * control.segmentWidth
        y: control.inset
        width: control.segmentWidth
        height: control.height - control.inset * 2
        radius: height / 2
        color: control.theme ? control.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 1.0)
        opacity: 0.28

        Behavior on x {
            NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
        }
    }

    Row {
        id: segmentsRow
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: control.labels

            Item {
                id: segment
                // Declaring modelData required would drop the whole file from the headless harness.
                property string label: typeof modelData !== 'undefined' ? modelData : ""
                readonly property bool isCurrent: control.labels[control.currentIndex] === label

                width: control.segmentWidth
                height: control.height - control.inset * 2

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 1)
                    opacity: !segment.isCurrent && segmentHover.hovered ? 0.08 : 0.0

                    Behavior on opacity { NumberAnimation { duration: Theme.Motion.micro } }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: segment.label
                    font.family: control.typo ? control.typo.fontFamily : "M PLUS 2"
                    font.pixelSize: control.typo ? control.typo.sizeSmall : 11
                    color: segment.isCurrent || segmentHover.hovered
                        ? (control.theme ? control.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))
                        : (control.theme ? control.theme.textSecondary : Qt.rgba(0.86, 0.89, 0.96, 0.58))

                    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                }

                HoverHandler { id: segmentHover }

                TapHandler {
                    onTapped: control.selected(segment.label)
                }
            }
        }
    }
}
