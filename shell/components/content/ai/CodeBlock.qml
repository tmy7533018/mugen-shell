import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../../ui" as UI

Item {
    id: root

    required property var modeManager
    required property var theme
    required property var icons
    property string lang: ""
    property string code: ""

    // Emitted when the copy icon is clicked. The parent owns a single shared
    // wl-copy Process — keeping it out of CodeBlock means a chat with many
    // code blocks doesn't stack up that many idle Process instances.
    signal copyRequested(string text)

    implicitHeight: container.implicitHeight
    implicitWidth: parent ? parent.width : 200

    Rectangle {
        id: container
        anchors.left: parent.left
        anchors.right: parent.right
        radius: modeManager.scale(8)
        color: Qt.rgba(0.04, 0.03, 0.10, 0.55)
        border.color: Qt.rgba(0.55, 0.55, 0.75, 0.18)
        border.width: 1
        implicitHeight: layout.implicitHeight + modeManager.scale(2)

        property bool justCopied: false

        ColumnLayout {
            id: layout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0

            // Top bar: language + copy
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: modeManager.scale(26)

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: modeManager.scale(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.lang || "code"
                    color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.7)
                    font.pixelSize: modeManager.scale(10)
                    font.family: "M PLUS 2"
                    font.letterSpacing: 0.6
                }

                Item {
                    id: copyBtn
                    anchors.right: parent.right
                    anchors.rightMargin: modeManager.scale(8)
                    anchors.verticalCenter: parent.verticalCenter
                    width: modeManager.scale(22)
                    height: modeManager.scale(22)
                    opacity: hoverArea.containsMouse || copyMouse.containsMouse || container.justCopied ? 1.0 : 0.55

                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    UI.SvgIcon {
                        anchors.centerIn: parent
                        width: modeManager.scale(13)
                        height: modeManager.scale(13)
                        source: root.icons ? root.icons.copySvg : ""
                        color: container.justCopied
                            ? (root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1.0))
                            : (copyMouse.containsMouse
                                ? (root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))
                                : (root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.7)))
                        Behavior on color { ColorAnimation { duration: 180 } }

                        layer.enabled: copyMouse.containsMouse || container.justCopied
                        layer.effect: Glow {
                            samples: 14
                            radius: 6
                            spread: 0.25
                            color: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.7) : Qt.rgba(0.65, 0.55, 0.85, 0.7)
                            transparentBorder: true
                        }
                    }

                    MouseArea {
                        id: copyMouse
                        anchors.fill: parent
                        anchors.margins: -modeManager.scale(4)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.copyRequested(root.code)
                            container.justCopied = true
                            resetTimer.restart()
                        }
                    }
                }
            }

            // Faint divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(0.55, 0.55, 0.75, 0.12)
            }

            // Code body
            TextEdit {
                Layout.fillWidth: true
                Layout.leftMargin: modeManager.scale(12)
                Layout.rightMargin: modeManager.scale(12)
                Layout.topMargin: modeManager.scale(10)
                Layout.bottomMargin: modeManager.scale(12)
                text: root.code
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95)
                selectionColor: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.35) : Qt.rgba(0.65, 0.55, 0.85, 0.35)
                font.family: "JetBrainsMono Nerd Font, monospace"
                font.pixelSize: modeManager.scale(12)
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
        }

        Timer {
            id: resetTimer
            interval: 1100
            repeat: false
            onTriggered: container.justCopied = false
        }
    }

}
