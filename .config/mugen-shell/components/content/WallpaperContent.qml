import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../ui" as UI
import "../common" as Common

FocusScope {
    id: root

    required property var modeManager
    required property var wallpaperManager
    property var theme
    property var icons

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(240),
        "leftMargin": modeManager.scale(550),
        "rightMargin": modeManager.scale(550),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })

    function setWallpaper(path) {
        wallpaperManager.setWallpaper(path)
        modeManager.closeAllModes()
    }

    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("wallpaper", root)
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("wallpaper")) {
                wallpaperManager.loadWallpapers()
                // Increase delay to ensure IPC triggers work reliably
                focusTimer.restart()
                autoCloseTimer.restart()
            } else {
                autoCloseTimer.stop()
            }
        }
    }

    Timer {
        id: autoCloseTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            if (modeManager.isMode("wallpaper")) {
                modeManager.closeAllModes()
            }
        }
    }

    function resetAutoCloseTimer() {
        if (modeManager.isMode("wallpaper")) {
            autoCloseTimer.restart()
        }
    }

    // Longer interval to wait for PanelWindow.forceActiveFocus()
    Timer {
        id: focusTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (wallpaperLayer) {
                wallpaperLayer.forceActiveFocus()
            }
            Qt.callLater(() => {
                if (listView) {
                    listView.forceActiveFocus()
                    if (!listView.activeFocus) {
                        Qt.callLater(() => {
                            if (listView) {
                                listView.forceActiveFocus()
                            }
                        })
                    }
                }
            })
        }
    }

    function updateFocusToCurrentWallpaper() {
        if (wallpaperManager.wallpapers.length > 0 && wallpaperManager.currentWallpaperPath.length > 0) {
            Qt.callLater(function() {
                let index = 0
                for (let i = 0; i < wallpaperManager.wallpapers.length; i++) {
                    if (wallpaperManager.wallpapers[i] === wallpaperManager.currentWallpaperPath) {
                        index = i
                        break
                    }
                }
                if (listView) {
                    listView.positionViewAtIndex(index, ListView.Center)
                    listView.currentIndex = index
                }
            })
        }
    }

    Connections {
        target: wallpaperManager
        function onWallpapersChanged() {
            updateFocusToCurrentWallpaper()
        }

        function onCurrentWallpaperPathChanged() {
            updateFocusToCurrentWallpaper()
        }
    }

    Item {
        id: wallpaperLayer
        anchors.fill: parent
        anchors.leftMargin: modeManager.scale(560)
        anchors.rightMargin: modeManager.scale(560)
        anchors.topMargin: modeManager.scale(20)
        anchors.bottomMargin: modeManager.scale(20)
        visible: modeManager.isMode("wallpaper")
        z: 10

        focus: modeManager.isMode("wallpaper")

        Keys.forwardTo: [listView]

        Keys.onPressed: (event) => {
            if (modeManager.isMode("wallpaper")) {
                root.resetAutoCloseTimer()
            }
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            Common.GlowText {
                Layout.alignment: Qt.AlignHCenter
                text: "select wallpaper"
                color: Qt.rgba(0.95, 0.93, 0.98, 0.95)
                font.pixelSize: modeManager.scale(20)
                font.family: "M PLUS 2"
                font.weight: Font.Light
                font.letterSpacing: 1.5
                enableGlow: true
                glowColor: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6)
                glowSamples: 20
                glowRadius: modeManager.scale(12)
                glowSpread: 0.5
            }

            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true

                model: wallpaperManager.wallpapers
                orientation: ListView.Horizontal
                spacing: modeManager.scale(16)
                clip: true

                highlightFollowsCurrentItem: true
                highlightMoveDuration: 300
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: width / 2 - modeManager.scale(120)
                preferredHighlightEnd: width / 2 + modeManager.scale(120)
                snapMode: ListView.SnapToItem

                focus: true

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        modeManager.closeAllModes()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (currentIndex >= 0) {
                            root.setWallpaper(wallpaperManager.wallpapers[currentIndex])
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        if (currentIndex > 0) {
                            currentIndex--
                            root.resetAutoCloseTimer()
                            event.accepted = true
                        } else {
                            event.accepted = false
                        }
                    } else if (event.key === Qt.Key_Right) {
                        if (currentIndex < count - 1) {
                            currentIndex++
                            root.resetAutoCloseTimer()
                            event.accepted = true
                        } else {
                            event.accepted = false
                        }
                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        if (event.modifiers & Qt.ShiftModifier || event.key === Qt.Key_Backtab) {
                            if (currentIndex > 0) {
                                currentIndex--
                                root.resetAutoCloseTimer()
                                event.accepted = true
                            } else {
                                event.accepted = false
                            }
                        } else {
                            if (currentIndex < count - 1) {
                                currentIndex++
                                root.resetAutoCloseTimer()
                                event.accepted = true
                            } else {
                                event.accepted = false
                            }
                        }
                    } else if (event.key === Qt.Key_Home) {
                        currentIndex = 0
                        root.resetAutoCloseTimer()
                        event.accepted = true
                    } else if (event.key === Qt.Key_End) {
                        currentIndex = count - 1
                        root.resetAutoCloseTimer()
                        event.accepted = true
                    } else {
                        event.accepted = false
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    z: -1

                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) {
                            if (listView.currentIndex > 0) {
                                listView.currentIndex--
                            }
                        } else if (wheel.angleDelta.y < 0) {
                            if (listView.currentIndex < listView.count - 1) {
                                listView.currentIndex++
                            }
                        }
                        root.resetAutoCloseTimer()
                    }

                    onPositionChanged: {
                        root.resetAutoCloseTimer()
                    }
                }

                onCountChanged: {
                    if (modeManager.isMode("wallpaper")) {
                        Qt.callLater(() => root.updateFocusToCurrentWallpaper())
                    }
                }

                delegate: Item {
                    width: modeManager.scale(240)
                    height: listView.height

                    property bool isCurrent: ListView.isCurrentItem
                    property string wallpaperPath: modelData

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: modeManager.scale(8)
                        color: "transparent"
                        radius: modeManager.scale(18)

                        scale: isCurrent ? 1.0 : 0.75
                        opacity: isCurrent ? 1.0 : 0.7

                        Behavior on scale {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        Behavior on opacity {
                            NumberAnimation { duration: 200 }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: modeManager.scale(4)
                            color: root.theme ? root.theme.surfaceGlass : Qt.rgba(0.15, 0.15, 0.20, 0.5)
                            radius: modeManager.scale(18)
                            visible: thumb.status === Image.Loading || thumb.status === Image.Null
                        }

                        Image {
                            id: thumb
                            anchors.fill: parent
                            anchors.margins: modeManager.scale(4)
                            source: "file://" + wallpaperManager.getThumbnailPath(wallpaperPath)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            cache: false
                            visible: false

                            Component.onCompleted: {
                            }

                            onStatusChanged: {
                            }
                        }

                        OpacityMask {
                            anchors.fill: thumb
                            source: thumb
                            maskSource: Rectangle {
                                width: thumb.width
                                height: thumb.height
                                radius: modeManager.scale(18)
                            }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: modeManager.scale(10)
                            width: modeManager.scale(24)
                            height: modeManager.scale(24)
                            radius: modeManager.scale(12)
                            color: Qt.rgba(0, 0, 0, 0.7)
                            visible: wallpaperManager.isVideoFile(wallpaperPath)

                            Text {
                                anchors.centerIn: parent
                                text: "▶"
                                color: "white"
                                font.pixelSize: modeManager.scale(10)
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: isCurrent ? modeManager.scale(2) : 0
                            border.color: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                            radius: modeManager.scale(18)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                listView.currentIndex = index
                                root.setWallpaper(wallpaperPath)
                                root.resetAutoCloseTimer()
                            }
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: wallpaperManager.isLoading ? "loading..." : wallpaperManager.wallpapers.length + " wallpapers"
                color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                font.pixelSize: modeManager.scale(10)
                font.family: "M PLUS 2"
                opacity: 0.6
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 1
        enabled: modeManager.isMode("wallpaper")
        visible: enabled
        hoverEnabled: true
        onClicked: modeManager.closeAllModes()

        onPositionChanged: {
            if (modeManager.isMode("wallpaper")) {
                root.resetAutoCloseTimer()
            }
        }
    }
}
