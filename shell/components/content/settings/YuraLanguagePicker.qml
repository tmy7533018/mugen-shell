pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

RowLayout {
    id: root

    property var theme
    property string language: ""
    property string filter: ""
    property bool open: false
    property var options: []
    property var allOptions: []

    signal openToggled()
    signal filterEdited(string text)
    signal picked(string code)

    Layout.fillWidth: true
    spacing: 8

    Text {
        Layout.preferredWidth: 80
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: 6
        text: "Language"
        color: root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
        font.pixelSize: 11
        font.family: "M PLUS 2"
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: 8
            color: langHeaderMouse.containsMouse
                ? Qt.rgba(0.45, 0.45, 0.60, 0.2)
                : "transparent"
            border.width: 1
            border.color: root.theme ? root.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18)
            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (!root.language) return "Auto — match the user's language"
                    let opt = root.allOptions.find(l => l.code === root.language)
                    return opt ? root.language + " — " + opt.name : root.language
                }
                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                font.pixelSize: 11
                font.family: "M PLUS 2"
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.open ? "▴" : "▾"
                color: root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 11
                font.family: "M PLUS 2"
                opacity: 0.7
            }

            MouseArea {
                id: langHeaderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openToggled()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            visible: root.open
            radius: 8
            color: root.theme ? root.theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.3)
            border.width: 1
            border.color: root.theme ? root.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18)
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    color: "transparent"
                    radius: 6
                    border.width: 1
                    border.color: filterInput.activeFocus
                        ? (root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                        : Qt.rgba(1, 1, 1, 0.10)
                    Behavior on border.color { ColorAnimation { duration: Theme.Motion.micro } }

                    TextInput {
                        id: filterInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        text: root.filter
                        color: root.theme ? root.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                        selectionColor: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                        font.pixelSize: 11
                        font.family: "M PLUS 2"
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        onTextChanged: root.filterEdited(text)

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "filter by code or name…"
                            color: root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.5)
                            font: filterInput.font
                            opacity: filterInput.text.length === 0 ? 0.5 : 0
                        }
                    }
                }

                ListView {
                    id: langList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 0
                    model: root.options
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: langRow
                        required property var modelData
                        width: langList.width
                        height: 24
                        radius: 4
                        color: root.language === langRow.modelData.code
                            ? (root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25))
                            : (langItemMouse.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.05)
                                : "transparent")

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: (langRow.modelData.code ? langRow.modelData.code + " — " : "") + langRow.modelData.name
                            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                            font.pixelSize: 10
                            font.family: "M PLUS 2"
                        }

                        MouseArea {
                            id: langItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.picked(langRow.modelData.code)
                        }
                    }
                }
            }
        }
    }
}
