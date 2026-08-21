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
import "../components/common" as Common
import "../lib" as Theme

PanelWindow {
    id: barWindow

    // SettingsManager lives inside this window, so the monitor choice can only resolve here.
    function screenByName(name) {
        if (!name || name === "") return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) return Quickshell.screens[i]
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }
    screen: screenByName(settingsManager.initialDisplayMonitor)

    anchors.top: true
    anchors.left: true
    anchors.right: true

    // Overlay so panels ride above fullscreen apps; with none open the bar hides entirely.
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property var hyprMonitor: barWindow.screen
        ? Hyprland.monitorFor(barWindow.screen)
        : null
    readonly property bool fullscreenActive: hyprMonitor && hyprMonitor.activeWorkspace
        ? hyprMonitor.activeWorkspace.hasFullscreen
        : false
    readonly property bool fullscreenHidden: fullscreenActive && modeManager.isMode("normal")

    property bool lockHidden: false
    property real lockOpacity: 1.0
    property int lockClientPid: 0

    readonly property bool barHidden: fullscreenHidden || lockHidden

    implicitHeight: modeManager.currentBarSize.height
    // Not lock-aware: dropping the zone reflows tiled windows, which session_lock_xray makes visible.
    exclusiveZone: fullscreenHidden ? 0 : modeManager.normalBarSize.height
    // The lock path fades to zero instead of unmapping: an unmapped layer has no exclusive zone.
    visible: !fullscreenHidden
    // Release keyboard focus in normal mode so launched apps can receive it.
    focusable: !modeManager.isMode("normal")
    color: "transparent"

    HyprlandFocusGrab {
        windows: [barWindow]
        // A module open at lock time would leave a grab pulling focus toward an unmapped bar.
        active: !modeManager.isMode("normal") && modeManager.openedViaIpc
            && !barWindow.lockHidden
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

            // Per-panel Keys handlers never fire: escKeyHandler owns focus while a panel is open.
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
                // PanelWindow has no requestActivate(); focusable + FocusGrab give focus, then push inward.
                Qt.callLater(() => {
                    escKeyHandler.forceActiveFocus()
                })
            }
        }
    }

    property alias notificationManager: notificationManager

    // AI only counts down while quiet: no streamed reply, no unsent draft, nothing being spoken.
    readonly property bool aiQuiet: !yuraSpeaking && !yuraFloatThinking
        && (!aiAssistantLoader.item
            || (!aiAssistantLoader.item.streaming && !aiAssistantLoader.item.hasDraft))
    readonly property bool autoCloseEligible: !modeManager.isMode("normal")
        && !modeManager.isMode("notification-popup")
        && settingsManager.autoCloseTimerInterval > 0
        && (!modeManager.isMode("ai") || aiQuiet)

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
            duration: settingsManager.animationDurationMultiplier === 0 ? 0 : Theme.Motion.sweep * settingsManager.animationDurationMultiplier
            easing.type: Easing.OutExpo
        }
    }

    Theme.ModeManager { id: modeManager; screenWidth: barWindow.width; settingsManager: settingsManager }

    readonly property Component defaultModuleBackground: Component {
        Common.ModuleBackdrop {
            id: defaultBackdrop
            readonly property var pal: Theme.ModulePalettes.byId(settingsManager.moduleBackdropPalette)

            theme: barWindow.themeRef
            satMin: defaultBackdrop.pal.satMin
            satMax: defaultBackdrop.pal.satMax
            hueOffsets: defaultBackdrop.pal.hueOffsets
            strength: defaultBackdrop.pal.strength
            levels: defaultBackdrop.pal.levels
            sourceIndex: defaultBackdrop.pal.sourceIndex
        }
    }

    Theme.Colors { id: theme }

    readonly property var themeRef: theme

    Theme.Typography { id: typo }

    Theme.IconProvider { id: icons }

    Theme.SettingsManager { id: settingsManager }

    Theme.AiBackend { id: aiBackend }

    readonly property string soundsDir: Theme.Paths.soundsDir
    readonly property string timerSoundsDir: Theme.Paths.timerSoundsDir

    Theme.TimerManager {
        id: timerManager

        onCompleted: {
            // Don't yank focus from another open panel; viaIpc activates the grab so the bar gets it.
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

    Managers.MusicPlayerManager {
        id: musicPlayerManager
        fallbackAccent: theme.accent
    }

    Theme.IpcRouter {
        audioManager: audioManager
        musicPlayerManager: musicPlayerManager
        modeManager: modeManager
        brightnessManager: brightnessManager
        wallpaperManager: wallpaperManager
        notificationManager: notificationManager
        theme: theme
        timerManager: timerManager
        settingsManager: settingsManager
        weatherManager: weatherManager
    }

    // Float Yura and yurad both mirror their state here over IPC, so auto-close waits for a spoken read-out.
    property bool yuraFloatThinking: false
    property bool yuraSpeaking: false
    property bool yuraPanelOpen: false
    // A visible conversation is the one a voice turn continues.
    readonly property bool yuraSurfaceOpen: yuraPanelOpen || modeManager.isMode("ai")

    IpcHandler {
        target: "yura"
        function set_thinking(on: bool): void {
            barWindow.yuraFloatThinking = on
            if (on) yuraThinkingFailsafe.restart()
            else yuraThinkingFailsafe.stop()
        }
        function set_speaking(on: bool): void {
            barWindow.yuraSpeaking = on
            if (on) yuraSpeakingFailsafe.restart()
            else yuraSpeakingFailsafe.stop()
        }
        function set_panel_open(on: bool): void {
            barWindow.yuraPanelOpen = on
            if (on) yuraPanelFailsafe.restart()
            else yuraPanelFailsafe.stop()
        }
        function orb_home(): string {
            if (barWindow.barHidden || !modeManager.isMode("normal")) return ""
            const r = leftSection.aiOrbScreenRect()
            return Math.round(r.x) + " " + Math.round(r.y) + " " + Math.round(r.size)
        }
    }

    function showAfterLock() {
        if (!lockHidden) return
        lockFadeOut.stop()
        lockClientPid = 0
        lockHidden = false
        lockFadeIn.start()
    }

    // On contentItem, so surface.opacity and its Behavior stay untouched.
    Binding {
        target: barWindow.contentItem
        property: "opacity"
        value: barWindow.lockOpacity
    }

    NumberAnimation {
        id: lockFadeOut
        target: barWindow
        property: "lockOpacity"
        to: 0
        duration: settingsManager.animationDurationMultiplier === 0
            ? 0 : Theme.Motion.micro * settingsManager.animationDurationMultiplier
        easing.type: Easing.OutCubic
        onFinished: modeManager.closeAllModes()
    }

    NumberAnimation {
        id: lockFadeIn
        target: barWindow
        property: "lockOpacity"
        to: 1
        duration: settingsManager.animationDurationMultiplier === 0
            ? 0 : Theme.Motion.standard * settingsManager.animationDurationMultiplier
        easing.type: Easing.OutCubic
    }

    IpcHandler {
        target: "bar"

        function rect(): string {
            if (barWindow.barHidden || !barWindow.screen)
                return JSON.stringify({ hidden: true })

            const w = Math.round(surface.width)
            const h = Math.round(surface.height)
            if (w <= 0 || h <= 0) return JSON.stringify({ hidden: true })

            // Rectangle clamps radius to half the shorter side, so the raw setting would climb with the card.
            const effective = Math.min(settingsManager.barRadius, Math.min(w, h) / 2)

            const n = modeManager.normalBarSize
            const nw = Math.round(barWindow.width - n.leftMargin - n.rightMargin)
            const nh = Math.round(n.height - n.topMargin - n.bottomMargin)
            const nEffective = Math.min(settingsManager.barRadius,
                                        Math.min(nw, nh) / 2)

            // Only exclusive top layer, so window-local == monitor-local.
            return JSON.stringify({
                screen: barWindow.screen.name,
                x: Math.round(surface.x), y: Math.round(surface.y),
                w: w, h: h,
                radius: Math.round(effective),
                opacity: Number(surface.opacity.toFixed(2)),
                themeMode: theme.themeMode === "light" ? "light" : "dark",
                exitX: Math.round(n.leftMargin), exitY: Math.round(n.topMargin),
                exitW: nw, exitH: nh, exitRadius: Math.round(nEffective)
            })
        }

        function hide(pid: int): string {
            barWindow.lockClientPid = pid
            if (!barWindow.lockHidden) {
                barWindow.lockHidden = true
                lockFadeIn.stop()
                lockFadeOut.start()
            }
            return "ok"
        }

        // Not `show`: IpcHandler resolves that against QObject and answers with its handler listing.
        function restore(): string {
            barWindow.showAfterLock()
            return "ok"
        }
    }

    Timer {
        id: lockAliveCheck
        interval: 60000
        repeat: true
        running: barWindow.lockHidden && barWindow.lockClientPid > 0
        onTriggered: lockProbe.running = true
    }

    Process {
        id: lockProbe
        running: false
        // The verdict is on stdout because qmllint rejects any onExited handler.
        command: ["sh", "-c",
                  "kill -0 \"$1\" 2>/dev/null && echo alive || echo dead",
                  "sh", String(barWindow.lockClientPid)]

        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "alive") barWindow.showAfterLock()
            }
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        running: barWindow.lockHidden && barWindow.lockClientPid <= 0
        onTriggered: barWindow.showAfterLock()
    }

    // If yura-shell dies mid-stream its clearing IPC never arrives, so the icon would glow forever.
    Timer {
        id: yuraThinkingFailsafe
        interval: 15 * 60 * 1000
        onTriggered: barWindow.yuraFloatThinking = false
    }

    // A spoken reply runs minutes at most; past that yurad died mid-turn.
    Timer {
        id: yuraSpeakingFailsafe
        interval: 10 * 60 * 1000
        onTriggered: barWindow.yuraSpeaking = false
    }

    Timer {
        id: yuraPanelFailsafe
        interval: 30 * 60 * 1000
        onTriggered: barWindow.yuraPanelOpen = false
    }

    Managers.WallpaperManager { id: wallpaperManager }

    Managers.IdleInhibitorManager { id: idleInhibitorManager }

    Managers.WiFiManager { id: wifiManager }

    Managers.BluetoothManager { id: bluetoothManager }

    Managers.AirplaneManager { id: airplaneManager; active: batteryManager.present }

    Managers.BatteryManager { id: batteryManager }

    Managers.WeatherManager {
        id: weatherManager
        enabled: settingsManager.weatherEnabled
        locationOverride: settingsManager.weatherLocation
        unit: settingsManager.weatherUnit
    }

    Managers.ClipboardManager { id: clipboardManager }

    Managers.ScreenshotManager { id: screenshotManager }

    Managers.CavaManager {
        id: cavaManager

        // The bar visualiser only draws while playing; the two panels need it while open.
        isActive: musicPlayerManager.isPlaying
            || modeManager.isMode("volume")
            || modeManager.isMode("music")
    }

    Managers.CavaManager { id: micCavaManager; source: "mic" }

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
        anchors.topMargin: modeManager.currentBarSize.topMargin
        anchors.bottomMargin: modeManager.currentBarSize.bottomMargin
        anchors.leftMargin: modeManager.currentBarSize.leftMargin
        anchors.rightMargin: modeManager.currentBarSize.rightMargin

        z: 0
        baseRadius: settingsManager.barRadius
        moduleBackground: modeManager.currentSurfaceBackground
            ? modeManager.currentSurfaceBackground
            : (modeManager.currentModeInstance && settingsManager.moduleBackdropEnabled
                ? barWindow.defaultModuleBackground
                : null)
        moduleContext: modeManager.currentModeInstance
        backdropSpread: settingsManager.moduleBackdropSpread

        theme: theme

        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: settingsManager.animationDurationMultiplier === 0 ? 0 : Theme.Motion.sweep * settingsManager.animationDurationMultiplier
                easing.type: Easing.OutExpo
            }
        }

        Behavior on anchors.leftMargin {
            NumberAnimation {
                duration: settingsManager.animationDurationMultiplier === 0 ? 0 : Theme.Motion.sweep * settingsManager.animationDurationMultiplier
                easing.type: Easing.OutExpo
            }
        }

        Behavior on anchors.rightMargin {
            NumberAnimation {
                duration: settingsManager.animationDurationMultiplier === 0 ? 0 : Theme.Motion.sweep * settingsManager.animationDurationMultiplier
                easing.type: Easing.OutExpo
            }
        }

        opacity: barWindow.implicitHeight > modeManager.normalBarSize.height ? 0.95 : 0.85

        Behavior on opacity {
            NumberAnimation {
                duration: settingsManager.animationDurationMultiplier === 0 ? 0 : Theme.Motion.standard * settingsManager.animationDurationMultiplier
                easing.type: Easing.OutCubic
            }
        }
    }

    Item {
        id: contentClipContainer
        anchors.fill: parent
        anchors.topMargin: modeManager.currentBarSize.topMargin
        anchors.bottomMargin: modeManager.currentBarSize.bottomMargin
        anchors.leftMargin: modeManager.currentBarSize.leftMargin
        anchors.rightMargin: modeManager.currentBarSize.rightMargin
        clip: true
        z: 1

        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: settingsManager.animationDurationMultiplier === 0 ? 0 : Theme.Motion.sweep * settingsManager.animationDurationMultiplier
                easing.type: Easing.OutExpo
            }
        }

        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: settingsManager.animationDurationMultiplier === 0 ? 0 : Theme.Motion.sweep * settingsManager.animationDurationMultiplier
                easing.type: Easing.OutExpo
            }
        }

        Behavior on anchors.leftMargin {
            NumberAnimation {
                duration: settingsManager.animationDurationMultiplier === 0 ? 0 : Theme.Motion.sweep * settingsManager.animationDurationMultiplier
                easing.type: Easing.OutExpo
            }
        }

        Behavior on anchors.rightMargin {
            NumberAnimation {
                duration: settingsManager.animationDurationMultiplier === 0 ? 0 : Theme.Motion.sweep * settingsManager.animationDurationMultiplier
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
        // Never bind visible here — it severs the binding and leaves the bar permanently empty.
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
                        duration: contentRow.isFirstShow ? 0 : (settingsManager.animationDurationMultiplier === 0 ? 0 : Theme.Motion.gentle * settingsManager.animationDurationMultiplier)
                    }
                    NumberAnimation {
                        property: "opacity"
                        duration: contentRow.isFirstShow ? 0 : (settingsManager.animationDurationMultiplier === 0 ? 0 : Theme.Motion.gentle * settingsManager.animationDurationMultiplier)
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
            weatherManager: weatherManager
            aiThinking: (aiAssistantLoader.item ? aiAssistantLoader.item.streaming : false)
                || barWindow.yuraFloatThinking
            aiSpeaking: barWindow.yuraSpeaking
            aiPanelOpen: barWindow.yuraPanelOpen
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
            airplaneManager: airplaneManager
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
        settingsManager: settingsManager
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
        property var themeRef: theme
        active: modeManagerRef.isMode("powermenu")
        sourceComponent: Content.PowerMenuContent {
            anchors.fill: parent
            visible: powerMenuLoader.modeManagerRef.isMode("powermenu")
            modeManager: powerMenuLoader.modeManagerRef
            icons: powerMenuLoader.iconsRef
            theme: powerMenuLoader.themeRef
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

        // AI stays resident after first open so chat state survives close-reopen; others unload.
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
            voiceSpeaking: barWindow.yuraSpeaking
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
        property var settingsManagerRef: settingsManager
        active: modeManagerRef.isMode("launcher")
        sourceComponent: Content.AppLauncherContent {
            anchors.fill: parent
            visible: appLauncherLoader.modeManagerRef.isMode("launcher")
            modeManager: appLauncherLoader.modeManagerRef
            theme: appLauncherLoader.themeRef
            icons: appLauncherLoader.iconsRef
            typo: appLauncherLoader.typoRef
            settingsManager: appLauncherLoader.settingsManagerRef
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
        property var settingsManagerRef: settingsManager
        active: modeManagerRef.isMode("notification")
        sourceComponent: Content.NotificationContent {
            anchors.fill: parent
            visible: notificationLoader.modeManagerRef.isMode("notification")
            modeManager: notificationLoader.modeManagerRef
            notificationManager: notificationLoader.notificationManagerRef
            theme: notificationLoader.themeRef
            icons: notificationLoader.iconsRef
            settingsManager: notificationLoader.settingsManagerRef
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
        id: weatherLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: modeManager
        property var themeRef: theme
        property var iconsRef: icons
        property var weatherManagerRef: weatherManager
        property var settingsManagerRef: settingsManager
        active: modeManagerRef.isMode("weather")
        sourceComponent: Content.WeatherContent {
            anchors.fill: parent
            visible: weatherLoader.modeManagerRef.isMode("weather")
            modeManager: weatherLoader.modeManagerRef
            weatherManager: weatherLoader.weatherManagerRef
            theme: weatherLoader.themeRef
            icons: weatherLoader.iconsRef
            reduceMotion: weatherLoader.settingsManagerRef ? weatherLoader.settingsManagerRef.reduceMotion : false
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
        settingsManager: settingsManager
        theme: theme
        icons: icons
    }

    Component.onCompleted: {
        modeManager.listModes()
    }
}
