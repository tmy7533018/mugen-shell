import QtQuick
import QtQuick.Layouts
import "../../lib" as Theme

// A label for the cards below it, deliberately not a card itself: the shape is
// what tells you a click here acts on the whole app rather than one message.
Item {
    id: header

    property var modelData
    property var theme

    signal toggleRequested(var groupKey)
    signal dismissRequested(var memberIds)

    readonly property int count: modelData && modelData.groupCount ? modelData.groupCount : 0
    readonly property bool expanded: !!(modelData && modelData.groupExpanded)
    readonly property string appLabel: {
        if (!modelData) return ""
        if (modelData.appName && String(modelData.appName).length > 0) return String(modelData.appName)
        if (modelData.desktopEntry && String(modelData.desktopEntry).length > 0) return String(modelData.desktopEntry)
        return "Notifications"
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        radius: 10
        color: headerMouse.containsMouse
            ? (header.theme ? Qt.rgba(header.theme.glowPrimary.r, header.theme.glowPrimary.g, header.theme.glowPrimary.b, 0.10)
                            : Qt.rgba(0.65, 0.55, 0.85, 0.10))
            : "transparent"

        Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: header.toggleRequested(header.modelData.groupKey)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 8

            Text {
                text: header.expanded ? "▾" : "▸"
                color: header.theme ? header.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
                font.pixelSize: 10
                opacity: 0.9
            }

            Text {
                text: header.appLabel
                color: header.theme ? header.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.90)
                font.pixelSize: 11
                font.weight: Font.Medium
                font.family: "M PLUS 2"
                font.letterSpacing: 0.3
                elide: Text.ElideRight
                Layout.maximumWidth: 220
            }

            Rectangle {
                Layout.preferredHeight: 16
                Layout.preferredWidth: countText.implicitWidth + 12
                radius: 8
                color: header.theme
                    ? Qt.rgba(header.theme.glowPrimary.r, header.theme.glowPrimary.g, header.theme.glowPrimary.b, 0.18)
                    : Qt.rgba(0.65, 0.55, 0.85, 0.18)

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: header.count
                    color: header.theme ? header.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.family: "M PLUS 2"
                }
            }

            Item { Layout.fillWidth: true }

            // Collapsed shows only the newest member, so say what is still
            // folded away rather than leaving the count to imply it.
            Text {
                text: header.expanded
                    ? "Collapse"
                    : "+" + (header.count - 1) + " more"
                color: header.theme ? header.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 10
                font.family: "M PLUS 2"
                opacity: header.expanded ? (headerMouse.containsMouse ? 0.85 : 0.0) : 0.7
                Behavior on opacity { NumberAnimation { duration: Theme.Motion.micro } }
            }

            Rectangle {
                Layout.preferredHeight: 18
                Layout.preferredWidth: dismissText.implicitWidth + 14
                radius: 9
                opacity: headerMouse.containsMouse || dismissArea.containsMouse ? 1.0 : 0.0
                visible: opacity > 0.01
                color: dismissArea.containsMouse ? Qt.rgba(0.9, 0.35, 0.35, 0.18) : "transparent"
                border.width: 1
                border.color: dismissArea.containsMouse
                    ? Qt.rgba(0.9, 0.45, 0.45, 0.55)
                    : Qt.rgba(0.72, 0.72, 0.82, 0.25)

                Behavior on opacity { NumberAnimation { duration: Theme.Motion.micro } }
                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                Text {
                    id: dismissText
                    anchors.centerIn: parent
                    text: "Clear"
                    color: dismissArea.containsMouse
                        ? Qt.rgba(0.95, 0.6, 0.6, 1.0)
                        : (header.theme ? header.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90))
                    font.pixelSize: 10
                    font.family: "M PLUS 2"
                }

                MouseArea {
                    id: dismissArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: header.dismissRequested(header.modelData.groupMemberIds)
                }
            }
        }
    }
}
