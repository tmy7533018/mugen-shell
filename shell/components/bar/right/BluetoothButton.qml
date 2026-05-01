import QtQuick
import QtQuick.Layouts
import "../../ui" as UI

Item {
    id: bluetoothContainer

    required property var theme
    required property var icons
    required property var modeManager
    required property var bluetoothManager

    function scaled(v) { return modeManager ? modeManager.scale(v) : v }

    implicitWidth: scaled(24)
    implicitHeight: scaled(24)
    Layout.alignment: Qt.AlignVCenter
    Layout.leftMargin: scaled(4)

    property bool isPowered: bluetoothManager ? bluetoothManager.isPowered : false
    property bool isScanning: bluetoothManager ? bluetoothManager.isScanning : false
    property bool hasConnectedDevices: bluetoothManager ? bluetoothManager.hasConnectedDevices : false

    UI.SvgIcon {
        id: bluetoothIconSvg
        anchors.centerIn: parent
        width: bluetoothContainer.scaled(24)
        height: bluetoothContainer.scaled(24)
        source: {
            if (!bluetoothContainer.icons || !bluetoothContainer.bluetoothManager) return ""
            let iconData = bluetoothContainer.icons.getBluetoothIcon(bluetoothContainer.isPowered, bluetoothContainer.isScanning, bluetoothContainer.hasConnectedDevices)
            return iconData.value
        }
        color: bluetoothContainer.theme ? bluetoothContainer.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        opacity: bluetoothMouseArea.containsMouse ? 1.0 : 0.6
        scale: bluetoothMouseArea.containsMouse ? 1.3 : 1.0

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
        id: bluetoothMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (bluetoothContainer.modeManager) {
                bluetoothContainer.modeManager.switchMode("bluetooth")
            }
        }
    }
}
