import QtQuick
import QtQuick.Layouts
import "../common" as Common
import "../../lib" as Theme

Item {
    id: delegateRoot

    property var modelData

    required property bool isCurrent
    required property var theme
    required property var typo
    required property var iconResolver
    required property var modeManager
    required property bool isFavorite
    property bool dragEnabled: false
    // The tile a drag has hovered long enough to take the drop.
    property bool willGroup: false
    property bool isDragging: false

    signal launchApp(var app)
    signal dragStarted(var app, real localX, real localY)
    signal dragMoved(real localX, real localY)
    signal dragEnded(real localX, real localY)
    signal dragCancelled()
    signal resetAutoCloseTimer()
    signal entered()
    signal contextMenuRequested(var app, real posX, real posY)

    width: GridView.view ? GridView.view.cellWidth : 100
    height: GridView.view ? GridView.view.cellHeight : 100

    property var currentData: modelData
    readonly property bool isGroup: currentData ? currentData.kind === "group" : false

    onModelDataChanged: {
        if (modelData) {
            currentData = modelData
        }
    }

    onCurrentDataChanged: {
        Qt.callLater(() => {
            loadIcon()
        })
    }

    function firstIconPath(app) {
        if (!app || !app.icon) return ""
        if (!iconResolver || typeof iconResolver.resolveIconPath !== 'function') {
            return app.icon.startsWith("/") ? app.icon : ""
        }
        let paths = iconResolver.resolveIconPath(app.icon)
        return paths && paths.length > 0 ? paths[0] : ""
    }

    function loadIcon() {
        if (isGroup) {
            appIcon.visible = false
            fallbackIcon.visible = false
            return
        }
        if (!currentData || !currentData.icon) {
            fallbackIcon.visible = true
            appIcon.visible = false
            return
        }

        if (!iconResolver || typeof iconResolver.resolveIconPath !== 'function') {
            if (currentData.icon.startsWith("/")) {
                appIcon.source = "file://" + currentData.icon
                appIcon.visible = true
                fallbackIcon.visible = false
                return
            }
            fallbackIcon.visible = true
            appIcon.visible = false
            return
        }

        appIcon.source = ""
        appIcon.visible = false
        fallbackIcon.visible = false

        let paths = iconResolver.resolveIconPath(currentData.icon)

        if (!paths || paths.length === 0) {
            fallbackIcon.visible = true
            return
        }

        appIcon.iconPaths = paths
        appIcon.currentPathIndex = 0
        appIcon.source = "file://" + paths[0]
    }

    Component.onCompleted: {
        if (modelData) {
            currentData = modelData
        }
    }

    Rectangle {
        id: appItem
        anchors.fill: parent
        anchors.margins: 6
        radius: 15

        readonly property color accent: delegateRoot.theme ? delegateRoot.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 1.0)
        readonly property real faceAlpha: delegateRoot.isCurrent ? 0.12 : 0.06
        color: delegateRoot.willGroup
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.16)
            : (delegateRoot.isFavorite
                ? Qt.rgba(accent.r, accent.g, accent.b, faceAlpha + 0.04)
                : Qt.rgba(1, 1, 1, faceAlpha))
        border.width: delegateRoot.willGroup ? 2 : 1
        border.color: delegateRoot.willGroup
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.75)
            : (delegateRoot.isFavorite
                ? Qt.rgba(accent.r, accent.g, accent.b, 0.25)
                : Qt.rgba(1, 1, 1, 0.10))
        // The source stays put, faded, while its ghost travels with the pointer.
        opacity: delegateRoot.isDragging ? 0.35 : 1.0

        Behavior on color {
            ColorAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.Motion.micro }
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.Motion.micro }
        }

        Item {
            id: selectionEffect
            anchors.centerIn: parent
            width: parent.width + 24
            height: parent.height + 24
            z: -1

            visible: delegateRoot.isCurrent

            opacity: 0.6

            Behavior on opacity {
                NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
            }

            property real heartbeatScale: 1.0

            SequentialAnimation on heartbeatScale {
                id: heartbeatAnimation
                loops: Animation.Infinite
                running: selectionEffect.visible && delegateRoot.visible && parent.visible
                NumberAnimation { to: 1.14; duration: 420; easing.type: Easing.OutCubic }
                NumberAnimation { to: 1.0; duration: 420; easing.type: Easing.InCubic }
                PauseAnimation { duration: 200 }
                NumberAnimation { to: 1.12; duration: 360; easing.type: Easing.OutCubic }
                NumberAnimation { to: 1.0; duration: 360; easing.type: Easing.InCubic }
                PauseAnimation { duration: 720 }
            }

            Common.BlobEffect {
                anchors.fill: parent
                blobColor: delegateRoot.theme ? delegateRoot.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 1.0)
                layers: 3
                waveAmplitude: 4.0
                baseOpacity: 0.6
                animationSpeed: 0.05
                pointCount: 16
                running: selectionEffect.visible && delegateRoot.visible && parent.visible
                scale: selectionEffect.heartbeatScale
            }
        }


        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignHCenter

                Image {
                    id: appIcon
                    anchors.centerIn: parent
                    width: 40
                    height: 40

                    scale: delegateRoot.willGroup ? 0.82 : (delegateRoot.isCurrent ? 1.15 : 1.0)
                    z: 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.Motion.gentle
                            easing.type: Easing.OutCubic
                        }
                    }

                    property var iconPaths: []
                    property int currentPathIndex: 0

                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    sourceSize: Qt.size(96, 96)

                    onStatusChanged: {
                        if (status === Image.Error) {
                            currentPathIndex++
                            if (currentPathIndex < iconPaths.length) {
                                source = "file://" + iconPaths[currentPathIndex]
                            } else {
                                visible = false
                                fallbackIcon.visible = true
                            }
                        } else if (status === Image.Ready) {
                            visible = true
                            fallbackIcon.visible = false
                        } else if (status === Image.Loading) {
                            visible = false
                            fallbackIcon.visible = true
                        }
                    }
                }

                // Four members at 17px with a 6px gutter fill the same 40px box as one app icon.
                Grid {
                    id: groupIcons
                    anchors.centerIn: parent
                    columns: 2
                    spacing: 6
                    visible: delegateRoot.isGroup
                    z: 1

                    scale: delegateRoot.willGroup ? 0.82 : (delegateRoot.isCurrent ? 1.15 : 1.0)

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.Motion.gentle
                            easing.type: Easing.OutCubic
                        }
                    }

                    Repeater {
                        model: delegateRoot.isGroup ? Math.min(4, delegateRoot.currentData.members.length) : 0

                        Image {
                            required property int index
                            width: 17
                            height: 17
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            sourceSize: Qt.size(48, 48)
                            source: {
                                let p = delegateRoot.firstIconPath(delegateRoot.currentData.members[index])
                                return p === "" ? "" : "file://" + p
                            }
                        }
                    }
                }

                Text {
                    id: fallbackIcon
                    anchors.centerIn: parent
                    text: "\uD83D\uDCE6"
                    font.pixelSize: 40
                    visible: false

                    scale: delegateRoot.isCurrent ? 1.15 : 1.0
                    z: 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.Motion.gentle
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter

                text: delegateRoot.currentData ? delegateRoot.currentData.name : ""
                color: delegateRoot.theme ? delegateRoot.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: delegateRoot.typo ? delegateRoot.typo.sizeSmall : 11
                font.family: delegateRoot.typo ? delegateRoot.typo.fontFamily : "M PLUS 2"

                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: appMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            // A scrollable Home would otherwise take over the pointer a few pixels into every drag.
            preventStealing: delegateRoot.dragEnabled

            property real pressX: 0
            property real pressY: 0
            property bool dragging: false
            readonly property int dragThreshold: 8

            onPressed: (mouse) => {
                pressX = mouse.x
                pressY = mouse.y
                dragging = false
            }

            onPositionChanged: (mouse) => {
                delegateRoot.resetAutoCloseTimer()
                if (!pressed || mouse.buttons !== Qt.LeftButton) return
                if (!delegateRoot.dragEnabled || delegateRoot.isGroup || !delegateRoot.currentData) return
                if (!dragging) {
                    if (Math.abs(mouse.x - pressX) < dragThreshold && Math.abs(mouse.y - pressY) < dragThreshold) return
                    dragging = true
                    delegateRoot.dragStarted(delegateRoot.currentData, pressX, pressY)
                }
                delegateRoot.dragMoved(mouse.x, mouse.y)
            }

            onReleased: (mouse) => {
                if (dragging) {
                    dragging = false
                    delegateRoot.dragEnded(mouse.x, mouse.y)
                }
            }

            onCanceled: {
                if (dragging) {
                    dragging = false
                    delegateRoot.dragCancelled()
                }
            }

            onClicked: (mouse) => {
                if (!delegateRoot.currentData) return
                // A release that ended a drag is not a launch.
                if (mouse.button === Qt.LeftButton && (Math.abs(mouse.x - pressX) >= dragThreshold || Math.abs(mouse.y - pressY) >= dragThreshold)) return
                if (mouse.button === Qt.RightButton) {
                    let p = appMouseArea.mapToItem(delegateRoot, mouse.x, mouse.y)
                    delegateRoot.contextMenuRequested(delegateRoot.currentData, p.x, p.y)
                } else {
                    delegateRoot.launchApp(delegateRoot.currentData)
                }
            }

            onEntered: delegateRoot.entered()
        }

        Text {
            id: favoriteStar
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 6
            anchors.topMargin: 6
            text: "★"
            font.pixelSize: 12
            color: delegateRoot.theme ? delegateRoot.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 1.0)
            visible: delegateRoot.isFavorite
            opacity: 0.9
            z: 2
        }
    }
}
