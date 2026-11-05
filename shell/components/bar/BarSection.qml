pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt.labs.qmlmodels
import "../../lib" as Lib
import "../ui" as UI
import "./left" as Left
import "./right" as Right

RowLayout {
    id: root

    required property string side

    property var theme
    property var typo
    property var icons
    property var modeManager
    property var settingsManager
    property var audioManager
    property var musicPlayerManager
    property var cavaManager
    property var timerManager
    property var weatherManager
    property var notificationManager
    property var wifiManager
    property var bluetoothManager
    property var airplaneManager
    property var batteryManager
    property var imeStatus
    property var idleInhibitorManager
    property var brightnessManager
    property bool aiThinking: false
    property bool aiPanelOpen: false

    property var unavailable: ({})
    readonly property var ids: Lib.BarLayoutRules.sectionIds(
        root.settingsManager ? root.settingsManager.barLayoutItems : Lib.BarLayoutRules.defaultItems(), root.side)
    readonly property var shownSeparators: Lib.BarLayoutRules.shownSeparators(root.ids, root.unavailable)

    property var _orbOwner: null
    readonly property var orbItem: root._orbOwner
    property var _trayOwner: null
    property bool _trayOwnerMenuOpen: false
    readonly property bool trayMenuOpen: root._trayOwnerMenuOpen

    function scaled(val) {
        if (root.modeManager) return root.modeManager.barScale(val)
        return val
    }

    function reportAvailable(id, available) {
        const next = Object.assign({}, root.unavailable)
        next[id] = !available
        root.unavailable = next
    }

    spacing: root.side === "left" ? 4 : root.scaled(4)
    Layout.alignment: Qt.AlignVCenter

    Repeater {
        model: root.ids

        delegate: DelegateChooser {
            role: "modelData"

            DelegateChoice {
                roleValue: "separator"
                BarSeparator {
                    id: separator
                    required property int index
                    theme: root.theme
                    modeManager: root.modeManager
                    visible: root.shownSeparators[separator.index] === true
                }
            }

            DelegateChoice {
                roleValue: "launcher"
                Left.LauncherButton {
                    theme: root.theme
                    typo: root.typo
                    icons: root.icons
                    modeManager: root.modeManager
                }
            }

            DelegateChoice {
                roleValue: "clock"
                Left.ClockDate {
                    theme: root.theme
                    typo: root.typo
                    modeManager: root.modeManager
                    settingsManager: root.settingsManager
                }
            }

            DelegateChoice {
                roleValue: "timer"
                Left.TimerPill {
                    Layout.leftMargin: root.scaled(8)
                    id: timerPill
                    theme: root.theme
                    typo: root.typo
                    modeManager: root.modeManager
                    timerManager: root.timerManager
                    Component.onCompleted: root.reportAvailable("timer", timerPill.available)
                    onAvailableChanged: root.reportAvailable("timer", timerPill.available)
                }
            }

            DelegateChoice {
                roleValue: "weather"
                Left.WeatherIndicator {
                    id: weatherIndicator
                    theme: root.theme
                    typo: root.typo
                    icons: root.icons
                    modeManager: root.modeManager
                    weatherManager: root.weatherManager
                    Component.onCompleted: root.reportAvailable("weather", weatherIndicator.available)
                    onAvailableChanged: root.reportAvailable("weather", weatherIndicator.available)
                }
            }

            DelegateChoice {
                roleValue: "wallpaper"
                Left.WallpaperButton {
                    theme: root.theme
                    typo: root.typo
                    icons: root.icons
                    modeManager: root.modeManager
                }
            }

            DelegateChoice {
                roleValue: "screenshot"
                UI.ScreenshotButton {
                    Layout.leftMargin: root.scaled(4)
                    theme: root.theme
                    icons: root.icons
                    modeManager: root.modeManager
                }
            }

            DelegateChoice {
                roleValue: "volume"
                Left.VolumeIndicator {
                    theme: root.theme
                    typo: root.typo
                    icons: root.icons
                    modeManager: root.modeManager
                    audioManager: root.audioManager
                }
            }

            DelegateChoice {
                roleValue: "music"
                Left.MusicButton {
                    Layout.leftMargin: root.scaled(4)
                    theme: root.theme
                    typo: root.typo
                    icons: root.icons
                    modeManager: root.modeManager
                    musicPlayerManager: root.musicPlayerManager
                    cavaManager: root.cavaManager
                }
            }

            DelegateChoice {
                roleValue: "yura"
                Left.YuraOrb {
                    id: yuraOrb
                    theme: root.theme
                    modeManager: root.modeManager
                    settingsManager: root.settingsManager
                    aiThinking: root.aiThinking
                    aiPanelOpen: root.aiPanelOpen
                    onAvailableChanged: root.reportAvailable("yura", yuraOrb.available)
                    Component.onCompleted: {
                        root._orbOwner = yuraOrb
                        root.reportAvailable("yura", yuraOrb.available)
                    }
                    Component.onDestruction: {
                        if (root._orbOwner === yuraOrb) root._orbOwner = null
                    }
                }
            }

            DelegateChoice {
                roleValue: "tray"
                UI.Tray {
                    id: tray
                    opensTowardRight: root.side === "left"
                    modeManager: root.modeManager
                    theme: root.theme
                    onMenuOpenChanged: {
                        if (root._trayOwner === tray) root._trayOwnerMenuOpen = tray.menuOpen
                    }
                    Component.onCompleted: {
                        root._trayOwner = tray
                        root._trayOwnerMenuOpen = tray.menuOpen
                    }
                    Component.onDestruction: {
                        if (root._trayOwner !== tray) return
                        root._trayOwner = null
                        root._trayOwnerMenuOpen = false
                    }
                }
            }

            DelegateChoice {
                roleValue: "notifications"
                Right.NotificationIcon {
                    theme: root.theme
                    icons: root.icons
                    modeManager: root.modeManager
                    notificationManager: root.notificationManager
                }
            }

            DelegateChoice {
                roleValue: "ime"
                UI.ImeIndicator {
                    id: imeIndicator
                    theme: root.theme
                    imeStatus: root.imeStatus
                    modeManager: root.modeManager
                    Component.onCompleted: root.reportAvailable("ime", imeIndicator.available)
                    onAvailableChanged: root.reportAvailable("ime", imeIndicator.available)
                }
            }

            DelegateChoice {
                roleValue: "idle"
                Right.IdleInhibitorToggle {
                    Layout.leftMargin: root.spacing
                    theme: root.theme
                    icons: root.icons
                    modeManager: root.modeManager
                    idleInhibitorManager: root.idleInhibitorManager
                }
            }

            DelegateChoice {
                roleValue: "brightness"
                Right.BrightnessIndicator {
                    id: brightnessIndicator
                    theme: root.theme
                    typo: root.typo
                    modeManager: root.modeManager
                    brightnessManager: root.brightnessManager
                    Component.onCompleted: root.reportAvailable("brightness", brightnessIndicator.available)
                    onAvailableChanged: root.reportAvailable("brightness", brightnessIndicator.available)
                }
            }

            DelegateChoice {
                roleValue: "battery"
                Right.BatteryIndicator {
                    id: batteryIndicator
                    theme: root.theme
                    typo: root.typo
                    icons: root.icons
                    modeManager: root.modeManager
                    batteryManager: root.batteryManager
                    settingsManager: root.settingsManager
                    Component.onCompleted: root.reportAvailable("battery", batteryIndicator.available)
                    onAvailableChanged: root.reportAvailable("battery", batteryIndicator.available)
                }
            }

            DelegateChoice {
                roleValue: "airplane"
                Right.AirplaneToggle {
                    id: airplaneToggle
                    theme: root.theme
                    icons: root.icons
                    modeManager: root.modeManager
                    airplaneManager: root.airplaneManager
                    batteryManager: root.batteryManager
                    Component.onCompleted: root.reportAvailable("airplane", airplaneToggle.available)
                    onAvailableChanged: root.reportAvailable("airplane", airplaneToggle.available)
                }
            }

            DelegateChoice {
                roleValue: "wifi"
                Right.WifiButton {
                    theme: root.theme
                    icons: root.icons
                    modeManager: root.modeManager
                    wifiManager: root.wifiManager
                }
            }

            DelegateChoice {
                roleValue: "bluetooth"
                Right.BluetoothButton {
                    Layout.leftMargin: root.scaled(4)
                    theme: root.theme
                    icons: root.icons
                    modeManager: root.modeManager
                    bluetoothManager: root.bluetoothManager
                }
            }

            DelegateChoice {
                roleValue: "power"
                UI.PowerMenu {
                    modeManager: root.modeManager
                    icons: root.icons
                    theme: root.theme
                }
            }
        }
    }
}
