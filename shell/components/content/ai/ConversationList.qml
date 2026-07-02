import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../../ui" as UI
import "../../common" as Common
import "../../../lib" as Theme

FocusScope {
    id: root

    required property var modeManager
    required property var theme
    required property var icons

    property var conversations: []
    property int currentId: 0

    signal newChatRequested()
    signal conversationSelected(int convId)
    signal conversationDeleteRequested(int convId)
    signal toggleRequested()

    function relativeTime(unixSeconds) {
        let now = Math.floor(Date.now() / 1000)
        let diff = now - unixSeconds
        if (diff < 60) return "just now"
        if (diff < 3600) return Math.floor(diff / 60) + "m"
        if (diff < 86400) return Math.floor(diff / 3600) + "h"
        if (diff < 86400 * 7) return Math.floor(diff / 86400) + "d"
        let d = new Date(unixSeconds * 1000)
        return Qt.formatDate(d, "MMM d")
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.015, 0.06, 0.55)
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Qt.rgba(0.55, 0.55, 0.75, 0.12)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: modeManager.scale(10)
        spacing: modeManager.scale(8)

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: modeManager.scale(34)

            Common.GlowText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: modeManager.scale(6)
                text: "Yura"
                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                font.pixelSize: modeManager.scale(17)
                font.family: "M PLUS 2"
                font.weight: Font.Normal
                font.letterSpacing: 1.0
                font.italic: true

                enableGlow: true
                glowColor: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5)
                glowSamples: 18
                glowRadius: 10
                glowSpread: 0.4
            }

            Item {
                id: toggleBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: modeManager.scale(28)
                height: modeManager.scale(28)

                UI.SvgIcon {
                    anchors.centerIn: parent
                    width: modeManager.scale(17)
                    height: modeManager.scale(17)
                    source: root.icons ? root.icons.sidebarSvg : ""
                    color: toggleMouse.containsMouse
                        ? (root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))
                        : (root.theme ? root.theme.textSecondary : Qt.rgba(0.78, 0.78, 0.88, 0.85))
                    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                }

                MouseArea {
                    id: toggleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleRequested()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: modeManager.scale(36)
            radius: modeManager.scale(10)
            color: newChatMouse.containsMouse
                ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.22) : Qt.rgba(0.65, 0.55, 0.85, 0.22))
                : Qt.rgba(0.55, 0.55, 0.75, 0.08)
            border.color: Qt.rgba(0.55, 0.55, 0.75, 0.15)
            border.width: 1

            Behavior on color { ColorAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: modeManager.scale(12)
                anchors.rightMargin: modeManager.scale(12)
                spacing: modeManager.scale(8)

                UI.SvgIcon {
                    Layout.preferredWidth: modeManager.scale(13)
                    Layout.preferredHeight: modeManager.scale(13)
                    source: root.icons ? root.icons.plusSvg : ""
                    color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                }

                Text {
                    Layout.fillWidth: true
                    text: "New chat"
                    color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                    font.pixelSize: modeManager.scale(12)
                    font.family: "M PLUS 2"
                    font.letterSpacing: 0.3
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: newChatMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.newChatRequested()
            }
        }

        Text {
            Layout.topMargin: modeManager.scale(6)
            Layout.leftMargin: modeManager.scale(4)
            text: "Recent"
            color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.6)
            font.pixelSize: modeManager.scale(10)
            font.family: "M PLUS 2"
            font.letterSpacing: 1.2
            visible: root.conversations.length > 0
        }

        ListView {
            id: convList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: modeManager.scale(2)
            model: root.conversations
            interactive: contentHeight > height

            delegate: Item {
                width: ListView.view.width
                height: row.height

                readonly property bool isActive: modelData.id === root.currentId

                Rectangle {
                    id: row
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: rowCol.implicitHeight + modeManager.scale(12)
                    radius: modeManager.scale(8)
                    color: parent.isActive
                        ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.18) : Qt.rgba(0.65, 0.55, 0.85, 0.18))
                        : (rowMouse.containsMouse ? Qt.rgba(0.55, 0.55, 0.75, 0.10) : "transparent")

                    Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

                    ColumnLayout {
                        id: rowCol
                        anchors.left: parent.left
                        anchors.right: deleteBtn.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: modeManager.scale(10)
                        anchors.rightMargin: modeManager.scale(4)
                        spacing: modeManager.scale(2)

                        Text {
                            Layout.fillWidth: true
                            text: modelData.title && modelData.title.length > 0 ? modelData.title : "New chat"
                            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                            font.pixelSize: modeManager.scale(12)
                            font.family: "M PLUS 2"
                            font.letterSpacing: 0.2
                            font.italic: !(modelData.title && modelData.title.length > 0)
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.relativeTime(modelData.updated_at)
                            color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.55)
                            font.pixelSize: modeManager.scale(9)
                            font.family: "M PLUS 2"
                            font.letterSpacing: 0.4
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.conversationSelected(modelData.id)
                    }

                    Item {
                        id: deleteBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: modeManager.scale(8)
                        width: modeManager.scale(20)
                        height: modeManager.scale(20)
                        opacity: rowMouse.containsMouse || deleteMouse.containsMouse ? 1.0 : 0.0
                        z: 1

                        Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }

                        UI.SvgIcon {
                            anchors.centerIn: parent
                            width: modeManager.scale(12)
                            height: modeManager.scale(12)
                            source: root.icons ? root.icons.trashSvg : ""
                            color: deleteMouse.containsMouse
                                ? Qt.rgba(0.95, 0.55, 0.65, 1.0)
                                : (root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.7))
                            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                        }

                        MouseArea {
                            id: deleteMouse
                            anchors.fill: parent
                            anchors.margins: -modeManager.scale(4)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.conversationDeleteRequested(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
