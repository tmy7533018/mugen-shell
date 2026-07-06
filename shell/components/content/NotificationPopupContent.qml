import QtQuick
import QtQuick.Layouts
import "../ui" as UI
import "../../lib" as Theme

Item {
    id: root
    
    required property var modeManager
    required property var notificationManager
    property var theme
    property var icons
    
    readonly property var requiredBarSize: ({
        "height": modeManager.scale(70),
        "leftMargin": modeManager.scale(650),
        "rightMargin": modeManager.scale(650),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })
    
    property var currentNotification: null

    Timer {
        id: autoCloseTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            if (modeManager.isMode("notification-popup")) {
                modeManager.closeAllModes()
            }
        }
    }
    
    Connections {
        target: notificationManager
        function onNotificationReceived(notification) {
            if (!notificationManager.notificationsEnabled) {
                return
            }
            
            root.currentNotification = notification

            // Only show popup if no other mode is active to avoid disrupting user interaction
            if (modeManager.isMode("normal")) {
                modeManager.switchMode("notification-popup")
                autoCloseTimer.restart()
            }
        }
    }
    
    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("notification-popup")) {
                autoCloseTimer.restart()
            } else {
                autoCloseTimer.stop()
            }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        z: 1.5
        enabled: modeManager.isMode("notification-popup")
        visible: enabled
        hoverEnabled: true
        
        onClicked: {
            modeManager.switchMode("notification")
        }
        
        onPositionChanged: {
            if (modeManager.isMode("notification-popup")) {
                autoCloseTimer.restart()
            }
        }
    }
    
    Item {
        id: popupLayer
        anchors.fill: parent
        anchors.topMargin: modeManager.currentBarSize.topMargin
        anchors.bottomMargin: modeManager.currentBarSize.bottomMargin
        anchors.leftMargin: modeManager.currentBarSize.leftMargin
        anchors.rightMargin: modeManager.currentBarSize.rightMargin
        z: 2
        
        opacity: 0
        visible: opacity > 0.01
        
        states: [
            State {
                name: "visible"
                when: modeManager.isMode("notification-popup")
                PropertyChanges { target: popupLayer; opacity: 1.0 }
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
        
        Theme.IconResolver { id: iconResolver }

        Item {
            anchors.fill: parent
            anchors.topMargin: modeManager.scale(8)
            anchors.bottomMargin: modeManager.scale(8)
            anchors.leftMargin: modeManager.scale(16)
            anchors.rightMargin: modeManager.scale(16)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: modeManager.scale(8)
                anchors.rightMargin: modeManager.scale(8)
                spacing: modeManager.scale(18)

                Item {
                    Layout.preferredWidth: modeManager.scale(28)
                    Layout.preferredHeight: modeManager.scale(28)
                    Layout.alignment: Qt.AlignVCenter

                    // Quickshell already resolves notify-send's -i hint into
                    // an `image://icon/<name>` URL on `image`. Prefer that;
                    // fall back to walking IconResolver paths from desktopEntry
                    // / appName for senders that only set those.
                    property var iconPaths: {
                        if (!root.currentNotification) return []
                        let n = root.currentNotification
                        let candidates = []
                        if (n.desktopEntry && n.desktopEntry.length > 0) candidates.push(n.desktopEntry)
                        if (n.appName && n.appName.length > 0) candidates.push(n.appName.toLowerCase())
                        let paths = []
                        for (let i = 0; i < candidates.length; i++) {
                            let resolved = iconResolver.resolveIconPath(candidates[i])
                            for (let j = 0; j < resolved.length; j++) paths.push(resolved[j])
                        }
                        return paths
                    }
                    property int currentPathIndex: 0
                    property string directImage: root.currentNotification && root.currentNotification.image
                        ? root.currentNotification.image
                        : ""

                    Image {
                        id: appIcon
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                        cache: false
                        visible: status === Image.Ready
                        source: {
                            if (parent.directImage.length > 0) return parent.directImage
                            if (parent.iconPaths.length > 0 && parent.currentPathIndex < parent.iconPaths.length) {
                                return "file://" + parent.iconPaths[parent.currentPathIndex]
                            }
                            return ""
                        }
                        onStatusChanged: {
                            if (status === Image.Error) {
                                let p = parent
                                if (p.currentPathIndex + 1 < p.iconPaths.length) {
                                    p.currentPathIndex++
                                }
                            }
                        }
                    }

                    UI.SvgIcon {
                        anchors.centerIn: parent
                        width: modeManager.scale(20)
                        height: modeManager.scale(20)
                        visible: !appIcon.visible
                        source: icons ? icons.notificationSvg : ""
                        color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                        opacity: 0.9
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: modeManager.scale(2)

                    Text {
                        Layout.fillWidth: true
                        text: root.currentNotification ? root.currentNotification.title : ""
                        color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95)
                        font.pixelSize: modeManager.scale(13)
                        font.weight: Font.Medium
                        font.family: "M PLUS 2"
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.currentNotification ? root.currentNotification.message : ""
                        color: theme ? theme.textSecondary : Qt.rgba(0.82, 0.82, 0.87, 0.78)
                        font.pixelSize: modeManager.scale(11)
                        font.family: "M PLUS 2"
                        elide: Text.ElideRight
                        // Title + one body line is all the 70px pill can fit;
                        // two wrapped lines spill past the rounded bottom edge.
                        maximumLineCount: 1
                        visible: text.length > 0
                    }
                }

                Item {
                    Layout.preferredWidth: modeManager.scale(22)
                    Layout.preferredHeight: modeManager.scale(22)
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: Qt.rgba(0.95, 0.55, 0.65, closeArea.containsMouse ? 1.0 : 0.6)
                        font.pixelSize: modeManager.scale(18)
                        font.weight: Font.Medium
                        Behavior on color { ColorAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: modeManager.scale(-4)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modeManager.closeAllModes()
                    }
                }
            }
        }
    }
    
    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("notification-popup", root)
        }
    }
}

