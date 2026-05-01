import QtQuick
import QtQuick.Layouts
import "../common" as Common

Item {
    id: delegateRoot

    property var modelData

    required property bool isCurrent
    required property var theme
    required property var typo
    required property var iconResolver
    required property var isAppRunning
    required property var modeManager

    signal launchApp(var app)
    signal resetAutoCloseTimer()
    signal entered()

    width: GridView.view ? GridView.view.cellWidth : 100
    height: GridView.view ? GridView.view.cellHeight : 100

    property var currentData: modelData

    onModelDataChanged: {
        if (modelData) {
            currentData = modelData
        }
    }

    onCurrentDataChanged: {
        if (currentData && currentData.icon) {
            Qt.callLater(() => {
                loadIcon()
            })
        }
    }

    function loadIcon() {
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
        anchors.margins: 8
        color: "transparent"
        radius: 12

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

                    scale: delegateRoot.isCurrent ? 1.15 : 1.0
                    z: 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutCubic
                        }
                    }

                    property var iconPaths: []
                    property int currentPathIndex: 0

                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    cache: false

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
                            duration: 400
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: delegateRoot.theme ? delegateRoot.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                    visible: delegateRoot.currentData ? (delegateRoot.isAppRunning ? delegateRoot.isAppRunning(delegateRoot.currentData.name) : false) : false
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

            onClicked: {
                if (!delegateRoot.currentData) return
                delegateRoot.launchApp(delegateRoot.currentData)
            }

            onEntered: delegateRoot.entered()

            onPositionChanged: {
                delegateRoot.resetAutoCloseTimer()
            }
        }
    }
}
