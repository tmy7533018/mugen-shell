import QtQuick
import QtQuick.Layouts
import Quickshell
import "../ui" as UI
import "../common" as Common
import "./right" as Right

RowLayout {
    id: root
    
    function scaled(val) {
        if (modeManager) return modeManager.scale(val)
        return val
    }
    
    spacing: scaled(4)
    Layout.alignment: Qt.AlignVCenter
    
    component Separator: UI.SvgIcon {
        width: 1
        height: scaled(16)
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: scaled(-4)  // Negate parent RowLayout spacing
        Layout.rightMargin: scaled(-4)  // Negate parent RowLayout spacing
        source: Quickshell.shellDir + "/assets/icons/divider.svg"
        color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.40)
        opacity: 0.5
    }
    
    property var theme
    property var typo
    property var icons
    property var notificationManager
    property var modeManager
    property var wifiManager
    property var bluetoothManager
    property var batteryManager
    property var imeStatus
    property var idleInhibitorManager
    property var settingsManager

    UI.Tray {
        modeManager: root.modeManager
        theme: root.theme
    }

    Separator {}

    Right.NotificationIcon {
        theme: root.theme
        icons: root.icons
        modeManager: root.modeManager
        notificationManager: root.notificationManager
    }

    Separator {}

    UI.ImeIndicator {
        Layout.alignment: Qt.AlignVCenter
        visible: root.imeStatus
        theme: root.theme
        imeStatus: root.imeStatus
        modeManager: root.modeManager
    }

    Right.IdleInhibitorToggle {
        theme: root.theme
        icons: root.icons
        modeManager: root.modeManager
        idleInhibitorManager: root.idleInhibitorManager
        spacing: root.spacing
    }

    Separator {}

    Right.WifiButton {
        theme: root.theme
        icons: root.icons
        modeManager: root.modeManager
        wifiManager: root.wifiManager
    }
    
    Right.BluetoothButton {
        theme: root.theme
        icons: root.icons
        modeManager: root.modeManager
        bluetoothManager: root.bluetoothManager
    }
    
    Separator {}

    UI.PowerMenu {
        modeManager: root.modeManager
        accentColor: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
        textColor: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        icons: root.icons
        theme: root.theme
        batteryManager: root.batteryManager
        settingsManager: root.settingsManager
        onClicked: {
            if (root.modeManager) {
                root.modeManager.switchMode("powermenu")
            }
        }
        onRightClicked: {
            if (root.modeManager) {
                root.modeManager.switchMode("settings")
            }
        }
    }
}

