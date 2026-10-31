pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../common" as Common
import "../../../lib" as Theme

Rectangle {
    id: form

    required property var theme
    required property string name
    required property string command
    required property string url
    required property string env

    signal fieldEdited(string key, string text)
    signal envEdited(string text)
    signal cancelRequested()
    signal addRequested()

    Layout.fillWidth: true
    Layout.preferredHeight: addForm.implicitHeight + 20
    radius: 10
    color: form.theme ? form.theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.3)
    border.width: 1
    border.color: form.theme ? form.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.12)

    ColumnLayout {
        id: addForm
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 10
        spacing: 6

        Repeater {
            model: [
                { key: "name", label: "Name", hint: "memory" },
                { key: "command", label: "Command", hint: "npx -y @modelcontextprotocol/server-memory" },
                { key: "url", label: "URL", hint: "http://host:port/mcp — remote server, instead of a command" }
            ]

            RowLayout {
                id: fieldRow
                required property var modelData
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.preferredWidth: 64
                    text: fieldRow.modelData.label
                    color: form.theme ? form.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    color: "transparent"
                    radius: 8
                    border.width: 1
                    border.color: fieldInput.activeFocus
                        ? (form.theme ? form.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                        : (form.theme ? form.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18))
                    Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

                    TextInput {
                        id: fieldInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        text: fieldRow.modelData.key === "name" ? form.name
                            : fieldRow.modelData.key === "command" ? form.command
                            : form.url
                        color: form.theme ? form.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                        selectionColor: form.theme ? Qt.rgba(form.theme.glowPrimary.r, form.theme.glowPrimary.g, form.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                        font.pixelSize: 11
                        font.family: "M PLUS 2"
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        onTextChanged: form.fieldEdited(fieldRow.modelData.key, text)

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 0
                            verticalAlignment: Text.AlignVCenter
                            visible: parent.text.length === 0
                            text: fieldRow.modelData.hint
                            color: form.theme ? form.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.45)
                            font.pixelSize: 10
                            font.family: "M PLUS 2"
                            opacity: 0.5
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Env (optional) — KEY=value per line. Stored as plaintext in config.toml; use ${VAR} to read a secret from the environment instead."
            color: form.theme ? form.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "transparent"
            radius: 8
            border.width: 1
            border.color: envInput.activeFocus
                ? (form.theme ? form.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                : (form.theme ? form.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18))
            Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }
            clip: true

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true

                TextArea {
                    id: envInput
                    text: form.env
                    color: form.theme ? form.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                    selectionColor: form.theme ? Qt.rgba(form.theme.glowPrimary.r, form.theme.glowPrimary.g, form.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                    font.pixelSize: 10
                    font.family: "M PLUS 2"
                    wrapMode: TextEdit.Wrap
                    background: null
                    padding: 0
                    onTextChanged: form.envEdited(text)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8

            Item { Layout.fillWidth: true }

            Common.SubtleButton {
                theme: form.theme
                label: "Cancel"
                buttonWidth: 70
                buttonHeight: 26
                fontSize: 10
                onClicked: form.cancelRequested()
            }

            Common.SubtleButton {
                theme: form.theme
                label: "Add to list"
                buttonWidth: 90
                buttonHeight: 26
                fontSize: 10
                fontWeight: Font.Medium
                tint: Qt.rgba(0.45, 0.65, 0.90, 0.30)
                tintHover: Qt.rgba(0.45, 0.65, 0.90, 0.45)
                onClicked: form.addRequested()
            }
        }
    }
}
