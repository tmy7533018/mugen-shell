pragma ComponentBehavior: Bound

import QtQuick
import "../content" as Content

Item {
    id: root

    required property var aiBackendRef
    required property var audioManagerRef
    required property var bluetoothManagerRef
    required property var brightnessManagerRef
    required property var cavaManagerRef
    required property var clipboardManagerRef
    required property var iconsRef
    required property var micCavaManagerRef
    required property var modeManagerRef
    required property var musicPlayerManagerRef
    required property var notificationManagerRef
    required property var screenshotManagerRef
    required property var settingsManagerRef
    required property var themeRef
    required property var timerManagerRef
    required property var typoRef
    required property var wallpaperManagerRef
    required property var weatherManagerRef
    required property var wifiManagerRef

    readonly property var aiItem: aiAssistantLoader.item
    readonly property var launcherItem: appLauncherLoader.item
    readonly property var wifiItem: wifiLoader.item

    Loader {
        id: powerMenuLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: root.modeManagerRef
        property var iconsRef: root.iconsRef
        property var themeRef: root.themeRef
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
        property var modeManagerRef: root.modeManagerRef
        property var themeRef: root.themeRef
        property var timerManagerRef: root.timerManagerRef
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
        property var modeManagerRef: root.modeManagerRef
        property var themeRef: root.themeRef
        property var iconsRef: root.iconsRef
        property var musicManagerRef: root.musicPlayerManagerRef
        property var cavaManagerRef: root.cavaManagerRef
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

        property var modeManagerRef: root.modeManagerRef
        property var themeRef: root.themeRef
        property var iconsRef: root.iconsRef
        property var settingsManagerRef: root.settingsManagerRef
        property var aiBackendRef: root.aiBackendRef

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
        }
    }

    Loader {
        id: appLauncherLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: root.modeManagerRef
        property var themeRef: root.themeRef
        property var iconsRef: root.iconsRef
        property var typoRef: root.typoRef
        property var settingsManagerRef: root.settingsManagerRef
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
        property var modeManagerRef: root.modeManagerRef
        property var themeRef: root.themeRef
        property var typoRef: root.typoRef
        property var audioManagerRef: root.audioManagerRef
        property var cavaManagerRef: root.cavaManagerRef
        property var micCavaManagerRef: root.micCavaManagerRef
        property var musicPlayerManagerRef: root.musicPlayerManagerRef
        property var settingsManagerRef: root.settingsManagerRef
        active: modeManagerRef.isMode("volume")
        sourceComponent: Content.VolumeContent {
            anchors.fill: parent
            visible: volumeLoader.modeManagerRef.isMode("volume")
            modeManager: volumeLoader.modeManagerRef
            audioManager: volumeLoader.audioManagerRef
            cavaManager: volumeLoader.cavaManagerRef
            micCavaManager: volumeLoader.micCavaManagerRef
            musicPlayerManager: volumeLoader.musicPlayerManagerRef
            settingsManager: volumeLoader.settingsManagerRef
            theme: volumeLoader.themeRef
            typo: volumeLoader.typoRef
        }
    }

    Loader {
        id: brightnessLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: root.modeManagerRef
        property var themeRef: root.themeRef
        property var typoRef: root.typoRef
        property var brightnessManagerRef: root.brightnessManagerRef
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
        property var modeManagerRef: root.modeManagerRef
        property var themeRef: root.themeRef
        property var iconsRef: root.iconsRef
        property var notificationManagerRef: root.notificationManagerRef
        property var settingsManagerRef: root.settingsManagerRef
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
        property var modeManagerRef: root.modeManagerRef
        property var themeRef: root.themeRef
        property var iconsRef: root.iconsRef
        property var wifiManagerRef: root.wifiManagerRef
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
        property var modeManagerRef: root.modeManagerRef
        property var themeRef: root.themeRef
        property var iconsRef: root.iconsRef
        property var bluetoothManagerRef: root.bluetoothManagerRef
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
        property var modeManagerRef: root.modeManagerRef
        property var themeRef: root.themeRef
        property var iconsRef: root.iconsRef
        property var weatherManagerRef: root.weatherManagerRef
        property var settingsManagerRef: root.settingsManagerRef
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
        property var modeManagerRef: root.modeManagerRef
        property var themeRef: root.themeRef
        property var iconsRef: root.iconsRef
        property var wallpaperManagerRef: root.wallpaperManagerRef
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
        property var modeManagerRef: root.modeManagerRef
        property var themeRef: root.themeRef
        property var screenshotManagerRef: root.screenshotManagerRef
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
        id: screenshotMenuLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: root.modeManagerRef
        property var themeRef: root.themeRef
        property var screenshotManagerRef: root.screenshotManagerRef
        property var iconsRef: root.iconsRef
        active: modeManagerRef.isMode("screenshot-menu")
        sourceComponent: Content.ScreenshotMenuContent {
            anchors.fill: parent
            visible: screenshotMenuLoader.modeManagerRef.isMode("screenshot-menu")
            modeManager: screenshotMenuLoader.modeManagerRef
            screenshotManager: screenshotMenuLoader.screenshotManagerRef
            icons: screenshotMenuLoader.iconsRef
            theme: screenshotMenuLoader.themeRef
        }
    }

    Loader {
        id: clipboardLoader
        anchors.fill: parent
        z: 2
        property var modeManagerRef: root.modeManagerRef
        property var themeRef: root.themeRef
        property var iconsRef: root.iconsRef
        property var clipboardManagerRef: root.clipboardManagerRef
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
}
