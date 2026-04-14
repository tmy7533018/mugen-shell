import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Qt5Compat.GraphicalEffects
import "../components/ui" as UI
import "../components/content" as Content
import "../components/managers" as Managers
import "../components/bar" as BarComponents
import "../lib" as Theme

PanelWindow {
    id: barWindow

    anchors.top: true
    anchors.left: true
    anchors.right: true

    implicitHeight: modeManager.currentBarSize.height
    exclusiveZone: modeManager.scale(60)
    // In normal mode, don't hold keyboard focus so launched apps receive focus instead
    focusable: !modeManager.isMode("normal")
    color: "transparent"

    HyprlandFocusGrab {
        windows: [barWindow]
        active: !modeManager.isMode("normal") && modeManager.openedViaIpc
    }

    Item {
        id: escKeyHandler
        anchors.fill: parent
        focus: false

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape && !modeManager.isMode("normal")) {
                modeManager.closeAllModes()
                event.accepted = true
            } else {
                event.accepted = false
            }
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (!modeManager.isMode("normal") && modeManager.openedViaIpc) {
                Qt.callLater(() => {
                    // PanelWindow lacks forceActiveFocus(), so activate the window
                    // then move focus to the internal Item
                    barWindow.requestActivate()
                    escKeyHandler.forceActiveFocus()
                })
            }
        }
    }

    property alias notificationManager: notificationManager

    Behavior on implicitHeight {
        NumberAnimation {
            duration: settingsManager.animationDurationMultiplier === 0 ? 0 : 1000 * settingsManager.animationDurationMultiplier
            easing.type: Easing.OutExpo
        }
    }

    Theme.ModeManager { id: modeManager; screenWidth: barWindow.width }

    Theme.Colors { id: theme }

    Theme.Typography { id: typo }

    Theme.IconProvider { id: icons }

    Theme.SettingsManager { id: settingsManager }

    Managers.AudioManager { id: audioManager }

    Managers.MusicPlayerManager { id: musicPlayerManager }

    Managers.WallpaperManager { id: wallpaperManager }

    Managers.IdleInhibitorManager { id: idleInhibitorManager }

    Managers.WiFiManager { id: wifiManager }

    Managers.BluetoothManager { id: bluetoothManager }

    Managers.ClipboardManager { id: clipboardManager }

    Managers.ScreenshotManager { id: screenshotManager }

    Managers.CavaManager {
        id: cavaManager

        // Keep always active to prevent multiple process conflicts
        Component.onCompleted: {
            isActive = true
        }
    }

    property int previousVolume: audioManager.volume
    property bool previousMuted: audioManager.isMuted
    property bool isInitialized: false

    Timer {
        id: initTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            previousVolume = audioManager.volume
            previousMuted = audioManager.isMuted
            isInitialized = true
        }
    }

    Connections {
        target: audioManager

        function onVolumeChanged() {
            // Skip during startup initialization
            if (!isInitialized) {
                previousVolume = audioManager.volume
                return
            }

            if (audioManager.volume !== previousVolume) {
                if (!modeManager.isMode("volume")) {
                    modeManager.switchMode("volume")
                }
                previousVolume = audioManager.volume
            }
        }

        function onIsMutedChanged() {
            // Skip during startup initialization
            if (!isInitialized) {
                previousMuted = audioManager.isMuted
                return
            }

            if (audioManager.isMuted !== previousMuted) {
                if (!modeManager.isMode("volume")) {
                    modeManager.switchMode("volume")
                }
                previousMuted = audioManager.isMuted
            }
        }
    }

    Managers.ImeStatus {
        id: imeStatus
        theme: theme
    }

    Managers.NotificationManager {
        id: notificationManager
    }

    Managers.WindowManager {
        id: windowManager
    }

    UI.MugenSurface {
        id: surface

        anchors.fill: parent
        anchors.topMargin: 6
        anchors.bottomMargin: modeManager.currentBarSize.bottomMargin
        anchors.leftMargin: modeManager.currentBarSize.leftMargin
        anchors.rightMargin: modeManager.currentBarSize.rightMargin

        z: 0
        baseRadius: 50

        theme: theme

        gradientColor1: theme.glowPrimary
        gradientColor2: theme.glowSecondary
        gradientColor3: theme.glowTertiary

        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: settingsManager.animationDurationMultiplier === 0 ? 0 : 1000 * settingsManager.animationDurationMultiplier
                easing.type: Easing.OutExpo
            }
        }

        Behavior on anchors.leftMargin {
            NumberAnimation {
                duration: settingsManager.animationDurationMultiplier === 0 ? 0 : 1000 * settingsManager.animationDurationMultiplier
                easing.type: Easing.OutExpo
            }
        }

        Behavior on anchors.rightMargin {
            NumberAnimation {
                duration: settingsManager.animationDurationMultiplier === 0 ? 0 : 1000 * settingsManager.animationDurationMultiplier
                easing.type: Easing.OutExpo
            }
        }

        opacity: barWindow.implicitHeight > modeManager.normalBarSize.height ? 0.95 : 0.85

        Behavior on opacity {
            NumberAnimation {
                duration: settingsManager.animationDurationMultiplier === 0 ? 0 : 300 * settingsManager.animationDurationMultiplier
                easing.type: Easing.OutCubic
            }
        }

        gradientEnabled: settingsManager.barGradientEnabled
    }

    // Clip container prevents icons from overflowing during bar transitions
    Item {
        id: contentClipContainer
        anchors.fill: parent
        anchors.topMargin: 6
        anchors.bottomMargin: modeManager.currentBarSize.bottomMargin
        anchors.leftMargin: modeManager.currentBarSize.leftMargin
        anchors.rightMargin: modeManager.currentBarSize.rightMargin
        clip: true
        z: 1

        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: settingsManager.animationDurationMultiplier === 0 ? 0 : 1000 * settingsManager.animationDurationMultiplier
                easing.type: Easing.OutExpo
            }
        }

        Behavior on anchors.leftMargin {
            NumberAnimation {
                duration: settingsManager.animationDurationMultiplier === 0 ? 0 : 1000 * settingsManager.animationDurationMultiplier
                easing.type: Easing.OutExpo
            }
        }

        Behavior on anchors.rightMargin {
            NumberAnimation {
                duration: settingsManager.animationDurationMultiplier === 0 ? 0 : 1000 * settingsManager.animationDurationMultiplier
                easing.type: Easing.OutExpo
            }
        }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        spacing: 20
        Layout.alignment: Qt.AlignVCenter

        property bool isFirstShow: true

        opacity: 0
        // NOTE: Do not bind visible directly -- it breaks the binding and causes
        // a permanently empty bar. Use opacity for display control instead.
        enabled: modeManager.isMode("normal")

        Component.onCompleted: {
            initialShowTimer.start();
        }

        Timer {
            id: initialShowTimer
            interval: 100
            running: false
            onTriggered: {
            }
        }

        states: [
            State {
                name: "visible"
                when: modeManager.isMode("normal")
                PropertyChanges { target: contentRow; opacity: 1.0 }
            }
        ]

        transitions: [
            Transition {
                from: "visible"
                to: ""
                SequentialAnimation {
                    NumberAnimation {
                        property: "opacity"
                        duration: settingsManager.animationDurationMultiplier === 0 ? 0 : 70 * settingsManager.animationDurationMultiplier
                        easing.type: Easing.OutCubic
                    }
                }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation {
                        duration: contentRow.isFirstShow ? 0 : (settingsManager.animationDurationMultiplier === 0 ? 0 : 370 * settingsManager.animationDurationMultiplier)
                    }
                    NumberAnimation {
                        property: "opacity"
                        duration: contentRow.isFirstShow ? 0 : (settingsManager.animationDurationMultiplier === 0 ? 0 : 400 * settingsManager.animationDurationMultiplier)
                        easing.type: Easing.InOutCubic
                    }
                    ScriptAction {
                        script: {
                            if (contentRow.isFirstShow) {
                                contentRow.isFirstShow = false
                            }
                        }
                    }
                }
            }
        ]

        BarComponents.BarLeftSection {
            id: leftSection
            theme: theme
            typo: typo
            icons: icons
            modeManager: modeManager
            imeStatus: imeStatus
            screenshotManager: screenshotManager
            audioManager: audioManager
            musicPlayerManager: musicPlayerManager
            cavaManager: cavaManager
        }

        Item { Layout.fillWidth: true }

        BarComponents.BarRightSection {
            id: rightSection
            theme: theme
            typo: typo
            icons: icons
            modeManager: modeManager
            notificationManager: notificationManager
            wifiManager: wifiManager
            bluetoothManager: bluetoothManager
            imeStatus: imeStatus
            idleInhibitorManager: idleInhibitorManager
        }
        }
    }

    UI.Workspaces {
        id: workspaces
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        z: 1.5
        activeColor: theme.glowPrimary
        hasWindowsColor: Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.5)
        modeManager: modeManager

        opacity: contentRow.opacity
        visible: opacity > 0.01
    }

    Content.PowerMenuContent {
        id: powerMenuContent
        anchors.fill: parent
        z: 2
        visible: modeManager.isMode("powermenu")
        modeManager: modeManager
        icons: icons
    }

    Content.CalendarContent {
        id: calendarContent
        anchors.fill: parent
        z: 2
        visible: modeManager.isMode("calendar")
        modeManager: modeManager
        theme: theme
    }

    Content.MusicPlayerContent {
        id: musicPlayerContent
        anchors.fill: parent
        z: 2
        visible: modeManager.isMode("music")
        modeManager: modeManager
        musicManager: musicPlayerManager
        cavaManager: cavaManager
        theme: theme
        icons: icons
    }

    Content.AiAssistantContent {
        id: aiAssistantContent
        anchors.fill: parent
        z: 2
        visible: modeManager.isMode("ai")
        modeManager: modeManager
        theme: theme
        icons: icons
    }

    Content.AppLauncherContent {
        icons: icons
        id: appLauncherContent
        anchors.fill: parent
        z: 2
        visible: modeManager.isMode("launcher")
        modeManager: modeManager
        theme: theme
        typo: typo
    }

    Content.VolumeContent {
        id: volumeContent
        anchors.fill: parent
        z: 2
        visible: modeManager.isMode("volume")
        modeManager: modeManager
        audioManager: audioManager
        cavaManager: cavaManager
        musicPlayerManager: musicPlayerManager
        theme: theme
        typo: typo
    }

    Content.NotificationContent {
        id: notificationContent
        anchors.fill: parent
        z: 2
        visible: modeManager.isMode("notification")
        modeManager: modeManager
        notificationManager: notificationManager
        theme: theme
        icons: icons
    }

    Content.WiFiContent {
        id: wifiContent
        anchors.fill: parent
        z: 2
        visible: modeManager.isMode("wifi")
        modeManager: modeManager
        wifiManager: wifiManager
        theme: theme
        icons: icons
    }

    Content.BluetoothContent {
        id: bluetoothContent
        anchors.fill: parent
        z: 2
        visible: modeManager.isMode("bluetooth")
        modeManager: modeManager
        bluetoothManager: bluetoothManager
        theme: theme
        icons: icons
    }

    Content.WallpaperContent {
        id: wallpaperContent
        anchors.fill: parent
        z: 2
        visible: modeManager.isMode("wallpaper")
        modeManager: modeManager
        wallpaperManager: wallpaperManager
        theme: theme
        icons: icons
    }

    Content.SettingsContent {
        id: settingsContent
        anchors.fill: parent
        z: 2
        visible: modeManager.isMode("settings")
        modeManager: modeManager
        theme: theme
        icons: icons
        settingsManager: settingsManager
    }

    Content.ScreenshotGalleryContent {
        id: screenshotGalleryContent
        anchors.fill: parent
        z: 2
        visible: modeManager.isMode("screenshot-gallery")
        modeManager: modeManager
        screenshotManager: screenshotManager
        theme: theme
    }

    Content.ClipboardContent {
        id: clipboardContent
        anchors.fill: parent
        z: 2
        visible: modeManager.isMode("clipboard")
        modeManager: modeManager
        clipboardManager: clipboardManager
        theme: theme
        icons: icons
    }

    Content.WindowSwitcherContent {
        id: windowSwitcherContent
        anchors.fill: parent
        z: 2
        visible: modeManager.isMode("window-switcher")
        modeManager: modeManager
        windowManager: windowManager
        theme: theme
        typo: typo
        barWidth: barWindow.width
        settingsManager: settingsManager
    }

    Content.NotificationPopupContent {
        id: notificationPopupContent
        anchors.fill: parent
        z: 3
        visible: modeManager.isMode("notification-popup")
        modeManager: modeManager
        notificationManager: notificationManager
        theme: theme
        icons: icons
    }

    Component.onCompleted: {
        modeManager.listModes()

        appLauncherContent.preloadApps()

        initTimer.start()
    }
}
