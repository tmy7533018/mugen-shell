import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root

    property var theme
    property string title: ""
    property string summaryText: ""
    property bool summaryItalic: false
    property bool expanded: false
    property int titleElide: Text.ElideRight

    signal toggleRequested()

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 64
    cursorShape: Qt.PointingHandCursor

    TapHandler {
        onTapped: root.toggleRequested()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.title
            color: root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.letterSpacing: 0.5
            elide: root.titleElide
        }

        Text {
            text: root.summaryText
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            font.pixelSize: 11
            font.family: "M PLUS 2"
            font.italic: root.summaryItalic
            opacity: 0.85
        }

        Text {
            text: root.expanded ? "▴" : "▾"
            color: root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            opacity: 0.7
        }
    }
}
