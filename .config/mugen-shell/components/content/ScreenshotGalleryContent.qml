import QtQuick
import QtQuick.Layouts
import Quickshell
import "../common" as Common
import "../ui" as UI

FocusScope {
    id: root

    required property var modeManager
    required property var screenshotManager
    required property var theme

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(450),
        "leftMargin": modeManager.scale(550),
        "rightMargin": modeManager.scale(550),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })

    Item {
        id: galleryLayer
        anchors.fill: parent
        anchors.leftMargin: modeManager.scale(560)
        anchors.rightMargin: modeManager.scale(560)
        anchors.topMargin: modeManager.scale(20)
        anchors.bottomMargin: modeManager.scale(20)
        z: 10

        focus: modeManager.isMode("screenshot-gallery")

        opacity: 0
        visible: opacity > 0.01

        states: [
            State {
                name: "visible"
                when: modeManager.isMode("screenshot-gallery")
                PropertyChanges { target: galleryLayer; opacity: 1.0 }
            }
        ]

        transitions: [
            Transition {
                from: "visible"
                to: ""
                NumberAnimation {
                    property: "opacity"
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: 300 }
                    NumberAnimation {
                        property: "opacity"
                        duration: 400
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        ]
        Keys.forwardTo: [screenshotGrid]
        Keys.onPressed: (event) => {
            if (modeManager.isMode("screenshot-gallery")) {
                autoCloseTimer.restart()
            }
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Common.GlowText {
                Layout.alignment: Qt.AlignHCenter
                text: "screenshots"
                color: Qt.rgba(0.95, 0.93, 0.98, 0.95)
                font.pixelSize: 20
                font.family: "M PLUS 2"
                font.weight: Font.Light
                font.letterSpacing: 1.5
                enableGlow: true
                glowColor: root.theme && root.theme.glowPrimary
                    ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.6)
                    : Qt.rgba(0.65, 0.55, 0.85, 0.6)
                glowSamples: 20
                glowRadius: 12
                glowSpread: 0.5
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter

                GridView {
                    id: screenshotGrid
                    anchors.centerIn: parent
                    width: {
                        let colsPerRow = Math.floor(parent.width / 150)
                        if (colsPerRow <= 0) return parent.width
                        return Math.min(colsPerRow * 150, parent.width)
                    }
                    height: parent.height
                    cellWidth: 150
                    cellHeight: 120
                    model: root.screenshotManager ? root.screenshotManager.screenshots : null
                    boundsBehavior: Flickable.StopAtBounds
                    focus: true
                    clip: true
                    highlightFollowsCurrentItem: true
                    highlight: Rectangle {
                        width: screenshotGrid.cellWidth
                        height: screenshotGrid.cellHeight
                        color: "transparent"
                        border.width: 0
                    }

                    Keys.onPressed: (event) => {
                        if (modeManager.isMode("screenshot-gallery")) {
                            autoCloseTimer.restart()
                        }
                        if (event.key === Qt.Key_Escape) {
                            modeManager.closeAllModes()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (currentIndex >= 0 && screenshotManager) {
                                let path = screenshotManager.filePath(currentIndex)
                                if (path) {
                                    screenshotManager.openScreenshot(path)
                                    modeManager.closeAllModes()
                                }
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Left) {
                            if (currentIndex > 0) {
                                currentIndex--
                                positionViewAtIndex(currentIndex, GridView.Visible)
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Right) {
                            if (currentIndex < count - 1) {
                                currentIndex++
                                positionViewAtIndex(currentIndex, GridView.Visible)
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            let colsPerRow = Math.floor(width / cellWidth)
                            if (colsPerRow > 0 && currentIndex >= colsPerRow) {
                                currentIndex -= colsPerRow
                                positionViewAtIndex(currentIndex, GridView.Visible)
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            let colsPerRow = Math.floor(width / cellWidth)
                            if (colsPerRow > 0 && currentIndex < count - colsPerRow) {
                                currentIndex += colsPerRow
                                positionViewAtIndex(currentIndex, GridView.Visible)
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            if (event.modifiers & Qt.ShiftModifier || event.key === Qt.Key_Backtab) {
                                if (currentIndex > 0) {
                                    currentIndex--
                                    positionViewAtIndex(currentIndex, GridView.Visible)
                                } else {
                                    currentIndex = count - 1
                                    positionViewAtIndex(currentIndex, GridView.Visible)
                                }
                            } else {
                                if (currentIndex < count - 1) {
                                    currentIndex++
                                    positionViewAtIndex(currentIndex, GridView.Visible)
                                } else {
                                    currentIndex = 0
                                    positionViewAtIndex(currentIndex, GridView.Visible)
                                }
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Home) {
                            currentIndex = 0
                            positionViewAtIndex(currentIndex, GridView.Visible)
                            event.accepted = true
                        } else if (event.key === Qt.Key_End) {
                            currentIndex = count - 1
                            positionViewAtIndex(currentIndex, GridView.Visible)
                            event.accepted = true
                        } else {
                            event.accepted = false
                        }
                    }

                delegate: Item {
                    width: screenshotGrid.cellWidth
                    height: screenshotGrid.cellHeight

                    property bool isCurrent: GridView.isCurrentItem
                    property string filePathValue: filePath && filePath.length > 0
                        ? filePath
                        : (root.screenshotManager ? root.screenshotManager.filePath(index) : "")
                    property string fileNameValue: fileName && fileName.length > 0 ? fileName : ""
                    property string imageSource: filePathValue
                        ? (filePathValue.startsWith("file://") ? filePathValue : "file://" + filePathValue)
                        : ""

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 8
                        radius: 16
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: isCurrent ? 2 : 0
                        border.color: isCurrent 
                            ? (root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
                            : Qt.rgba(1, 1, 1, 0.15)
                        
                        scale: isCurrent ? 1.0 : 0.9
                        opacity: isCurrent ? 1.0 : 0.7
                        
                        Behavior on scale {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 200 }
                        }

                        Image {
                            id: screenshotImage
                            anchors.fill: parent
                            anchors.margins: 6
                            source: imageSource
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            opacity: status === Image.Ready ? 1.0 : 0.0
                            
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.InOutCubic
                                }
                            }
                            
                            onStatusChanged: {
                                if (status === Image.Ready) {
                                    opacity = 1.0
                                } else if (status === Image.Loading) {
                                    opacity = 0.0
                                }
                            }
                        }
                        
                        Item {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 6
                            width: 28
                            height: 28
                            visible: filePathValue.length > 0
                            z: 2

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Qt.rgba(0, 0, 0, 0.6)
                            }

                            UI.SvgIcon {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                source: Quickshell.shellDir + "/assets/icons/trash.svg"
                                color: Qt.rgba(1, 0.8, 0.85, 0.95)
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    if (root.screenshotManager && filePathValue.length > 0) {
                                        root.screenshotManager.deleteScreenshot(filePathValue)
                                        root.resetAutoCloseTimer()
                                    }
                                    mouse.accepted = true
                                }
                            }
                        }

                        Item {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            width: 28
                            height: 28
                            visible: filePathValue.length > 0
                            z: 2
                            property real clickScale: 1.0

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Qt.rgba(0, 0, 0, 0.6)
                            }

                            UI.SvgIcon {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                source: Quickshell.shellDir + "/assets/icons/copy.svg"
                                color: Qt.rgba(0.92, 0.95, 1, 0.95)
                                scale: parent.clickScale
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 120
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    if (root.screenshotManager && filePathValue.length > 0) {
                                        parent.clickScale = 1.25
                                        copyClickReset.restart()
                                        root.screenshotManager.copyScreenshot(filePathValue)
                                        root.resetAutoCloseTimer()
                                    }
                                    mouse.accepted = true
                                }
                            }
                            Timer {
                                id: copyClickReset
                                interval: 160
                                repeat: false
                                onTriggered: parent.clickScale = 1.0
                            }
                        }

                        Rectangle {
                            anchors.fill: screenshotImage
                            color: root.theme ? root.theme.surfaceGlass : Qt.rgba(0.15, 0.15, 0.20, 0.5)
                            radius: 10
                            visible: screenshotImage.status === Image.Loading || screenshotImage.status === Image.Null
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: {
                                screenshotGrid.currentIndex = index
                                screenshotGrid.forceActiveFocus()
                            }

                            onClicked: {
                                screenshotGrid.currentIndex = index
                                if (root.screenshotManager && filePathValue) {
                                    root.screenshotManager.openScreenshot(filePathValue)
                                    modeManager.closeAllModes()
                                }
                        }
                    }
                }
                }
                }
            }

            Common.GlowText {
                Layout.alignment: Qt.AlignHCenter
                text: screenshotManager && screenshotManager.screenshots ? screenshotManager.screenshots.count + " screenshots" : "0 screenshots"
                color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                font.pixelSize: 10
                font.family: "M PLUS 2"
                opacity: 0.6
                glowColor: root.theme && root.theme.glowPrimary
                    ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.18)
                    : Qt.rgba(0.65, 0.55, 0.85, 0.18)
                glowRadius: 5
                glowSpread: 0.2
                glowSamples: 12
            }
        }
    }

    Timer {
        id: autoCloseTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            if (modeManager.isMode("screenshot-gallery")) {
                modeManager.closeAllModes()
            }
        }
    }
    
    function resetAutoCloseTimer() {
        if (modeManager.isMode("screenshot-gallery")) {
            autoCloseTimer.restart()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 1
        enabled: modeManager.isMode("screenshot-gallery")
        visible: enabled
        hoverEnabled: true
        onClicked: modeManager.closeAllModes()
        
        onPositionChanged: {
            if (modeManager.isMode("screenshot-gallery")) {
                root.resetAutoCloseTimer()
            }
        }
    }

    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("screenshot-gallery", root)
            if (modeManager.isMode("screenshot-gallery")) {
                if (screenshotManager) screenshotManager.refresh()
                focusTimer.restart()
                autoCloseTimer.restart()
            }
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("screenshot-gallery")) {
                if (screenshotManager) {
                    screenshotManager.refresh()
                }
                focusTimer.restart()
                autoCloseTimer.restart()
            } else {
                autoCloseTimer.stop()
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (galleryLayer) {
                galleryLayer.forceActiveFocus()
            }
            Qt.callLater(() => {
                if (screenshotGrid) {
                    screenshotGrid.forceActiveFocus()
                    if (screenshotGrid.count > 0 && screenshotGrid.currentIndex < 0) {
                        screenshotGrid.currentIndex = 0
                    }
                }
            })
        }
    }
}

