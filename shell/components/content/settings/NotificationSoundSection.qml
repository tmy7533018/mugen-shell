import QtQuick
import QtQuick.Layouts

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager
    required property var sounds

    signal applySound(string name)

    width: parent ? parent.width : 420
    height: section.isExpanded ? 64 + Math.min(section.sounds.length, 6) * 36 + 12 : 64
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)
    clip: true

    property bool isExpanded: false

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    Behavior on height {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    MouseArea {
        id: soundHeader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 64
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        TapHandler {
            onTapped: {
                section.isExpanded = !section.isExpanded
                section.bump()
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Notification Sound"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Normal
                font.letterSpacing: 0.5
            }

            Text {
                text: section.settingsManager ? section.settingsManager.notificationSound : "None"
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Medium
            }

            Text {
                text: section.isExpanded ? "▴" : "▾"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
            }
        }
    }

    ListView {
        id: soundList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: soundHeader.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 12
        clip: true
        model: section.sounds
        visible: section.isExpanded
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            width: soundList.width
            height: 36
            radius: 8
            property bool isCurrent: section.settingsManager && modelData === section.settingsManager.notificationSound

            color: soundMouseArea.containsMouse
                ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25))
                : (isCurrent
                    ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4))
                    : "transparent")

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                text: modelData
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: isCurrent ? Font.Medium : Font.Normal
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 12
                text: "✓"
                visible: isCurrent
                color: section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                font.pixelSize: 12
                font.family: "M PLUS 2"
            }

            MouseArea {
                id: soundMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                onClicked: {
                    section.applySound(modelData)
                    section.isExpanded = false
                    section.bump()
                }
            }
        }
    }
}
