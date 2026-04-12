import QtQuick

Item {
    id: root
    
    property var modeManager
    property string modeName: ""
    property int autoCloseDelay: 5000
    property bool enableAutoClose: true
    property bool enableBackgroundClick: true
    property real contentOpacity: 1.0
    property int fadeInDelay: 300
    property int fadeInDuration: 400
    property int fadeOutDuration: 300

    default property alias contentData: contentLayer.data
    
    function resetAutoCloseTimer() {
        if (enableAutoClose && modeManager && modeManager.isMode(modeName)) {
            autoCloseTimer.restart()
        }
    }
    
    Timer {
        id: autoCloseTimer
        interval: root.autoCloseDelay
        running: false
        repeat: false
        onTriggered: {
            if (enableAutoClose && modeManager && modeManager.isMode(modeName)) {
                modeManager.closeAllModes()
            }
        }
    }
    
    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager && modeManager.isMode(modeName)) {
                if (enableAutoClose) {
                    autoCloseTimer.restart()
                }
            } else {
                autoCloseTimer.stop()
            }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        z: 1.5
        enabled: enableBackgroundClick && modeManager && modeManager.isMode(modeName)
        visible: enabled
        hoverEnabled: true
        
        onClicked: {
            if (modeManager) {
                modeManager.closeAllModes()
            }
        }
        
        onPositionChanged: {
            root.resetAutoCloseTimer()
        }
    }
    
    Item {
        id: contentLayer
        anchors.fill: parent
        z: 2
        
        opacity: 0
        visible: opacity > 0.01
        
        states: [
            State {
                name: "visible"
                when: modeManager && modeManager.isMode(modeName)
                PropertyChanges { target: contentLayer; opacity: root.contentOpacity }
            }
        ]
        
        transitions: [
            Transition {
                from: "visible"
                to: ""
                NumberAnimation {
                    property: "opacity"
                    duration: root.fadeOutDuration
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: root.fadeInDelay }
                    NumberAnimation {
                        property: "opacity"
                        duration: root.fadeInDuration
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        ]
    }
}

