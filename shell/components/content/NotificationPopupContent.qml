import QtQuick
import QtQuick.Layouts
import "../ui" as UI

Item {
    id: root
    
    required property var modeManager
    required property var notificationManager
    property var theme
    property var icons
    
    readonly property var requiredBarSize: ({
        "height": modeManager.scale(70),
        "leftMargin": modeManager.scale(600),
        "rightMargin": modeManager.scale(600),
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
                    duration: 300
                    easing.type: Easing.OutCubic
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
        
        Item {
            anchors.fill: parent
            anchors.topMargin: modeManager.scale(8)
            anchors.bottomMargin: modeManager.scale(8)
            anchors.leftMargin: modeManager.scale(16)
            anchors.rightMargin: modeManager.scale(16)
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: modeManager.scale(12)
                anchors.rightMargin: modeManager.scale(12)
                anchors.topMargin: 0
                anchors.bottomMargin: 0
                spacing: modeManager.scale(10)
                
                UI.SvgIcon {
                    width: modeManager.scale(18)
                    height: modeManager.scale(18)
                    Layout.alignment: Qt.AlignVCenter
                    source: icons ? icons.notificationSvg : ""
                    color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                    opacity: 0.9
                }
                
                Text {
                    text: root.currentNotification ? root.currentNotification.title : ""
                    color: (theme ? theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))
                    font.pixelSize: modeManager.scale(13)
                    font.weight: Font.Medium
                    font.family: "M PLUS 2"
                    elide: Text.ElideRight
                    Layout.maximumWidth: modeManager.scale(150)
                    Layout.alignment: Qt.AlignVCenter
                }
                
                Text {
                    text: "·"
                    color: (theme ? theme.textFaint : Qt.rgba(0.72, 0.72, 0.82, 0.50))
                    font.pixelSize: modeManager.scale(13)
                    font.family: "M PLUS 2"
                    visible: root.currentNotification && root.currentNotification.message.length > 0
                    Layout.alignment: Qt.AlignVCenter
                }
                
                Text {
                    Layout.fillWidth: true
                    text: root.currentNotification ? root.currentNotification.message : ""
                    color: Qt.rgba(0.82, 0.82, 0.87, 0.80)
                    font.pixelSize: modeManager.scale(12)
                    font.family: "M PLUS 2"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.alignment: Qt.AlignVCenter
                }
                
                Item {
                    width: modeManager.scale(20)
                    height: modeManager.scale(20)
                    Layout.alignment: Qt.AlignVCenter
                    
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: Qt.rgba(0.95, 0.55, 0.65, closeArea.containsMouse ? 1.0 : 0.7)
                        font.pixelSize: modeManager.scale(16)
                        font.weight: Font.Light
                        
                        Behavior on color {
                            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                    }
                    
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: modeManager.scale(-4)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            modeManager.closeAllModes()
                        }
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

