import QtQuick
import QtQuick.Layouts
import Quickshell
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
    }
}
