import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

Text {
    id: root

    property var theme

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    color: root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
    font.pixelSize: 10
    font.family: "M PLUS 2"
    opacity: root.text ? 0.85 : 0
    elide: Text.ElideRight
    Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }
}
