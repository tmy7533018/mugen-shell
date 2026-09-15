import QtQuick
import QtQuick.Layouts
import "../../common" as Common
import "../../../lib" as Theme

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

    readonly property string bluetoothIconSource: {
        if (!icons || !bluetoothManager) return ""
        return icons.getBluetoothIcon(isPowered, isScanning, hasConnectedDevices).value
    }

    Component {
        id: runeRig
        Common.BluetoothRig {
            color: bluetoothContainer.theme ? bluetoothContainer.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            variant: bluetoothContainer.isScanning ? "searching" : (bluetoothContainer.hasConnectedDevices ? "connected" : "plain")
        }
    }
    Component {
        id: slashRig
        Common.ShakeRig {
            color: bluetoothContainer.theme ? bluetoothContainer.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            source: bluetoothContainer.bluetoothIconSource
        }
    }

    Loader {
        id: bluetoothIcon
        anchors.centerIn: parent
        width: bluetoothContainer.scaled(24)
        height: bluetoothContainer.scaled(24)
        sourceComponent: bluetoothContainer.isPowered ? runeRig : slashRig
        opacity: bluetoothMouseArea.containsMouse ? 1.0 : 0.6

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.Motion.gentle
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: bluetoothMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: if (bluetoothIcon.item) bluetoothIcon.item.play()
        onClicked: {
            if (bluetoothContainer.modeManager) {
                bluetoothContainer.modeManager.switchMode("bluetooth")
            }
        }
    }
}
