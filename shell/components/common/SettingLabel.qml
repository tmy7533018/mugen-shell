import QtQuick
import QtQuick.Layouts

// Title + description pair for a settings row.
ColumnLayout {
    id: label

    property var theme
    property string title: ""
    property string desc: ""

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    spacing: 2

    Text {
        Layout.fillWidth: true
        text: label.title
        color: label.theme ? label.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
        font.pixelSize: 12
        font.family: "M PLUS 2"
        font.letterSpacing: 0.5
        elide: Text.ElideRight
    }

    Text {
        Layout.fillWidth: true
        text: label.desc
        color: label.theme ? label.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
        font.pixelSize: 10
        font.family: "M PLUS 2"
        opacity: 0.6
        elide: Text.ElideRight
    }
}
