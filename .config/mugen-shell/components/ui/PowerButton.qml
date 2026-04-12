import QtQuick
import QtQuick.Layouts
import "../common" as Common

Item {
    id: button

    required property var modeManager
    
    property string icon: "⚡"
    property string iconSource: ""
    property string label: "Button"  // unused, kept for compatibility
    property color color: Qt.rgba(0.65, 0.55, 0.85, 1.0)
    property color iconBaseColor: Qt.rgba(1, 1, 1, 0.6)
    property color iconHoverColor: Qt.rgba(1, 1, 1, 0.95)
    property real hoverScale: 1.15
    property real hoverLift: modeManager.scale(8)
    property real iconSizeRatio: 0.5
    property real textSizeRatio: 0.45
    property real effectPadding: modeManager.scale(20)
    property bool isFocused: false

    signal clicked()

    readonly property bool isActive: isFocused || mouseArea.containsMouse
    
    implicitWidth: modeManager.scale(80)
    implicitHeight: modeManager.scale(70)
    
    property real baseLength: Math.max(width, height)
    property real iconSize: baseLength * iconSizeRatio
    property real textSize: baseLength * textSizeRatio
    property real effectSize: baseLength + effectPadding
    
    Item {
        id: fantasyEffect
        anchors.centerIn: parent
        width: button.effectSize
        height: button.effectSize
        z: -1

        opacity: button.isActive ? 1.0 : 0.3
        visible: true
        
        Behavior on opacity {
            NumberAnimation {
                duration: 500
                easing.type: Easing.OutCubic
            }
        }
        
        property real heartbeatScale: 1.0
        
        SequentialAnimation on heartbeatScale {
            id: heartbeatAnimation
            loops: Animation.Infinite
            running: button.isActive
            
            NumberAnimation {
                to: 1.15
                duration: 400
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                to: 1.0
                duration: 400
                easing.type: Easing.InCubic
            }
            PauseAnimation { duration: 200 }
            NumberAnimation {
                to: 1.15
                duration: 400
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                to: 1.0
                duration: 400
                easing.type: Easing.InCubic
            }
            PauseAnimation { duration: 800 }
        }
        
        Common.BlobEffect {
            anchors.fill: parent
            blobColor: button.color
            layers: 3
            waveAmplitude: 4.0
            baseOpacity: 0.6
            animationSpeed: 0.05
            pointCount: 16
            running: fantasyEffect.visible
            scale: fantasyEffect.heartbeatScale
        }
    }
    
    property real floatX: 0
    property real floatY: 0
    
    property real randomOffsetX: (Math.random() - 0.5) * 2
    property real randomOffsetY: (Math.random() - 0.5) * 2
    property real randomDuration: 1200 + Math.random() * 800
    property real randomDelay: Math.random() * 1600

    SequentialAnimation on floatX {
        id: floatXAnimation
        loops: Animation.Infinite
        running: true
        
        PauseAnimation {
            duration: button.randomDelay
        }
        
        NumberAnimation {
            to: button.randomOffsetX * 8
            duration: button.randomDuration
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 0
            duration: button.randomDuration
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: -button.randomOffsetX * 8
            duration: button.randomDuration
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 0
            duration: button.randomDuration
            easing.type: Easing.InOutSine
        }
    }
    
    SequentialAnimation on floatY {
        id: floatYAnimation
        loops: Animation.Infinite
        running: true
        
        PauseAnimation {
            duration: button.randomDelay
        }
        
        NumberAnimation {
            to: button.randomOffsetY * 8
            duration: button.randomDuration
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 0
            duration: button.randomDuration
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: -button.randomOffsetY * 8
            duration: button.randomDuration
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 0
            duration: button.randomDuration
            easing.type: Easing.InOutSine
        }
    }
    
    transform: Translate {
        x: button.floatX
        y: button.floatY
    }
    
    SvgIcon {
        id: iconImage
        anchors.centerIn: parent
        anchors.verticalCenterOffset: button.isActive ? -button.hoverLift : 0
        width: button.iconSize
        height: button.iconSize
        source: button.iconSource
        color: button.isActive ? button.iconHoverColor : button.iconBaseColor
        visible: button.iconSource !== ""
        z: 1
        scale: button.isActive ? button.hoverScale : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 600
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }

        Behavior on anchors.verticalCenterOffset {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
    }

    Text {
        id: iconText
        anchors.centerIn: parent
        anchors.verticalCenterOffset: button.isActive ? -button.hoverLift : 0
        text: button.icon
        font.pixelSize: button.textSize
        visible: button.iconSource === ""
        color: button.isActive ? button.iconHoverColor : button.iconBaseColor
        z: 1
        scale: button.isActive ? button.hoverScale : 1.0
        
        Behavior on scale {
            NumberAnimation {
                duration: 600
                easing.type: Easing.OutCubic
            }
        }
        
        Behavior on color {
            ColorAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
        
        Behavior on anchors.verticalCenterOffset {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
    }
    
    Text {
        id: labelText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: (button.iconSource !== "" ? iconImage.bottom : iconText.bottom)
        anchors.topMargin: 4
        text: button.label
        font.pixelSize: modeManager.scale(10)
        font.family: "M PLUS 2"
        color: Qt.rgba(1, 1, 1, 0.7)
        z: 1
        
        opacity: button.isActive ? 1.0 : 0.0
        visible: opacity > 0.01 && button.label !== ""
        
        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
