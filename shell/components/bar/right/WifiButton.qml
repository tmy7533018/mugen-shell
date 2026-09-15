import QtQuick
import QtQuick.Layouts
import "../../common" as Common
import "../../../lib" as Theme

Item {
    id: wifiContainer

    required property var theme
    required property var icons
    required property var modeManager
    required property var wifiManager

    function scaled(v) { return modeManager ? modeManager.scale(v) : v }

    implicitWidth: scaled(24)
    implicitHeight: scaled(24)
    Layout.alignment: Qt.AlignVCenter

    property bool isConnected: wifiManager ? wifiManager.isConnected : false

    Component {
        id: wifiRig
        Common.WifiRig { color: wifiContainer.theme ? wifiContainer.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90) }
    }
    Component {
        id: wifiOffRig
        Common.ShakeRig {
            color: wifiContainer.theme ? wifiContainer.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            source: wifiContainer.icons ? wifiContainer.icons.wifiOffSvg : ""
        }
    }

    Loader {
        id: wifiIcon
        anchors.centerIn: parent
        width: wifiContainer.scaled(24)
        height: wifiContainer.scaled(24)
        sourceComponent: wifiContainer.isConnected ? wifiRig : wifiOffRig
        opacity: wifiMouseArea.containsMouse ? 1.0 : 0.6

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.Motion.gentle
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: wifiMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: if (wifiIcon.item) wifiIcon.item.play()
        onClicked: {
            if (wifiContainer.modeManager) {
                wifiContainer.modeManager.switchMode("wifi")
            }
        }
    }
}
