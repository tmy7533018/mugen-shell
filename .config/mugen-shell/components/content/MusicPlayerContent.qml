import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import "." as MusicUI
import "../common" as Common

Item {
    id: root
    
    required property var modeManager
    property var musicManager
    property var cavaManager
    property var theme
    property var icons
    
    readonly property var requiredBarSize: ({
        "height": modeManager.scale(120),
        "leftMargin": modeManager.scale(580),
        "rightMargin": modeManager.scale(580),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })
    
    function resetAutoCloseTimer() {
        modeManager.bump()
    }


    MouseArea {
        anchors.fill: parent
        z: 1.5
        enabled: modeManager.isMode("music")
        visible: enabled
        hoverEnabled: true
        
        onClicked: {
            modeManager.closeAllModes()
        }

        onPositionChanged: {
            if (modeManager.isMode("music")) {
                root.resetAutoCloseTimer()
            }
        }
    }
    
    Item {
        id: musicLayer
        anchors.fill: parent
        anchors.leftMargin: modeManager.scale(32)
        anchors.rightMargin: modeManager.scale(32)
        z: 3

        focus: modeManager.isMode("music")
        Keys.onPressed: (event) => {
            if (modeManager.isMode("music")) {
                root.resetAutoCloseTimer()
            }
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
            } else if (event.key === Qt.Key_Space) {
                if (root.musicManager) {
                    root.musicManager.playPause()
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Left) {
                if (root.musicManager) {
                    root.musicManager.previous()
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                if (root.musicManager) {
                    root.musicManager.next()
                }
                event.accepted = true
            }
        }
        
        opacity: 0
        visible: true
        
        states: [
            State {
                name: "visible"
                when: modeManager.isMode("music")
                PropertyChanges { target: musicLayer; opacity: 1.0 }
            }
        ]
        
        transitions: [
            Transition {
                from: "visible"
                to: ""
                NumberAnimation {
                    property: "opacity"
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: 300 }  // wait for bar expand animation
                    NumberAnimation {
                        property: "opacity"
                        duration: 400
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        ]

        RowLayout {
            anchors.centerIn: parent
            spacing: modeManager.scale(12)
            z: 1.5
            
            MusicUI.AlbumArtDisplay {
                id: albumArtDisplay
                Layout.alignment: Qt.AlignVCenter
                musicManager: root.musicManager
                cavaManager: root.cavaManager
                theme: root.theme
                icons: root.icons
                modeManager: root.modeManager
            }
            
            MusicUI.SongInfoDisplay {
                Layout.alignment: Qt.AlignVCenter
                musicManager: root.musicManager
                cavaManager: root.cavaManager
                theme: root.theme
                modeManager: root.modeManager
                extractedColor: albumArtDisplay.extractedColor
            }
            
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: modeManager.scale(10)

                RowLayout {
                    spacing: modeManager.scale(12)
                    Layout.alignment: Qt.AlignHCenter

                    MusicUI.MusicControlButton {
                        modeManager: root.modeManager
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 56
                        implicitHeight: 56
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight
                        backgroundColor: Qt.rgba(albumArtDisplay.extractedColor.r, albumArtDisplay.extractedColor.g, albumArtDisplay.extractedColor.b, 1.0)
                        hoverScale: 1.12
                        iconSource: root.icons && root.icons.getPreviousIcon().type === "svg" ? root.icons.getPreviousIcon().value : ""
                        icon: root.icons && root.icons.getPreviousIcon().type === "text" ? root.icons.getPreviousIcon().value : ""
                        iconBaseColor: theme ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.65) : Qt.rgba(1, 1, 1, 0.6)
                        iconHoverColor: theme ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.95) : Qt.rgba(1, 1, 1, 0.95)
                        onClicked: {
                            root.resetAutoCloseTimer()
                            if (root.musicManager) {
                                root.musicManager.previous()
                            }
                        }
                    }

                    MusicUI.MusicControlButton {
                        modeManager: root.modeManager
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 68
                        implicitHeight: 68
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight
                        backgroundColor: Qt.rgba(albumArtDisplay.extractedColor.r, albumArtDisplay.extractedColor.g, albumArtDisplay.extractedColor.b, 1.0)
                        hoverScale: 1.18
                        iconRatio: 0.48
                        iconSource: (root.icons && root.musicManager && root.icons.getPlayPauseIcon(root.musicManager.isPlaying).type === "svg")
                                    ? root.icons.getPlayPauseIcon(root.musicManager.isPlaying).value
                                    : ""
                        icon: (root.icons && root.musicManager && root.icons.getPlayPauseIcon(root.musicManager.isPlaying).type === "text")
                              ? root.icons.getPlayPauseIcon(root.musicManager.isPlaying).value
                              : (!root.icons && root.musicManager ? (root.musicManager.isPlaying ? "⏸" : "▶") : "")
                        iconBaseColor: theme ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.7) : Qt.rgba(1, 1, 1, 0.7)
                        iconHoverColor: theme ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.98) : Qt.rgba(1, 1, 1, 0.95)
                        onClicked: {
                            root.resetAutoCloseTimer()
                            if (root.musicManager) {
                                root.musicManager.playPause()
                            }
                        }
                    }

                    MusicUI.MusicControlButton {
                        modeManager: root.modeManager
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 56
                        implicitHeight: 56
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight
                        backgroundColor: Qt.rgba(albumArtDisplay.extractedColor.r, albumArtDisplay.extractedColor.g, albumArtDisplay.extractedColor.b, 1.0)
                        hoverScale: 1.12
                        iconSource: root.icons && root.icons.getNextIcon().type === "svg" ? root.icons.getNextIcon().value : ""
                        icon: root.icons && root.icons.getNextIcon().type === "text" ? root.icons.getNextIcon().value : ""
                        iconBaseColor: theme ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.65) : Qt.rgba(1, 1, 1, 0.6)
                        iconHoverColor: theme ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.95) : Qt.rgba(1, 1, 1, 0.95)
                        onClicked: {
                            root.resetAutoCloseTimer()
                            if (root.musicManager) {
                                root.musicManager.next()
                            }
                        }
                    }
                }

                // Seekable progress slider
                Item {
                    id: progressSlider
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: modeManager.scale(130)
                    Layout.preferredHeight: modeManager.scale(14)
                    visible: root.musicManager && root.musicManager.isAvailable

                    readonly property real ratio: (root.musicManager && root.musicManager.duration > 0)
                        ? Math.max(0, Math.min(1, root.musicManager.position / root.musicManager.duration))
                        : 0

                    Rectangle {
                        id: track
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: modeManager.scale(3)
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, sliderArea.containsMouse || sliderArea.pressed ? 0.22 : 0.15)
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            id: filled
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * progressSlider.ratio
                            radius: parent.radius
                            color: Qt.rgba(albumArtDisplay.extractedColor.r, albumArtDisplay.extractedColor.g, albumArtDisplay.extractedColor.b, 0.55)

                            layer.enabled: true
                            layer.effect: Glow {
                                samples: 32
                                radius: 14
                                spread: 0.5
                                color: Qt.rgba(albumArtDisplay.extractedColor.r, albumArtDisplay.extractedColor.g, albumArtDisplay.extractedColor.b, 0.55)
                                transparentBorder: true
                            }

                            Behavior on width {
                                enabled: !sliderArea.pressed
                                NumberAnimation { duration: 800; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    MouseArea {
                        id: sliderArea
                        anchors.fill: parent
                        anchors.margins: -modeManager.scale(6)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function seekFromX(x) {
                            if (!root.musicManager || root.musicManager.duration <= 0) return
                            const clamped = Math.max(0, Math.min(progressSlider.width, x - (progressSlider.x - parent.x)))
                            const r = clamped / progressSlider.width
                            root.musicManager.seek(root.musicManager.duration * r)
                        }

                        onPressed: (mouse) => {
                            if (!root.musicManager) return
                            root.musicManager.seekingSuspended = true
                            seekFromX(mouse.x + sliderArea.x)
                            root.resetAutoCloseTimer()
                        }
                        onPositionChanged: (mouse) => {
                            if (pressed) seekFromX(mouse.x + sliderArea.x)
                        }
                        onReleased: {
                            if (root.musicManager) root.musicManager.seekingSuspended = false
                        }
                        onCanceled: {
                            if (root.musicManager) root.musicManager.seekingSuspended = false
                        }
                    }
                }
            }
        }
        
        Common.GlowText {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -70
            text: "Dream rhythm loading..."
            color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
            font.pixelSize: 22
            font.weight: Font.Light
            opacity: 0.5
            visible: !root.musicManager || !root.musicManager.isAvailable
            
            glowColor: Qt.rgba(albumArtDisplay.extractedColor.r, albumArtDisplay.extractedColor.g, albumArtDisplay.extractedColor.b, 0.35)
            glowRadius: 6
            glowSpread: 0.25
            glowSamples: 13
            enableGlow: true
            
            SequentialAnimation on opacity {
                running: !root.musicManager || !root.musicManager.isAvailable
                loops: Animation.Infinite
                NumberAnimation { from: 0.3; to: 0.6; duration: 1500; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.6; to: 0.3; duration: 1500; easing.type: Easing.InOutQuad }
            }
        }
    }
    
    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("music", root)
        }
    }
}
