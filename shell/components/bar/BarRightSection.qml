import QtQuick
import QtQuick.Layouts
import "../ui" as UI
import "./right" as Right

RowLayout {
    id: root
    
    function scaled(val) {
        if (modeManager) return modeManager.barScale(val)
        return val
    }
    
    spacing: scaled(4)
    Layout.alignment: Qt.AlignVCenter
    
    property var theme
    property var typo
    property var icons
    property var notificationManager
    property var modeManager
    property var wifiManager
    property var bluetoothManager
    property var airplaneManager
    property var batteryManager
    property var imeStatus
    property var idleInhibitorManager
    property var brightnessManager
    property var settingsManager

    readonly property bool trayMenuOpen: tray.menuOpen

    UI.Tray {
        id: tray
        modeManager: root.modeManager
        theme: root.theme
    }

    BarSeparator { theme: root.theme; modeManager: root.modeManager }

    Right.NotificationIcon {
        theme: root.theme
        icons: root.icons
        modeManager: root.modeManager
        notificationManager: root.notificationManager
    }

    BarSeparator { theme: root.theme; modeManager: root.modeManager }

    UI.ImeIndicator {
        theme: root.theme
        imeStatus: root.imeStatus
        modeManager: root.modeManager
    }

    Right.IdleInhibitorToggle {
        Layout.leftMargin: root.spacing
        theme: root.theme
        icons: root.icons
        modeManager: root.modeManager
        idleInhibitorManager: root.idleInhibitorManager
    }

    Right.BrightnessIndicator {
        theme: root.theme
        typo: root.typo
        modeManager: root.modeManager
        brightnessManager: root.brightnessManager
    }

    Right.BatteryIndicator {
        theme: root.theme
        typo: root.typo
        icons: root.icons
        modeManager: root.modeManager
        batteryManager: root.batteryManager
        settingsManager: root.settingsManager
    }

    BarSeparator { theme: root.theme; modeManager: root.modeManager }

    Right.AirplaneToggle {
        theme: root.theme
        icons: root.icons
        modeManager: root.modeManager
        airplaneManager: root.airplaneManager
        batteryManager: root.batteryManager
    }

    Right.WifiButton {
        theme: root.theme
        icons: root.icons
        modeManager: root.modeManager
        wifiManager: root.wifiManager
    }
    
    Right.BluetoothButton {
        Layout.leftMargin: root.scaled(4)
        theme: root.theme
        icons: root.icons
        modeManager: root.modeManager
        bluetoothManager: root.bluetoothManager
    }
    
    BarSeparator { theme: root.theme; modeManager: root.modeManager }

    UI.PowerMenu {
        modeManager: root.modeManager
        icons: root.icons
        theme: root.theme
    }
}

