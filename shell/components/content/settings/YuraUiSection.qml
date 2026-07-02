import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    width: parent ? parent.width : 420
    height: contentColumn.implicitHeight + 24
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    readonly property var collapsePresets: [0, 1, 3, 5, 10]
    readonly property var speedOptions: ["instant", "fast", "normal", "slow"]

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function save() {
        if (settingsManager) settingsManager.saveSettings()
        section.bump()
    }

    component RowLabel: ColumnLayout {
        property string title: ""
        property string desc: ""
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 2

        Text {
            Layout.fillWidth: true
            text: parent.title
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.letterSpacing: 0.5
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: parent.desc
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            opacity: 0.6
            elide: Text.ElideRight
        }
    }

    component Chip: Rectangle {
        property string label: ""
        property bool selected: false
        signal clicked()

        width: chipText.implicitWidth + 16
        height: 22
        radius: 11
        color: selected
            ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.45) : Qt.rgba(0.65, 0.55, 0.85, 0.45))
            : (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
        border.width: 1
        border.color: selected
            ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95))
            : Qt.rgba(1, 1, 1, 0.10)

        Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: parent.label
            color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            font.pixelSize: 10
            font.family: "M PLUS 2"
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLabel {
                title: "Idle orb breath"
                desc: "Slow breathing pulse on Yura's orb while idle"
            }

            Rectangle {
                id: breathPill
                Layout.preferredWidth: 44
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                radius: 12

                readonly property bool on: section.settingsManager && section.settingsManager.yuraIdleBreath

                color: breathPill.on
                    ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                    : Qt.rgba(0.3, 0.3, 0.36, 0.5)
                border.width: 1
                border.color: breathPill.on
                    ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95))
                    : Qt.rgba(1, 1, 1, 0.10)
                Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                    y: 3
                    x: breathPill.on ? breathPill.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!section.settingsManager) return
                        section.settingsManager.yuraIdleBreath = !section.settingsManager.yuraIdleBreath
                        section.save()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLabel {
                title: "Auto-collapse"
                desc: "Close the float panel after idle minutes"
            }

            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: section.collapsePresets

                    Chip {
                        required property int modelData
                        label: modelData === 0 ? "Off" : modelData + "m"
                        selected: section.settingsManager
                            && section.settingsManager.yuraAutoCollapseMin === modelData
                        onClicked: {
                            if (!section.settingsManager) return
                            section.settingsManager.yuraAutoCollapseMin = modelData
                            section.save()
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLabel {
                title: "Typing speed"
                desc: "Typewriter reveal for streamed replies"
            }

            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: section.speedOptions

                    Chip {
                        required property string modelData
                        label: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        selected: section.settingsManager
                            && section.settingsManager.yuraTypingSpeed === modelData
                        onClicked: {
                            if (!section.settingsManager) return
                            section.settingsManager.yuraTypingSpeed = modelData
                            section.save()
                        }
                    }
                }
            }
        }
    }
}
