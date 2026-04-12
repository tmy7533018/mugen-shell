import QtQuick
import QtQuick.Layouts
import Quickshell
import "../common" as Common
import "../ui" as UI

Item {
    id: powerMenuRoot

    property var modeManager

    function scaled(val) {
        if (modeManager) return modeManager.scale(val)
        return val
    }

    implicitWidth: scaled(24)
    implicitHeight: scaled(24)

    signal clicked()
    signal rightClicked()

    property color accentColor: Qt.rgba(0.65, 0.55, 0.85, 0.9)
    property color textColor: Qt.rgba(0.92, 0.92, 0.96, 0.90)

    required property var icons

    function generateRandomColor() {
        let hue = (Date.now() % 360) + Math.random() * 360
        if (hue > 360) hue = hue % 360
        let saturation = 0.3 + Math.random() * 0.4
        let value = 0.8 + Math.random() * 0.2
        return Qt.hsva(hue / 360, saturation, value, 0.3)
    }
    
    property color blobColor: generateRandomColor()
    
    Common.BlobEffect {
        anchors.fill: parent
        anchors.leftMargin: scaled(-20)
        anchors.rightMargin: scaled(-20)
        anchors.topMargin: scaled(-14)
        anchors.bottomMargin: scaled(-14)
        blobColor: powerMenuRoot.blobColor
        layers: 3
        waveAmplitude: 2.0
        baseOpacity: 0.4
        animationSpeed: 0.08
        pointCount: 12
        z: -1
        opacity: mouseArea.containsMouse ? 1.0 : 0.0
        visible: opacity > 0.01
        running: mouseArea.containsMouse
        
        Behavior on opacity {
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }
    }

    UI.SvgIcon {
        id: menuIconSvg
        anchors.centerIn: parent
        width: scaled(24)
        height: scaled(24)
        source: icons.iconData.menu.type === "svg" ? icons.iconData.menu.value : ""
        color: textColor
        opacity: mouseArea.containsMouse ? 1.0 : 0.6
        scale: mouseArea.pressed ? 0.9 : (mouseArea.containsMouse ? 1.3 : 1.0)
        visible: icons.iconData.menu.type === "svg"

        Behavior on opacity {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 600
                easing.type: Easing.OutCubic
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: icons.iconData.menu.type === "text" ? icons.iconData.menu.value : ""
        font.pixelSize: scaled(20)
        color: textColor
        visible: icons.iconData.menu.type === "text"
        opacity: mouseArea.containsMouse ? 1.0 : 0.6
        scale: mouseArea.pressed ? 0.9 : (mouseArea.containsMouse ? 1.3 : 1.0)

        Behavior on opacity {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 600
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
                powerMenuRoot.rightClicked()
            } else {
                powerMenuRoot.clicked()
            }
        }
        
        onContainsMouseChanged: {
            if (containsMouse) {
                powerMenuRoot.blobColor = powerMenuRoot.generateRandomColor()
            }
        }
    }
}
