import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

Rectangle {
    id: appRow

    required property var modelData
    property var theme
    property bool allowed: false

    signal toggleRequested()

    height: 32
    radius: 6
    color: appRow.allowed
        ? (appRow.theme ? Qt.rgba(appRow.theme.accent.r, appRow.theme.accent.g, appRow.theme.accent.b, 0.18) : Qt.rgba(0.65, 0.55, 0.85, 0.18))
        : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: appRow.modelData.display
                textFormat: Text.PlainText
                color: appRow.theme ? appRow.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.92)
                font.pixelSize: 11
                font.family: "M PLUS 2"
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: appRow.modelData.binary
                textFormat: Text.PlainText
                color: appRow.theme ? appRow.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.65)
                font.pixelSize: 9
                font.family: "M PLUS 2"
                opacity: 0.65
                elide: Text.ElideRight
            }
        }

        YuraPill {
            id: pill
            theme: appRow.theme
            on: appRow.allowed
            interactive: false
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: appRow.toggleRequested()
    }
}
