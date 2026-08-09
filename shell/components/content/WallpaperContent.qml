import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import "../common" as Common
import "../../lib" as Theme

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
        "topMargin": modeManager.normalBarSize.topMargin,
        "bottomMargin": modeManager.normalBarSize.bottomMargin
    })

    function setWallpaper(path) {
        wallpaperManager.setWallpaper(path)
        modeManager.closeAllModes()
    }

    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("wallpaper", root)
            wallpaperManager.pickerOpen = modeManager.isMode("wallpaper")
            if (modeManager.isMode("wallpaper")) {
                root.anchorPath = ""
                wallpaperManager.loadWallpapers()
                focusTimer.restart()
            }
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            wallpaperManager.pickerOpen = modeManager.isMode("wallpaper")
            if (modeManager.isMode("wallpaper")) {
                root.anchorPath = ""
                wallpaperManager.loadWallpapers()
                focusTimer.restart()
            }
        }
    }

    // A Binding here sticks pickerOpen on: the owning Loader tears it down without restoring.
    Component.onDestruction: wallpaperManager.pickerOpen = false

    function resetAutoCloseTimer() {
        if (modeManager.isMode("wallpaper")) modeManager.bump()
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

    readonly property var listModel: ["__add__"].concat(wallpaperManager.wallpapers || [])

    function openWallpaperFolder() {
        openWallpaperDirProcess.running = false
        openWallpaperDirProcess.command = ["xdg-open", wallpaperManager.wallpaperDir]
        openWallpaperDirProcess.running = true
    }

    Process {
        id: openWallpaperDirProcess
        command: []
        running: false
    }

    // Kept as a path, not an index, so the selection survives a file appearing or disappearing.
    property string anchorPath: ""

    function moveTo(index) {
        listView.currentIndex = index
        root.anchorPath = index >= 1 ? (root.listModel[index] || "") : ""
    }

    function restoreSelection() {
        Qt.callLater(function() {
            if (!listView)
                return

            let index = root.listModel.indexOf(root.anchorPath)
            if (index < 1)
                index = root.listModel.indexOf(wallpaperManager.currentWallpaperPath)
            if (index < 1)
                index = wallpaperManager.wallpapers.length > 0 ? 1 : 0

            listView.currentIndex = index
            listView.positionViewAtIndex(index, ListView.Center)
        })
    }

    Connections {
        target: wallpaperManager
        function onWallpapersChanged() {
            root.restoreSelection()
        }

        function onCurrentWallpaperPathChanged() {
            root.restoreSelection()
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

        opacity: 0

        states: [
            State {
                name: "visible"
                when: modeManager.isMode("wallpaper")
                PropertyChanges { target: wallpaperLayer; opacity: 1.0 }
            }
        ]

        transitions: [
            Transition {
                from: "visible"
                to: ""
                NumberAnimation {
                    property: "opacity"
                    duration: Theme.Motion.standard
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: Theme.Motion.standard }
                    NumberAnimation {
                        property: "opacity"
                        duration: Theme.Motion.gentle
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        ]

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
                color: (theme ? theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))
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

                model: root.listModel
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
                        if (currentIndex === 0) {
                            root.openWallpaperFolder()
                        } else if (currentIndex >= 1) {
                            root.setWallpaper(root.listModel[currentIndex])
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        if (currentIndex > 0) {
                            root.moveTo(currentIndex - 1)
                            root.resetAutoCloseTimer()
                            event.accepted = true
                        } else {
                            event.accepted = false
                        }
                    } else if (event.key === Qt.Key_Right) {
                        if (currentIndex < count - 1) {
                            root.moveTo(currentIndex + 1)
                            root.resetAutoCloseTimer()
                            event.accepted = true
                        } else {
                            event.accepted = false
                        }
                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        if (event.modifiers & Qt.ShiftModifier || event.key === Qt.Key_Backtab) {
                            if (currentIndex > 0) {
                                root.moveTo(currentIndex - 1)
                                root.resetAutoCloseTimer()
                                event.accepted = true
                            } else {
                                event.accepted = false
                            }
                        } else {
                            if (currentIndex < count - 1) {
                                root.moveTo(currentIndex + 1)
                                root.resetAutoCloseTimer()
                                event.accepted = true
                            } else {
                                event.accepted = false
                            }
                        }
                    } else if (event.key === Qt.Key_Home) {
                        root.moveTo(0)
                        root.resetAutoCloseTimer()
                        event.accepted = true
                    } else if (event.key === Qt.Key_End) {
                        root.moveTo(count - 1)
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
                                root.moveTo(listView.currentIndex - 1)
                            }
                        } else if (wheel.angleDelta.y < 0) {
                            if (listView.currentIndex < listView.count - 1) {
                                root.moveTo(listView.currentIndex + 1)
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
                        root.restoreSelection()
                    }
                }

                delegate: Item {
                    id: cellRoot
                    width: modeManager.scale(240)
                    height: listView.height

                    property bool isCurrent: ListView.isCurrentItem
                    property bool isAddCell: modelData === "__add__"
                    property string wallpaperPath: isAddCell ? "" : modelData

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: modeManager.scale(8)
                        color: "transparent"
                        radius: modeManager.scale(18)

                        scale: cellRoot.isCurrent ? 1.0 : 0.75
                        opacity: cellRoot.isCurrent ? 1.0 : 0.7

                        Behavior on scale { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: modeManager.scale(4)
                            color: root.theme ? root.theme.surfaceGlass : Qt.rgba(0.15, 0.15, 0.20, 0.5)
                            radius: modeManager.scale(18)
                            border.width: cellRoot.isAddCell ? modeManager.scale(2) : 0
                            border.color: root.theme
                                ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.45)
                                : Qt.rgba(0.65, 0.55, 0.85, 0.45)
                            visible: cellRoot.isAddCell || thumb.status !== Image.Ready

                            Canvas {
                                id: plusCanvas
                                anchors.centerIn: parent
                                width: modeManager.scale(56)
                                height: modeManager.scale(56)
                                visible: cellRoot.isAddCell

                                property color strokeColor: root.theme
                                    ? root.theme.accent
                                    : Qt.rgba(0.65, 0.55, 0.85, 1.0)

                                onStrokeColorChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                Component.onCompleted: requestPaint()

                                onPaint: {
                                    let ctx = getContext("2d")
                                    ctx.reset()
                                    let cx = width / 2
                                    let cy = height / 2
                                    let arm = width * 0.42
                                    ctx.lineWidth = width * 0.07
                                    ctx.lineCap = "round"
                                    ctx.strokeStyle = strokeColor
                                    ctx.beginPath()
                                    ctx.moveTo(cx - arm, cy)
                                    ctx.lineTo(cx + arm, cy)
                                    ctx.moveTo(cx, cy - arm)
                                    ctx.lineTo(cx, cy + arm)
                                    ctx.stroke()
                                }
                            }
                        }

                        Image {
                            id: thumb
                            anchors.fill: parent
                            anchors.margins: modeManager.scale(4)
                            source: cellRoot.isAddCell ? "" : wallpaperManager.thumbnailSource(cellRoot.wallpaperPath)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            cache: false
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: thumb
                            source: thumb
                            visible: !cellRoot.isAddCell && thumb.status === Image.Ready
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
                            visible: !cellRoot.isAddCell && wallpaperManager.isVideoFile(cellRoot.wallpaperPath)

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
                            border.width: cellRoot.isCurrent && !cellRoot.isAddCell ? modeManager.scale(2) : 0
                            border.color: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                            radius: modeManager.scale(18)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.moveTo(index)
                                // setWallpaper() tears down this delegate, so bump before it runs.
                                root.resetAutoCloseTimer()
                                if (cellRoot.isAddCell) {
                                    root.openWallpaperFolder()
                                } else {
                                    root.setWallpaper(cellRoot.wallpaperPath)
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: wallpaperManager.isLoading
                    ? "loading..."
                    : (wallpaperManager.wallpapers.length === 0
                        ? "no wallpapers yet, press + to open the folder"
                        : wallpaperManager.wallpapers.length + " wallpapers")
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

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: root.requiredBarSize.topMargin
        anchors.bottomMargin: root.requiredBarSize.bottomMargin
        anchors.leftMargin: root.requiredBarSize.leftMargin
        anchors.rightMargin: root.requiredBarSize.rightMargin
        z: 1.8
        enabled: modeManager.isMode("wallpaper")
        visible: enabled
        hoverEnabled: true
        onClicked: modeManager.bump()
        onPositionChanged: modeManager.bump()
    }
}
