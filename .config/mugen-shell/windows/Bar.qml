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

    // EXPERIMENT 2026-04-23: stripped PauseAnimation to test whether the binding
    // was stalling mode-change on open. Revert if close-transition looks bad.
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
                    modeManager.switchMode("volume", true)
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
                    modeManager.switchMode("volume", true)
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

    Item {
        id: powerMenuWrapper
        anchors.fill: parent
        z: 2
        property bool modeActive: modeManager.isMode("powermenu")
        visible: opacity > 0.01
        opacity: modeActive ? 1.0 : 0.0
        Behavior on opacity {
            enabled: powerMenuWrapper.opacity < 0.5
            SequentialAnimation {
                PauseAnimation { duration: 300 * settingsManager.animationDurationMultiplier }
                NumberAnimation {
                    duration: 400 * settingsManager.animationDurationMultiplier
                    easing.type: Easing.InOutCubic
                }
            }
        }
        Loader {
            id: powerMenuLoader
            anchors.fill: parent
            asynchronous: true
            property var modeManagerRef: modeManager
            property var iconsRef: icons
            active: powerMenuWrapper.modeActive
            sourceComponent: Content.PowerMenuContent {
                anchors.fill: parent
                modeManager: powerMenuLoader.modeManagerRef
                icons: powerMenuLoader.iconsRef
            }
        }
    }

    Item {
        id: calendarWrapper
        anchors.fill: parent
        z: 2
        property bool modeActive: modeManager.isMode("calendar")
        visible: opacity > 0.01
        opacity: modeActive ? 1.0 : 0.0
        Behavior on opacity {
            enabled: calendarWrapper.opacity < 0.5
            SequentialAnimation {
                PauseAnimation { duration: 300 * settingsManager.animationDurationMultiplier }
                NumberAnimation {
                    duration: 400 * settingsManager.animationDurationMultiplier
                    easing.type: Easing.InOutCubic
                }
            }
        }
        Loader {
            id: calendarLoader
            anchors.fill: parent
            asynchronous: true
            property var modeManagerRef: modeManager
            property var themeRef: theme
            active: calendarWrapper.modeActive
            sourceComponent: Content.CalendarContent {
                anchors.fill: parent
                modeManager: calendarLoader.modeManagerRef
                theme: calendarLoader.themeRef
            }
        }
    }

    Item {
        id: musicPlayerWrapper
        anchors.fill: parent
        z: 2
        property bool modeActive: modeManager.isMode("music")
        visible: opacity > 0.01
        opacity: modeActive ? 1.0 : 0.0
        Behavior on opacity {
            enabled: musicPlayerWrapper.opacity < 0.5
            SequentialAnimation {
                PauseAnimation { duration: 300 * settingsManager.animationDurationMultiplier }
                NumberAnimation {
                    duration: 400 * settingsManager.animationDurationMultiplier
                    easing.type: Easing.InOutCubic
                }
            }
        }
        Loader {
            id: musicPlayerLoader
            anchors.fill: parent
            asynchronous: true
            property var modeManagerRef: modeManager
            property var themeRef: theme
            property var iconsRef: icons
            property var musicManagerRef: musicPlayerManager
            property var cavaManagerRef: cavaManager
            active: musicPlayerWrapper.modeActive
            sourceComponent: Content.MusicPlayerContent {
                anchors.fill: parent
                modeManager: musicPlayerLoader.modeManagerRef
                musicManager: musicPlayerLoader.musicManagerRef
                cavaManager: musicPlayerLoader.cavaManagerRef
                theme: musicPlayerLoader.themeRef
                icons: musicPlayerLoader.iconsRef
            }
        }
    }

    // Fixed-size Loader: decouples AI content layout from the bar's growing
    // implicitHeight. With anchors.fill: parent, the content would resize every
    // frame during the 1000ms bar-grow animation, triggering per-frame layout
    // over a heavy ColumnLayout/ListView/TextEdit subtree and causing a visible
    // freeze. Fixing the height makes layout a one-time cost.
    Loader {
        id: aiAssistantLoader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: modeManager.scale(440)
        z: 2
        asynchronous: true

        property var modeManagerRef: modeManager
        property var themeRef: theme
        property var iconsRef: icons

        // Single source of truth so the Behavior's trigger (opacity) and its
        // duration binding evaluate atomically — prevents the stale-binding
        // issue that was stalling the bar on open.
        property bool modeActive: modeManagerRef.isMode("ai")

        property bool everLoaded: false
        active: modeActive || everLoaded
        onLoaded: everLoaded = true

        sourceComponent: Content.AiAssistantContent {
            anchors.fill: parent
            opacity: aiAssistantLoader.modeActive ? 1.0 : 0.0
            enabled: aiAssistantLoader.modeActive
            Behavior on opacity {
                NumberAnimation {
                    duration: 300 * settingsManager.animationDurationMultiplier
                    easing.type: Easing.InOutCubic
                }
            }
            modeManager: aiAssistantLoader.modeManagerRef
            theme: aiAssistantLoader.themeRef
            icons: aiAssistantLoader.iconsRef
        }
    }

    Item {
        id: appLauncherWrapper
        anchors.fill: parent
        z: 2
        property bool modeActive: modeManager.isMode("launcher")
        visible: opacity > 0.01
        opacity: modeActive ? 1.0 : 0.0
        Behavior on opacity {
            enabled: appLauncherWrapper.opacity < 0.5
            SequentialAnimation {
                PauseAnimation { duration: 300 * settingsManager.animationDurationMultiplier }
                NumberAnimation {
                    duration: 400 * settingsManager.animationDurationMultiplier
                    easing.type: Easing.InOutCubic
                }
            }
        }
        Loader {
            id: appLauncherLoader
            anchors.fill: parent
            asynchronous: true
            property var modeManagerRef: modeManager
            property var themeRef: theme
            property var iconsRef: icons
            property var typoRef: typo
            active: appLauncherWrapper.modeActive
            sourceComponent: Content.AppLauncherContent {
                anchors.fill: parent
                modeManager: appLauncherLoader.modeManagerRef
                theme: appLauncherLoader.themeRef
                icons: appLauncherLoader.iconsRef
                typo: appLauncherLoader.typoRef
            }
        }
    }

    Item {
        id: volumeWrapper
        anchors.fill: parent
        z: 2
        property bool modeActive: modeManager.isMode("volume")
        visible: opacity > 0.01
        opacity: modeActive ? 1.0 : 0.0
        Behavior on opacity {
            enabled: volumeWrapper.opacity < 0.5
            SequentialAnimation {
                PauseAnimation { duration: 300 * settingsManager.animationDurationMultiplier }
                NumberAnimation {
                    duration: 400 * settingsManager.animationDurationMultiplier
                    easing.type: Easing.InOutCubic
                }
            }
        }
        Loader {
            id: volumeLoader
            anchors.fill: parent
            asynchronous: true
            property var modeManagerRef: modeManager
            property var themeRef: theme
            property var typoRef: typo
            property var audioManagerRef: audioManager
            property var cavaManagerRef: cavaManager
            property var musicPlayerManagerRef: musicPlayerManager
            active: volumeWrapper.modeActive
            sourceComponent: Content.VolumeContent {
                anchors.fill: parent
                modeManager: volumeLoader.modeManagerRef
                audioManager: volumeLoader.audioManagerRef
                cavaManager: volumeLoader.cavaManagerRef
                musicPlayerManager: volumeLoader.musicPlayerManagerRef
                theme: volumeLoader.themeRef
                typo: volumeLoader.typoRef
            }
        }
    }

    Item {
        id: notificationWrapper
        anchors.fill: parent
        z: 2
        property bool modeActive: modeManager.isMode("notification")
        visible: opacity > 0.01
        opacity: modeActive ? 1.0 : 0.0
        Behavior on opacity {
            enabled: notificationWrapper.opacity < 0.5
            SequentialAnimation {
                PauseAnimation { duration: 300 * settingsManager.animationDurationMultiplier }
                NumberAnimation {
                    duration: 400 * settingsManager.animationDurationMultiplier
                    easing.type: Easing.InOutCubic
                }
            }
        }
        Loader {
            id: notificationLoader
            anchors.fill: parent
            asynchronous: true
            property var modeManagerRef: modeManager
            property var themeRef: theme
            property var iconsRef: icons
            property var notificationManagerRef: notificationManager
            active: notificationWrapper.modeActive
            sourceComponent: Content.NotificationContent {
                anchors.fill: parent
                modeManager: notificationLoader.modeManagerRef
                notificationManager: notificationLoader.notificationManagerRef
                theme: notificationLoader.themeRef
                icons: notificationLoader.iconsRef
            }
        }
    }

    Item {
        id: wifiWrapper
        anchors.fill: parent
        z: 2
        property bool modeActive: modeManager.isMode("wifi")
        visible: opacity > 0.01
        opacity: modeActive ? 1.0 : 0.0
        Behavior on opacity {
            enabled: wifiWrapper.opacity < 0.5
            SequentialAnimation {
                PauseAnimation { duration: 300 * settingsManager.animationDurationMultiplier }
                NumberAnimation {
                    duration: 400 * settingsManager.animationDurationMultiplier
                    easing.type: Easing.InOutCubic
                }
            }
        }
        Loader {
            id: wifiLoader
            anchors.fill: parent
            asynchronous: true
            property var modeManagerRef: modeManager
            property var themeRef: theme
            property var iconsRef: icons
            property var wifiManagerRef: wifiManager
            active: wifiWrapper.modeActive
            sourceComponent: Content.WiFiContent {
                anchors.fill: parent
                modeManager: wifiLoader.modeManagerRef
                wifiManager: wifiLoader.wifiManagerRef
                theme: wifiLoader.themeRef
                icons: wifiLoader.iconsRef
            }
        }
    }

    Item {
        id: bluetoothWrapper
        anchors.fill: parent
        z: 2
        property bool modeActive: modeManager.isMode("bluetooth")
        visible: opacity > 0.01
        opacity: modeActive ? 1.0 : 0.0
        Behavior on opacity {
            enabled: bluetoothWrapper.opacity < 0.5
            SequentialAnimation {
                PauseAnimation { duration: 300 * settingsManager.animationDurationMultiplier }
                NumberAnimation {
                    duration: 400 * settingsManager.animationDurationMultiplier
                    easing.type: Easing.InOutCubic
                }
            }
        }
        Loader {
            id: bluetoothLoader
            anchors.fill: parent
            asynchronous: true
            property var modeManagerRef: modeManager
            property var themeRef: theme
            property var iconsRef: icons
            property var bluetoothManagerRef: bluetoothManager
            active: bluetoothWrapper.modeActive
            sourceComponent: Content.BluetoothContent {
                anchors.fill: parent
                modeManager: bluetoothLoader.modeManagerRef
                bluetoothManager: bluetoothLoader.bluetoothManagerRef
                theme: bluetoothLoader.themeRef
                icons: bluetoothLoader.iconsRef
            }
        }
    }

    Item {
        id: wallpaperWrapper
        anchors.fill: parent
        z: 2
        property bool modeActive: modeManager.isMode("wallpaper")
        visible: opacity > 0.01
        opacity: modeActive ? 1.0 : 0.0
        Behavior on opacity {
            enabled: wallpaperWrapper.opacity < 0.5
            SequentialAnimation {
                PauseAnimation { duration: 300 * settingsManager.animationDurationMultiplier }
                NumberAnimation {
                    duration: 400 * settingsManager.animationDurationMultiplier
                    easing.type: Easing.InOutCubic
                }
            }
        }
        Loader {
            id: wallpaperLoader
            anchors.fill: parent
            asynchronous: true
            property var modeManagerRef: modeManager
            property var themeRef: theme
            property var iconsRef: icons
            property var wallpaperManagerRef: wallpaperManager
            active: wallpaperWrapper.modeActive
            sourceComponent: Content.WallpaperContent {
                anchors.fill: parent
                modeManager: wallpaperLoader.modeManagerRef
                wallpaperManager: wallpaperLoader.wallpaperManagerRef
                theme: wallpaperLoader.themeRef
                icons: wallpaperLoader.iconsRef
            }
        }
    }

    Item {
        id: settingsWrapper
        anchors.fill: parent
        z: 2
        property bool modeActive: modeManager.isMode("settings")
        visible: opacity > 0.01
        opacity: modeActive ? 1.0 : 0.0
        Behavior on opacity {
            enabled: settingsWrapper.opacity < 0.5
            SequentialAnimation {
                PauseAnimation { duration: 300 * settingsManager.animationDurationMultiplier }
                NumberAnimation {
                    duration: 400 * settingsManager.animationDurationMultiplier
                    easing.type: Easing.InOutCubic
                }
            }
        }
        Loader {
            id: settingsLoader
            anchors.fill: parent
            asynchronous: true
            property var modeManagerRef: modeManager
            property var themeRef: theme
            property var iconsRef: icons
            property var settingsManagerRef: settingsManager
            active: settingsWrapper.modeActive
            sourceComponent: Content.SettingsContent {
                anchors.fill: parent
                modeManager: settingsLoader.modeManagerRef
                theme: settingsLoader.themeRef
                icons: settingsLoader.iconsRef
                settingsManager: settingsLoader.settingsManagerRef
            }
        }
    }

    Item {
        id: screenshotGalleryWrapper
        anchors.fill: parent
        z: 2
        property bool modeActive: modeManager.isMode("screenshot-gallery")
        visible: opacity > 0.01
        opacity: modeActive ? 1.0 : 0.0
        Behavior on opacity {
            enabled: screenshotGalleryWrapper.opacity < 0.5
            SequentialAnimation {
                PauseAnimation { duration: 300 * settingsManager.animationDurationMultiplier }
                NumberAnimation {
                    duration: 400 * settingsManager.animationDurationMultiplier
                    easing.type: Easing.InOutCubic
                }
            }
        }
        Loader {
            id: screenshotGalleryLoader
            anchors.fill: parent
            asynchronous: true
            property var modeManagerRef: modeManager
            property var themeRef: theme
            property var screenshotManagerRef: screenshotManager
            active: screenshotGalleryWrapper.modeActive
            sourceComponent: Content.ScreenshotGalleryContent {
                anchors.fill: parent
                modeManager: screenshotGalleryLoader.modeManagerRef
                screenshotManager: screenshotGalleryLoader.screenshotManagerRef
                theme: screenshotGalleryLoader.themeRef
            }
        }
    }

    Item {
        id: clipboardWrapper
        anchors.fill: parent
        z: 2
        property bool modeActive: modeManager.isMode("clipboard")
        visible: opacity > 0.01
        opacity: modeActive ? 1.0 : 0.0
        Behavior on opacity {
            enabled: clipboardWrapper.opacity < 0.5
            SequentialAnimation {
                PauseAnimation { duration: 300 * settingsManager.animationDurationMultiplier }
                NumberAnimation {
                    duration: 400 * settingsManager.animationDurationMultiplier
                    easing.type: Easing.InOutCubic
                }
            }
        }
        Loader {
            id: clipboardLoader
            anchors.fill: parent
            asynchronous: true
            property var modeManagerRef: modeManager
            property var themeRef: theme
            property var iconsRef: icons
            property var clipboardManagerRef: clipboardManager
            active: clipboardWrapper.modeActive
            sourceComponent: Content.ClipboardContent {
                anchors.fill: parent
                modeManager: clipboardLoader.modeManagerRef
                clipboardManager: clipboardLoader.clipboardManagerRef
                theme: clipboardLoader.themeRef
                icons: clipboardLoader.iconsRef
            }
        }
    }

    // Fixed-size placement (same rationale as aiAssistantLoader above):
    // decouple content layout from the bar's growing implicitHeight.
    Content.WindowSwitcherContent {
        id: windowSwitcherContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: modeManager.scale(120)
        z: 2
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
        initTimer.start()
    }
}
