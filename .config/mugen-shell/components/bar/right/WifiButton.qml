import QtQuick
import QtQuick.Layouts
import "../../ui" as UI

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

    UI.SvgIcon {
        id: wifiIconSvg
        anchors.centerIn: parent
        width: wifiContainer.scaled(24)
        height: wifiContainer.scaled(24)
        source: wifiContainer.icons ? (wifiContainer.isConnected ? wifiContainer.icons.wifiSvg : wifiContainer.icons.wifiOffSvg) : ""
        color: wifiContainer.theme ? wifiContainer.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        opacity: wifiMouseArea.containsMouse ? 1.0 : 0.6
        scale: wifiMouseArea.containsMouse ? 1.3 : 1.0

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
        id: wifiMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (wifiContainer.modeManager) {
                wifiContainer.modeManager.switchMode("wifi")
            }
        }
    }
}
