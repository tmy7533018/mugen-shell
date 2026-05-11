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

    // Overlay layer so panels can ride above fullscreen apps; while a panel
    // isn't open we hide entirely so the fullscreen app keeps every pixel.
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property var hyprMonitor: barWindow.screen
        ? Hyprland.monitorFor(barWindow.screen)
        : null
    readonly property bool fullscreenActive: hyprMonitor && hyprMonitor.activeWorkspace
        ? hyprMonitor.activeWorkspace.hasFullscreen
        : false
    readonly property bool barHidden: fullscreenActive && modeManager.isMode("normal")

    implicitHeight: modeManager.currentBarSize.height
    exclusiveZone: barHidden ? 0 : modeManager.scale(60)
    visible: !barHidden
    // Release keyboard focus in normal mode so launched apps can receive it.
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
            if (modeManager.isMode("normal")) {
                event.accepted = false
                return
            }

            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
                return
            }

            // Music shortcuts handled here — per-panel Keys handlers don't fire
            // because escKeyHandler owns active focus while a panel is open.
            if (modeManager.isMode("music") && musicPlayerManager) {
                if (event.key === Qt.Key_Space) {
                    musicPlayerManager.playPause()
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Left) {
                    musicPlayerManager.previous()
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Right) {
                    musicPlayerManager.next()
                    event.accepted = true
                    return
                }
            }

            if (modeManager.isMode("brightness") && brightnessManager) {
                let step = (event.modifiers & Qt.ShiftModifier) ? 10 : 2
                if (event.key === Qt.Key_Up || event.key === Qt.Key_Right) {
                    brightnessManager.bump(step)
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Down || event.key === Qt.Key_Left) {
                    brightnessManager.bump(-step)
                    event.accepted = true
                    return
                }
            }

            event.accepted = false
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (!modeManager.isMode("normal") && modeManager.openedViaIpc) {
                // PanelWindow has no requestActivate() — focusable + FocusGrab
                // give the surface keyboard focus, then push it inward.
                Qt.callLater(() => {
                    escKeyHandler.forceActiveFocus()
                })
            }
        }
    }

    property alias notificationManager: notificationManager

    // Auto-close any open mode after idle. AI is exempt — users read streamed
    // responses without moving the cursor, so it relies on ESC / click-outside.
    readonly property bool autoCloseEligible: !modeManager.isMode("normal")
        && !modeManager.isMode("ai")
        && settingsManager.autoCloseTimerInterval > 0

    Timer {
        id: autoCloseTimer
        interval: settingsManager.autoCloseTimerInterval > 0 ? settingsManager.autoCloseTimerInterval : 60000
        repeat: false
        running: barWindow.autoCloseEligible
        onTriggered: {
            if (!modeManager.isMode("normal")) modeManager.closeAllModes()
        }
    }

    Connections {
        target: modeManager
        function onInteraction() {
            if (barWindow.autoCloseEligible) autoCloseTimer.restart()
        }
    }

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

    Theme.AiBackend { id: aiBackend }

    readonly property string soundsDir: {
        let xdg = Quickshell.env("XDG_DATA_HOME")
        if (!xdg || xdg === "") xdg = Quickshell.env("HOME") + "/.local/share"
        return xdg + "/mugen-shell/sounds"
    }
    readonly property string timerSoundsDir: {
        let xdg = Quickshell.env("XDG_DATA_HOME")
        if (!xdg || xdg === "") xdg = Quickshell.env("HOME") + "/.local/share"
        return xdg + "/mugen-shell/timer-sounds"
    }

    Theme.TimerManager {
        id: timerManager

        onCompleted: {
            // Don't yank focus from another open panel. viaIpc activates
            // HyprlandFocusGrab so the bar actually receives keyboard focus.
            if (modeManager.isMode("normal")) {
                modeManager.switchMode("timer", true)
            }
        }

        onAlertingChanged: {
            if (alerting) {
                barWindow._playTimerSound()
                timerLoopTimer.restart()
                timerSafetyTimer.restart()
            } else {
                timerLoopTimer.stop()
                timerSafetyTimer.stop()
                if (timerSoundProcess.running) timerSoundProcess.running = false
            }
        }
    }

    function _playTimerSound() {
        const name = settingsManager ? settingsManager.timerSound : "None"
        if (!name || name === "None" || name === "") return
        timerSoundProcess.command = ["paplay", barWindow.timerSoundsDir + "/" + name]
        timerSoundProcess.running = true
    }

    Process {
        id: timerSoundProcess
        command: []
        running: false
    }

    Timer {
        id: timerLoopTimer
        interval: 4000
        repeat: true
        running: false
        onTriggered: barWindow._playTimerSound()
    }

    Timer {
        id: timerSafetyTimer
        interval: 60000
        repeat: false
        running: false
        onTriggered: {
            if (timerManager.alerting) timerManager.dismissAlert()
        }
    }

    Managers.AudioManager { id: audioManager }

    Managers.BrightnessManager { id: brightnessManager }

    Managers.MusicPlayerManager { id: musicPlayerManager }

    Theme.IpcRouter {
        audioManager: audioManager
        musicPlayerManager: musicPlayerManager
        modeManager: modeManager
        brightnessManager: brightnessManager
        wallpaperManager: wallpaperManager
        notificationManager: notificationManager
        theme: theme
        timerManager: timerManager
    }

    Managers.WallpaperManager { id: wallpaperManager }

    Managers.IdleInhibitorManager { id: idleInhibitorManager }

    Managers.WiFiManager { id: wifiManager }

    Managers.BluetoothManager { id: bluetoothManager }

    Managers.BatteryManager { id: batteryManager }

    Managers.ClipboardManager { id: clipboardManager }

    Managers.ScreenshotManager { id: screenshotManager }

    Managers.CavaManager {
        id: cavaManager

        // Keep always active to prevent multiple process conflicts
        Component.onCompleted: {
            isActive = true
        }
    }

    Managers.MicCavaManager { id: micCavaManager }

    Managers.ImeStatus {
        id: imeStatus
        theme: theme
    }

    Managers.NotificationManager {
        id: notificationManager
        settingsManager: settingsManager
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
            screenshotManager: screenshotManager
            audioManager: audioManager
            musicPlayerManager: musicPlayerManager
            cavaManager: cavaManager
            settingsManager: settingsManager
            timerManager: timerManager
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
            batteryManager: batteryManager
            imeStatus: imeStatus
            idleInhibitorManager: idleInhibitorManager
            brightnessManager: brightnessManager
            settingsManager: settingsManager
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

    Loader {
        id: powerMenuLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: modeManager
        property var iconsRef: icons
        active: modeManagerRef.isMode("powermenu")
        sourceComponent: Content.PowerMenuContent {
            anchors.fill: parent
            visible: powerMenuLoader.modeManagerRef.isMode("powermenu")
            modeManager: powerMenuLoader.modeManagerRef
            icons: powerMenuLoader.iconsRef
        }
    }

    Loader {
        id: timerLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: modeManager
        property var themeRef: theme
        property var timerManagerRef: timerManager
        active: modeManagerRef.isMode("timer")
        sourceComponent: Content.TimerContent {
            anchors.fill: parent
            visible: timerLoader.modeManagerRef.isMode("timer")
            modeManager: timerLoader.modeManagerRef
            theme: timerLoader.themeRef
            timerManager: timerLoader.timerManagerRef
        }
    }

    Loader {
        id: musicPlayerLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: modeManager
        property var themeRef: theme
        property var iconsRef: icons
        property var musicManagerRef: musicPlayerManager
        property var cavaManagerRef: cavaManager
        active: modeManagerRef.isMode("music")
        sourceComponent: Content.MusicPlayerContent {
            anchors.fill: parent
            visible: musicPlayerLoader.modeManagerRef.isMode("music")
            modeManager: musicPlayerLoader.modeManagerRef
            musicManager: musicPlayerLoader.musicManagerRef
            cavaManager: musicPlayerLoader.cavaManagerRef
            theme: musicPlayerLoader.themeRef
            icons: musicPlayerLoader.iconsRef
        }
    }

    Loader {
        id: aiAssistantLoader
        anchors.fill: parent
        z: 2

        property var modeManagerRef: modeManager
        property var themeRef: theme
        property var iconsRef: icons
        property var settingsManagerRef: settingsManager
        property var aiBackendRef: aiBackend

        // AI stays resident after first open so chat / streaming state survive
        // close-reopen. Other modules unload to keep idle memory flat.
        property bool everLoaded: false
        active: modeManagerRef.isMode("ai") || everLoaded
        onLoaded: everLoaded = true

        sourceComponent: Content.AiAssistantContent {
            anchors.fill: parent
            visible: aiAssistantLoader.modeManagerRef.isMode("ai")
            modeManager: aiAssistantLoader.modeManagerRef
            theme: aiAssistantLoader.themeRef
            icons: aiAssistantLoader.iconsRef
            settingsManager: aiAssistantLoader.settingsManagerRef
            aiBackend: aiAssistantLoader.aiBackendRef
        }
    }

    Loader {
        id: appLauncherLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: modeManager
        property var themeRef: theme
        property var iconsRef: icons
        property var typoRef: typo
        active: modeManagerRef.isMode("launcher")
        sourceComponent: Content.AppLauncherContent {
            anchors.fill: parent
            visible: appLauncherLoader.modeManagerRef.isMode("launcher")
            modeManager: appLauncherLoader.modeManagerRef
            theme: appLauncherLoader.themeRef
            icons: appLauncherLoader.iconsRef
            typo: appLauncherLoader.typoRef
        }
    }

    Loader {
        id: volumeLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: modeManager
        property var themeRef: theme
        property var typoRef: typo
        property var audioManagerRef: audioManager
        property var cavaManagerRef: cavaManager
        property var micCavaManagerRef: micCavaManager
        property var musicPlayerManagerRef: musicPlayerManager
        active: modeManagerRef.isMode("volume")
        sourceComponent: Content.VolumeContent {
            anchors.fill: parent
            visible: volumeLoader.modeManagerRef.isMode("volume")
            modeManager: volumeLoader.modeManagerRef
            audioManager: volumeLoader.audioManagerRef
            cavaManager: volumeLoader.cavaManagerRef
            micCavaManager: volumeLoader.micCavaManagerRef
            musicPlayerManager: volumeLoader.musicPlayerManagerRef
            theme: volumeLoader.themeRef
            typo: volumeLoader.typoRef
        }
    }

    Loader {
        id: brightnessLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: modeManager
        property var themeRef: theme
        property var typoRef: typo
        property var brightnessManagerRef: brightnessManager
        active: modeManagerRef.isMode("brightness")
        sourceComponent: Content.BrightnessContent {
            anchors.fill: parent
            visible: brightnessLoader.modeManagerRef.isMode("brightness")
            modeManager: brightnessLoader.modeManagerRef
            brightnessManager: brightnessLoader.brightnessManagerRef
            theme: brightnessLoader.themeRef
            typo: brightnessLoader.typoRef
        }
    }

    Loader {
        id: notificationLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: modeManager
        property var themeRef: theme
        property var iconsRef: icons
        property var notificationManagerRef: notificationManager
        active: modeManagerRef.isMode("notification")
        sourceComponent: Content.NotificationContent {
            anchors.fill: parent
            visible: notificationLoader.modeManagerRef.isMode("notification")
            modeManager: notificationLoader.modeManagerRef
            notificationManager: notificationLoader.notificationManagerRef
            theme: notificationLoader.themeRef
            icons: notificationLoader.iconsRef
        }
    }

    Loader {
        id: wifiLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: modeManager
        property var themeRef: theme
        property var iconsRef: icons
        property var wifiManagerRef: wifiManager
        active: modeManagerRef.isMode("wifi")
        sourceComponent: Content.WiFiContent {
            anchors.fill: parent
            visible: wifiLoader.modeManagerRef.isMode("wifi")
            modeManager: wifiLoader.modeManagerRef
            wifiManager: wifiLoader.wifiManagerRef
            theme: wifiLoader.themeRef
            icons: wifiLoader.iconsRef
        }
    }

    Loader {
        id: bluetoothLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: modeManager
        property var themeRef: theme
        property var iconsRef: icons
        property var bluetoothManagerRef: bluetoothManager
        active: modeManagerRef.isMode("bluetooth")
        sourceComponent: Content.BluetoothContent {
            anchors.fill: parent
            visible: bluetoothLoader.modeManagerRef.isMode("bluetooth")
            modeManager: bluetoothLoader.modeManagerRef
            bluetoothManager: bluetoothLoader.bluetoothManagerRef
            theme: bluetoothLoader.themeRef
            icons: bluetoothLoader.iconsRef
        }
    }

    Loader {
        id: wallpaperLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: modeManager
        property var themeRef: theme
        property var iconsRef: icons
        property var wallpaperManagerRef: wallpaperManager
        active: modeManagerRef.isMode("wallpaper")
        sourceComponent: Content.WallpaperContent {
            anchors.fill: parent
            visible: wallpaperLoader.modeManagerRef.isMode("wallpaper")
            modeManager: wallpaperLoader.modeManagerRef
            wallpaperManager: wallpaperLoader.wallpaperManagerRef
            theme: wallpaperLoader.themeRef
            icons: wallpaperLoader.iconsRef
        }
    }

    Loader {
        id: screenshotGalleryLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: modeManager
        property var themeRef: theme
        property var screenshotManagerRef: screenshotManager
        active: modeManagerRef.isMode("screenshot-gallery")
        sourceComponent: Content.ScreenshotGalleryContent {
            anchors.fill: parent
            visible: screenshotGalleryLoader.modeManagerRef.isMode("screenshot-gallery")
            modeManager: screenshotGalleryLoader.modeManagerRef
            screenshotManager: screenshotGalleryLoader.screenshotManagerRef
            theme: screenshotGalleryLoader.themeRef
        }
    }

    Loader {
        id: clipboardLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: modeManager
        property var themeRef: theme
        property var iconsRef: icons
        property var clipboardManagerRef: clipboardManager
        active: modeManagerRef.isMode("clipboard")
        sourceComponent: Content.ClipboardContent {
            anchors.fill: parent
            visible: clipboardLoader.modeManagerRef.isMode("clipboard")
            modeManager: clipboardLoader.modeManagerRef
            clipboardManager: clipboardLoader.clipboardManagerRef
            theme: clipboardLoader.themeRef
            icons: clipboardLoader.iconsRef
        }
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
    }
}
