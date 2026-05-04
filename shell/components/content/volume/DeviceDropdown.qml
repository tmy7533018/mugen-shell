import QtQuick
import QtQuick.Layouts
import "../../common" as Common

Rectangle {
    id: dropdown

    required property var theme
    required property var typo
    required property var modeManager
    required property var audioManager
    required property bool isMicMode
    required property bool isVisible

    signal interactionOccurred()

    width: modeManager ? modeManager.scale(280) : 280
    property real maxHeight: modeManager ? modeManager.scale(250) : 250
    height: Math.min(dropdownFlickable.contentHeight + (modeManager ? modeManager.scale(16) : 16), maxHeight)

    color: theme ? theme.surfaceInsetCardHover : Qt.rgba(0.08, 0.08, 0.12, 0.75)
    radius: modeManager ? modeManager.scale(12) : 12
    border.width: 1
    border.color: theme ? theme.surfaceBorder : Qt.rgba(0.3, 0.3, 0.4, 0.3)

    visible: dropdown.isVisible
    opacity: dropdown.isVisible ? 1.0 : 0.0
    scale: dropdown.isVisible ? 1.0 : 0.95
    transformOrigin: Item.Top

    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Flickable {
        id: dropdownFlickable
        anchors.fill: parent
        anchors.margins: dropdown.modeManager ? dropdown.modeManager.scale(8) : 8
        contentWidth: width
        contentHeight: dropdownContent.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: false

            onClicked: (mouse) => { mouse.accepted = true }
            onPressed: (mouse) => { mouse.accepted = true }
            onReleased: (mouse) => { mouse.accepted = true }
            onPositionChanged: dropdown.interactionOccurred()

            onWheel: (wheel) => {
                let delta = wheel.angleDelta.y / 3
                dropdownFlickable.contentY = Math.max(0,
                    Math.min(dropdownFlickable.contentHeight - dropdownFlickable.height,
                        dropdownFlickable.contentY - delta))
                wheel.accepted = true
            }
        }

        Column {
            id: dropdownContent
            width: dropdownFlickable.width
            spacing: dropdown.modeManager ? dropdown.modeManager.scale(8) : 8

            Common.GlowText {
                visible: !dropdown.isMicMode
                text: "Output"
                color: Qt.rgba(0.7, 0.7, 0.8, 0.8)
                font.pixelSize: dropdown.modeManager ? dropdown.modeManager.scale(12) : 12
                font.weight: Font.Medium
                font.letterSpacing: 1
                enableGlow: false
            }

            Column {
                visible: !dropdown.isMicMode
                width: parent.width
                spacing: dropdown.modeManager ? dropdown.modeManager.scale(4) : 4

                Repeater {
                    model: dropdown.audioManager ? dropdown.audioManager.sinks : []

                    Rectangle {
                        width: parent.width
                        height: sinkText.implicitHeight + (dropdown.modeManager ? dropdown.modeManager.scale(12) : 12)
                        color: modelData.isDefault
                            ? Qt.rgba(dropdown.theme ? dropdown.theme.accent.r : 0.5, dropdown.theme ? dropdown.theme.accent.g : 0.4, dropdown.theme ? dropdown.theme.accent.b : 0.7, 0.25)
                            : (sinkMouseArea.containsMouse ? Qt.rgba(0.3, 0.3, 0.4, 0.3) : "transparent")
                        radius: dropdown.modeManager ? dropdown.modeManager.scale(6) : 6

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        Text {
                            id: sinkText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: dropdown.modeManager ? dropdown.modeManager.scale(8) : 8
                            text: modelData.description
                            color: modelData.isDefault ? Qt.rgba(0.95, 0.93, 0.98, 1.0) : Qt.rgba(0.85, 0.85, 0.9, 0.9)
                            font.pixelSize: dropdown.modeManager ? dropdown.modeManager.scale(13) : 13
                            font.family: dropdown.typo ? dropdown.typo.fontFamily : "M PLUS 2"
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: sinkMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                dropdown.audioManager.setDefaultSink(modelData.name)
                                dropdown.interactionOccurred()
                            }
                        }
                    }
                }
            }

            Common.GlowText {
                visible: dropdown.isMicMode
                text: "Input"
                color: Qt.rgba(0.7, 0.7, 0.8, 0.8)
                font.pixelSize: dropdown.modeManager ? dropdown.modeManager.scale(12) : 12
                font.weight: Font.Medium
                font.letterSpacing: 1
                enableGlow: false
            }

            Column {
                visible: dropdown.isMicMode
                width: parent.width
                spacing: dropdown.modeManager ? dropdown.modeManager.scale(4) : 4

                Repeater {
                    model: dropdown.audioManager ? dropdown.audioManager.sources : []

                    Rectangle {
                        width: parent.width
                        height: sourceText.implicitHeight + (dropdown.modeManager ? dropdown.modeManager.scale(12) : 12)
                        color: modelData.isDefault
                            ? Qt.rgba(dropdown.theme ? dropdown.theme.accent.r : 0.5, dropdown.theme ? dropdown.theme.accent.g : 0.4, dropdown.theme ? dropdown.theme.accent.b : 0.7, 0.25)
                            : (sourceMouseArea.containsMouse ? Qt.rgba(0.3, 0.3, 0.4, 0.3) : "transparent")
                        radius: dropdown.modeManager ? dropdown.modeManager.scale(6) : 6

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        Text {
                            id: sourceText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: dropdown.modeManager ? dropdown.modeManager.scale(8) : 8
                            text: modelData.description
                            color: modelData.isDefault ? Qt.rgba(0.95, 0.93, 0.98, 1.0) : Qt.rgba(0.85, 0.85, 0.9, 0.9)
                            font.pixelSize: dropdown.modeManager ? dropdown.modeManager.scale(13) : 13
                            font.family: dropdown.typo ? dropdown.typo.fontFamily : "M PLUS 2"
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: sourceMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                dropdown.audioManager.setDefaultSource(modelData.name)
                                dropdown.interactionOccurred()
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: scrollbar
        anchors.right: parent.right
        anchors.rightMargin: dropdown.modeManager ? dropdown.modeManager.scale(3) : 3
        anchors.top: parent.top
        anchors.topMargin: (dropdown.modeManager ? dropdown.modeManager.scale(8) : 8) + (dropdownFlickable.height - scrollbar.height) * (dropdownFlickable.contentY / (dropdownFlickable.contentHeight - dropdownFlickable.height))

        width: dropdown.modeManager ? dropdown.modeManager.scale(3) : 3
        height: Math.max(dropdown.modeManager ? dropdown.modeManager.scale(20) : 20, dropdownFlickable.height * (dropdownFlickable.height / dropdownFlickable.contentHeight))
        radius: dropdown.modeManager ? dropdown.modeManager.scale(1.5) : 1.5

        color: Qt.rgba(0.6, 0.6, 0.7, 0.5)

        visible: dropdownFlickable.contentHeight > dropdownFlickable.height
        opacity: dropdownFlickable.moving ? 0.8 : 0.4

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
}
