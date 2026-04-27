import QtQuick
import "../ui" as UI

Item {
    id: root
    
    property var modeManager
    
    function scaled(val) {
        if (modeManager) return modeManager.scale(val)
        return val
    }

    property string iconSource: ""
    property string iconText: ""
    property color iconColor: Qt.rgba(0.92, 0.92, 0.96, 0.90)
    property int iconSize: scaled(24)
    property real normalOpacity: 0.6
    property real hoverOpacity: 1.0
    property real normalScale: 1.0
    property real hoverScale: 1.3
    property int opacityDuration: 400
    property int scaleDuration: 600

    property string fontFamily: "M PLUS 2"
    property int fontSize: scaled(14)
    property int fontWeight: Font.Normal
    property real letterSpacing: 0
    
    signal clicked()
    signal rightClicked()
    
    implicitWidth: iconSize
    implicitHeight: iconSize
    
    UI.SvgIcon {
        id: svgIcon
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        source: root.iconSource
        color: root.iconColor
        opacity: mouseArea.containsMouse ? root.hoverOpacity : root.normalOpacity
        scale: mouseArea.containsMouse ? root.hoverScale : root.normalScale
        visible: root.iconSource !== ""
        
        Behavior on opacity {
            NumberAnimation {
                duration: root.opacityDuration
                easing.type: Easing.OutCubic
            }
        }
        
        Behavior on scale {
            NumberAnimation {
                duration: root.scaleDuration
                easing.type: Easing.OutCubic
            }
        }
    }
    
    Text {
        id: textIcon
        anchors.centerIn: parent
        text: root.iconText
        color: root.iconColor
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        font.weight: root.fontWeight
        font.letterSpacing: root.letterSpacing
        opacity: mouseArea.containsMouse ? root.hoverOpacity : root.normalOpacity
        scale: mouseArea.containsMouse ? root.hoverScale : root.normalScale
        visible: root.iconSource === "" && root.iconText !== ""
        
        Behavior on opacity {
            NumberAnimation {
                duration: root.opacityDuration
                easing.type: Easing.OutCubic
            }
        }
        
        Behavior on scale {
            NumberAnimation {
                duration: root.scaleDuration
                easing.type: Easing.OutCubic
            }
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked()
            } else {
                root.clicked()
            }
        }
    }
}

