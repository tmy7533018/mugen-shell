import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
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

    readonly property bool lockHidden: lockHide.lockHidden

    readonly property bool barHidden: fullscreenHidden || lockHidden || autoHide.hidden

    readonly property bool aiThinking: (barPanels.aiItem ? barPanels.aiItem.streaming : false)
        || yuraMirror.yuraFloatThinking

    // First touch of this singleton starts the StatusNotifier watcher, and apps need it while the Tray icon is hidden.
    readonly property var trayService: SystemTray

    BarComponents.AutoHide {
        id: autoHide
        enabled: settingsManager.barAutoHide
        held: !modeManager.isMode("normal") || leftSection.trayMenuOpen || rightSection.trayMenuOpen
        stripHovered: revealStripHover.hovered
        barHovered: barBodyHover.hovered
        suspended: barWindow.fullscreenHidden || barWindow.lockHidden
    }

    implicitHeight: modeManager.normalBarSize.height
    // Not lock-aware: dropping the zone reflows tiled windows, which session_lock_xray makes visible.
    exclusiveZone: (fullscreenHidden || settingsManager.barAutoHide) ? 0 : modeManager.normalBarSize.height
    // The lock path fades to zero instead of unmapping: an unmapped layer has no exclusive zone.
    visible: !fullscreenHidden
    // Quickshell never re-creates a layer surface the compositor closed because its output went away.
    onScreenChanged: Qt.callLater(barWindow.restoreClosedSurface)
    function restoreClosedSurface() {
        if (barWindow.visible || barWindow.fullscreenHidden || !Quickshell.screens.some(s => s === barWindow.screen && s.name !== "")) return
        barWindow.visible = false
        barWindow.visible = Qt.binding(() => !barWindow.fullscreenHidden)
    }
    focusable: modeManager.wantsKeyboard
    color: "transparent"

    HyprlandFocusGrab {
        windows: [barWindow]
        // Clicking the bar does not hand the layer surface keyboard focus, so a panel that takes keys needs the grab.
        // A module open at lock time would leave a grab pulling focus toward an unmapped bar.
        active: modeManager.wantsKeyboard && !barWindow.lockHidden
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

            modeManager.bump()

            // Music and brightness never take focus, and the launcher takes it only when focusTimer fires.
            if (modeManager.isMode("launcher") && barPanels.launcherItem
                    && (barPanels.launcherItem as Content.AppLauncherContent).forwardKeyToSearch(event)) {
                event.accepted = true
                return
            }

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
            // Every open, not just IPC: a click focuses the surface but leaves QML focus elsewhere, so Escape dies.
            if (modeManager.wantsKeyboard) {
                // PanelWindow has no requestActivate(); focusable + FocusGrab give focus, then push inward.
                Qt.callLater(() => {
                    escKeyHandler.forceActiveFocus()
                })
            }
        }
    }

    property alias notificationManager: notificationManager

    // AI only counts down while quiet: no streamed reply, no unsent draft.
    readonly property bool aiQuiet: !yuraMirror.yuraFloatThinking
        && (!barPanels.aiItem
            || (!barPanels.aiItem.streaming && !barPanels.aiItem.hasDraft))
    readonly property bool wifiQuiet: !barPanels.wifiItem || !(barPanels.wifiItem as Content.WiFiContent).hasDraft
    readonly property bool autoCloseEligible: !modeManager.isMode("normal")
        && !modeManager.isMode("notification-popup")
        && settingsManager.autoCloseTimerInterval > 0
        && (!modeManager.isMode("ai") || aiQuiet)
        && (!modeManager.isMode("wifi") || wifiQuiet)
        && !panelPointer.active

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

    // Input follows the animated body, not the stepped window, so the gap left while shrinking
    // stays click-through instead of swallowing presses meant for the app underneath.
    mask: Region {
        item: autoHide.hidden ? revealStrip : barBody
        // A still pointer on the strip would get a Leave while the body slides in under it, and the bar would hide again.
        Region { item: autoHide.enabled ? revealStrip : null }
    }

    Item {
        id: revealStrip
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: autoHide.stripHeight
        visible: autoHide.enabled

        HoverHandler { id: revealStripHover }
    }

    // The layer only ever grows: every resize shifts the bar content for two frames, and a shrink would do that on each close.
    readonly property int targetHeight: modeManager.currentBarSize.height
    onTargetHeightChanged: if (targetHeight > implicitHeight) implicitHeight = targetHeight

    // The screen, not the window: hidden over a fullscreen app the window is 0 wide, and panels opened from there would lay out at scale 0.
    Theme.ModeManager { id: modeManager; screenWidth: barWindow.screen ? barWindow.screen.width : barWindow.width; settingsManager: settingsManager }

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

    Theme.Colors {
        id: theme
        settings: settingsManager

        // A module backdrop hides the face entirely, so only judge the colour when none is up.
        windowTint: (settingsManager.barSurfaceCustom && !surface.moduleBackground)
            ? Qt.hsla(settingsManager.barSurfaceHue,
                      settingsManager.barSurfaceSaturation,
                      settingsManager.barSurfaceLightness,
                      settingsManager.barSurfaceOpacity)
            : "transparent"
    }

    readonly property var themeRef: theme

    Theme.Typography { id: typo }

    Theme.IconProvider { id: icons }

    Theme.SettingsManager { id: settingsManager }

    Theme.AiBackend { id: aiBackend }

    readonly property string soundsDir: Theme.Paths.soundsDir

    Theme.TimerManager { id: timerManager }

    BarComponents.TimerAlertSound {
        timerManagerRef: timerManager
        modeManagerRef: modeManager
        settingsManagerRef: settingsManager
    }

    Managers.AudioManager { id: audioManager }

    Managers.BrightnessManager { id: brightnessManager }

    Managers.MusicPlayerManager {
        id: musicPlayerManager
        fallbackAccent: theme.accent
        positionWanted: modeManager.isMode("music")
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

    BarComponents.YuraMirror {
        id: yuraMirror
        barHidden: barWindow.barHidden
        modeManagerRef: modeManager
        orbHost: leftSection.orbItem || rightSection.orbItem
    }

    BarComponents.LockHide {
        id: lockHide
        modeManagerRef: modeManager
    }

    // On contentItem, so surface.opacity and its Behavior stay untouched.
    Binding {
        target: barWindow.contentItem
        property: "opacity"
        value: lockHide.lockOpacity
    }

    IdleMonitor {
        id: ambientIdle
        timeout: 90
        respectInhibitors: false
    }

    Binding {
        target: Theme.Motion
        property: "ambientPaused"
        value: ambientIdle.isIdle || barWindow.barHidden
    }

    IpcHandler {
        target: "bar"

        function rect(): string {
            if (!barWindow.screen)
                return JSON.stringify({ hidden: true })
            const screenName = barWindow.screen.name
            // An auto-hiding bar may be gone by unlock, so the lock fades on this monitor rather than morphing out of the bar.
            if (barWindow.barHidden || autoHide.enabled)
                return JSON.stringify({ hidden: true, screen: screenName })

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

            // A top-anchored layer with no margins, so window-local == monitor-local.
            return JSON.stringify({
                screen: screenName,
                x: Math.round(surface.x), y: Math.round(surface.y),
                w: w, h: h,
                radius: Math.round(effective),
                opacity: Number(surface.opacity.toFixed(2)),
                themeMode: theme.themeMode === "light" ? "light" : "dark",
                surfaceColor: String(surface.baseColor),
                surfaceBorder: surface.showBorder,
                exitX: Math.round(n.leftMargin), exitY: Math.round(n.topMargin),
                exitW: nw, exitH: nh, exitRadius: Math.round(nEffective)
            })
        }

        function hide(pid: int): string {
            lockHide.hide(pid)
            return "ok"
        }

        // Not `show`: IpcHandler resolves that against QObject and answers with its handler listing.
        function restore(): string {
            lockHide.showAfterLock()
            return "ok"
        }
    }

    Managers.WallpaperManager {
        id: wallpaperManager
        settingsManager: settingsManager
        slideshowBlocked: wallpaperPlayback.wantPause || barWindow.lockHidden
    }

    Managers.WallpaperPlayback {
        id: wallpaperPlayback
        settingsManager: settingsManager
        toplevels: ToplevelManager.toplevels.values
        videoPath: wallpaperManager.isVideoFile(wallpaperManager.currentWallpaperPath) ? wallpaperManager.currentWallpaperPath : ""
    }

    Managers.IdleInhibitorManager { id: idleInhibitorManager }

    Managers.WiFiManager { id: wifiManager }

    Managers.BluetoothManager { id: bluetoothManager }

    Managers.AirplaneManager { id: airplaneManager; active: batteryManager.present }

    Managers.BatteryManager { id: batteryManager }

    Managers.WeatherManager {
        id: weatherManager
        enabled: settingsManager._settingsLoaded && settingsManager.weatherEnabled
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
        active: !barWindow.barHidden && !ambientIdle.isIdle
    }

    Managers.NotificationManager {
        id: notificationManager
        settingsManager: settingsManager
    }

    // The window is the layer-shell surface, and resizing it costs a frame, so the visible
    // geometry animates here while the window only steps.
    Item {
        id: barBody
        anchors.left: parent.left
        anchors.right: parent.right
        y: autoHide.hidden ? -modeManager.normalBarSize.height : 0
        height: modeManager.currentBarSize.height

        Behavior on height {
            NumberAnimation {
                duration: Theme.Motion.sweep
                easing.type: Easing.OutExpo
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.Motion.standard
                easing.type: Theme.Motion.easeOut
            }
        }

        HoverHandler { id: barBodyHover }

        // Qt re-delivers a resting pointer's position every frame while anything animates, so only real motion counts.
        HoverHandler {
            id: panelHover
            enabled: !modeManager.isMode("normal")
            property point lastScene: Qt.point(-1, -1)
            onPointChanged: {
                const p = panelHover.point.scenePosition
                if (p.x === panelHover.lastScene.x && p.y === panelHover.lastScene.y) return
                panelHover.lastScene = p
                modeManager.bump()
            }
        }

        Keys.onShortcutOverride: (event) => {
            modeManager.bump()
            event.accepted = false
        }

        // Topmost and passive, so it sees the presses, drags and wheels that the panel's own items accept.
        Item {
            anchors.fill: parent
            z: 10

            PointHandler {
                id: panelPointer
                enabled: !modeManager.isMode("normal")
                acceptedButtons: Qt.AllButtons
                onPointChanged: modeManager.bump()
            }

            WheelHandler {
                target: null
                blocking: false
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                enabled: !modeManager.isMode("normal")
                onWheel: modeManager.bump()
            }

            WheelHandler {
                target: null
                blocking: false
                orientation: Qt.Horizontal
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                enabled: !modeManager.isMode("normal")
                onWheel: modeManager.bump()
            }
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
            showBorder: !settingsManager.barSurfaceCustom || settingsManager.barSurfaceBorder
            baseColor: settingsManager.barSurfaceCustom
                ? Qt.hsla(settingsManager.barSurfaceHue,
                          settingsManager.barSurfaceSaturation,
                          settingsManager.barSurfaceLightness,
                          settingsManager.barSurfaceOpacity)
                : surface.defaultBase
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
                    duration: Theme.Motion.sweep
                    easing.type: Easing.OutExpo
                }
            }

            Behavior on anchors.leftMargin {
                NumberAnimation {
                    duration: Theme.Motion.sweep
                    easing.type: Easing.OutExpo
                }
            }

            Behavior on anchors.rightMargin {
                NumberAnimation {
                    duration: Theme.Motion.sweep
                    easing.type: Easing.OutExpo
                }
            }

            opacity: barBody.height > modeManager.normalBarSize.height ? 0.95 : 0.85

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.Motion.standard
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
                    duration: Theme.Motion.sweep
                    easing.type: Easing.OutExpo
                }
            }

            Behavior on anchors.bottomMargin {
                NumberAnimation {
                    duration: Theme.Motion.sweep
                    easing.type: Easing.OutExpo
                }
            }

            Behavior on anchors.leftMargin {
                NumberAnimation {
                    duration: Theme.Motion.sweep
                    easing.type: Easing.OutExpo
                }
            }

            Behavior on anchors.rightMargin {
                NumberAnimation {
                    duration: Theme.Motion.sweep
                    easing.type: Easing.OutExpo
                }
            }

        RowLayout {
            id: contentRow
            anchors.fill: parent
            anchors.leftMargin: 32
            anchors.rightMargin: 32
            spacing: 20

            property bool isFirstShow: true

            opacity: 0
            // Never bind visible here — it severs the binding and leaves the bar permanently empty.
            enabled: modeManager.isMode("normal")

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
                            duration: Theme.Motion.dur(70)
                            easing.type: Easing.OutCubic
                        }
                    }
                },
                Transition {
                    from: ""
                    to: "visible"
                    SequentialAnimation {
                        PauseAnimation {
                            duration: contentRow.isFirstShow ? 0 : Theme.Motion.gentle
                        }
                        NumberAnimation {
                            property: "opacity"
                            duration: contentRow.isFirstShow ? 0 : Theme.Motion.gentle
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

            BarComponents.BarSection {
                id: leftSection
                side: "left"
                theme: theme
                typo: typo
                icons: icons
                modeManager: modeManager
                settingsManager: settingsManager
                audioManager: audioManager
                musicPlayerManager: musicPlayerManager
                cavaManager: cavaManager
                timerManager: timerManager
                weatherManager: weatherManager
                notificationManager: notificationManager
                wifiManager: wifiManager
                bluetoothManager: bluetoothManager
                airplaneManager: airplaneManager
                batteryManager: batteryManager
                imeStatus: imeStatus
                idleInhibitorManager: idleInhibitorManager
                brightnessManager: brightnessManager
                aiThinking: barWindow.aiThinking
                aiPanelOpen: yuraMirror.yuraPanelOpen
            }

            Item { Layout.fillWidth: true }

            BarComponents.BarSection {
                id: rightSection
                side: "right"
                theme: theme
                typo: typo
                icons: icons
                modeManager: modeManager
                settingsManager: settingsManager
                audioManager: audioManager
                musicPlayerManager: musicPlayerManager
                cavaManager: cavaManager
                timerManager: timerManager
                weatherManager: weatherManager
                notificationManager: notificationManager
                wifiManager: wifiManager
                bluetoothManager: bluetoothManager
                airplaneManager: airplaneManager
                batteryManager: batteryManager
                imeStatus: imeStatus
                idleInhibitorManager: idleInhibitorManager
                brightnessManager: brightnessManager
                aiThinking: barWindow.aiThinking
                aiPanelOpen: yuraMirror.yuraPanelOpen
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
            // Workspaces' own default assumes a dark face; the dark value here is the one it ships with.
            emptyColor: theme.onLightSurface ? Qt.rgba(0.20, 0.20, 0.24, 0.95)
                                            : Qt.rgba(0.85, 0.85, 0.85, 0.95)
            hasWindowsColor: Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.5)
            modeManager: modeManager

            opacity: contentRow.opacity
            visible: opacity > 0.01
        }

        BarComponents.BarPanels {
            id: barPanels
            anchors.fill: parent
            z: 2
            aiBackendRef: aiBackend
            audioManagerRef: audioManager
            bluetoothManagerRef: bluetoothManager
            brightnessManagerRef: brightnessManager
            cavaManagerRef: cavaManager
            clipboardManagerRef: clipboardManager
            iconsRef: icons
            micCavaManagerRef: micCavaManager
            modeManagerRef: modeManager
            musicPlayerManagerRef: musicPlayerManager
            notificationManagerRef: notificationManager
            screenshotManagerRef: screenshotManager
            settingsManagerRef: settingsManager
            themeRef: theme
            timerManagerRef: timerManager
            typoRef: typo
            wallpaperManagerRef: wallpaperManager
            weatherManagerRef: weatherManager
            wifiManagerRef: wifiManager
        }

        Content.NotificationPopupContent {
            id: notificationPopupContent
            anchors.fill: parent
            z: 3
            visible: modeManager.isMode("notification-popup")
            modeManager: modeManager
            notificationManager: notificationManager
            settingsManager: settingsManager
            fullscreenActive: barWindow.fullscreenActive
            theme: theme
            icons: icons
        }
    }
}
