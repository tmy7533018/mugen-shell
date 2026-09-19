import QtQuick
import QtQuick.Layouts

RowLayout {
    id: row

    required property var rowTheme
    required property bool active
    property string label: ""
    property real value: 0
    property string display: Math.round(row.value * 100) + "%"

    signal moved(real newValue)
    signal released()

    Layout.fillWidth: true
    Layout.preferredHeight: 24
    spacing: 12
    enabled: row.active
    opacity: enabled ? 1 : 0.35

    Text {
        Layout.fillWidth: true
        text: row.label
        color: row.rowTheme ? row.rowTheme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
        font.pixelSize: 12
        font.family: "M PLUS 2"
        font.letterSpacing: 0.5
    }

    Slider {
        Layout.preferredWidth: 180
        theme: row.rowTheme
        from: 0.0
        to: 1.0
        stepSize: 0.005
        value: row.value
        display: row.display

        onMoved: nv => row.moved(nv)
        onReleased: row.released()
    }
}
