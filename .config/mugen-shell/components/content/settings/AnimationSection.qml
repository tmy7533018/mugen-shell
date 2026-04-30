import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    width: parent ? parent.width : 420
    height: section.isExpanded ? 120 : 64
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)
    clip: false

    property bool isExpanded: false
    property var animOptions: ["slow", "normal", "fast", "instant"]

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    Behavior on height {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        MouseArea {
            Layout.fillWidth: true
            Layout.preferredHeight: section.modeManager ? section.modeManager.scale(40) : 40
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
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: "Animation Speed"
                    color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    font.weight: Font.Normal
                    font.letterSpacing: 0.5
                }

                Text {
                    text: {
                        if (!section.settingsManager) return "..."
                        let speed = section.settingsManager.animationSpeed
                        return speed.charAt(0).toUpperCase() + speed.slice(1)
                    }
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    font.weight: Font.Medium
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: section.isExpanded ? 44 : 0
            visible: section.isExpanded
            opacity: section.isExpanded ? 1.0 : 0.0

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }

            ListView {
                id: animList
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(contentWidth, parent.width)
                height: parent.height
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                model: section.animOptions
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                interactive: section.isExpanded && contentWidth > width

                onVisibleChanged: {
                    if (visible && section.settingsManager) {
                        let index = section.animOptions.indexOf(section.settingsManager.animationSpeed)
                        if (index >= 0) {
                            Qt.callLater(() => {
                                animList.currentIndex = index
                                animList.positionViewAtIndex(index, ListView.Center)
                            })
                        }
                    }
                }

                delegate: Rectangle {
                    width: Math.max(animText.implicitWidth + 24, 80)
                    height: 36
                    radius: 8
                    property bool isCurrent: section.settingsManager && section.settingsManager.animationSpeed === modelData

                    color: animMouseArea.containsMouse
                        ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25))
                        : (isCurrent
                            ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.95) : Qt.rgba(0.65, 0.55, 0.85, 0.95))
                            : (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.15) : Qt.rgba(0.65, 0.55, 0.85, 0.15)))

                    border.width: isCurrent ? 1 : 0
                    border.color: section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Text {
                        id: animText
                        anchors.centerIn: parent
                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        color: isCurrent
                            ? (section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))
                            : (section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.70))
                        font.pixelSize: 12
                        font.family: "M PLUS 2"
                        font.weight: isCurrent ? Font.Medium : Font.Normal
                    }

                    MouseArea {
                        id: animMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onClicked: {
                            if (section.settingsManager) {
                                section.settingsManager.animationSpeed = modelData
                                section.settingsManager.updateAnimationMultiplier()
                                section.settingsManager.saveSettings()
                            }
                            section.isExpanded = false
                            section.bump()
                        }
                    }
                }

                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    height: 4

                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                    }
                }
            }
        }
    }
}
