import QtQuick
import Quickshell

QtObject {
    id: iconProvider

    property bool useImeIcons: false
    property bool useVolumeIcons: true
    property bool useMusicIcons: true
    property bool usePowerIcons: true

    readonly property string basePath: Quickshell.shellDir + "/assets/icons"

    readonly property string circleSvg: basePath + "/circle.svg"
    readonly property string starSvg: basePath + "/circle.svg"
    readonly property string lockSvg: basePath + "/lock.svg"
    readonly property string logoutSvg: basePath + "/logout.svg"
    readonly property string sleepSvg: basePath + "/sleep.svg"
    readonly property string rebootSvg: basePath + "/reboot.svg"
    readonly property string shutdownSvg: basePath + "/power-shutdown.svg"

    readonly property string volumeMutedSvg: basePath + "/volume-mute.svg"
    readonly property string volumeDownSvg: basePath + "/volume-down.svg"
    readonly property string volumeUpSvg: basePath + "/volume-up.svg"
    readonly property string headphonesSvg: basePath + "/headphones.svg"

    readonly property string musicSvg: basePath + "/music.svg"
    readonly property string playSvg: basePath + "/play.svg"
    readonly property string pauseSvg: basePath + "/pause.svg"
    readonly property string trackPreviousSvg: basePath + "/track-previous.svg"
    readonly property string trackNextSvg: basePath + "/track-next.svg"

    readonly property string bellPng: basePath + "/bell.png"
    readonly property string bellOffPng: basePath + "/bell-off.png"
    readonly property string bellActivePng: basePath + "/bell-active.png"
    readonly property string notificationSvg: basePath + "/notification.svg"
    readonly property string notificationOffSvg: basePath + "/notification-off.svg"

    readonly property string wifiSvg: basePath + "/wifi.svg"
    readonly property string wifiOffSvg: basePath + "/wifi-off.svg"

    readonly property string bluetoothSvg: basePath + "/bluetooth.svg"
    readonly property string bluetoothSlashSvg: basePath + "/bluetooth-slash.svg"
    readonly property string bluetoothSearchingSvg: basePath + "/bluetooth-searching.svg"
    readonly property string bluetoothConnectedSvg: basePath + "/bluetooth-connected.svg"

    readonly property string wallpaperSvg: basePath + "/wallpaper.svg"

    readonly property string clipboardSvg: basePath + "/clipboard.svg"

    readonly property string aiSvg: basePath + "/ai.svg"
    readonly property string trashSvg: basePath + "/trash.svg"

    readonly property string appLauncherSvg: basePath + "/app-launcher.svg"
    readonly property string clockSvg: basePath + "/clock.svg"
    readonly property string searchSvg: basePath + "/search.svg"
    readonly property string arrowDownwardSvg: basePath + "/arrow-downward-fill.svg"
    readonly property string chevronDownSvg: basePath + "/chevron-down.svg"
    readonly property string refreshOutlineSvg: basePath + "/refresh-outline.svg"

    readonly property var iconData: QtObject {
        property var menu: ({ type: usePowerIcons ? "svg" : "text", value: usePowerIcons ? starSvg : "⚡" })
        property var lock: ({ type: usePowerIcons ? "svg" : "text", value: usePowerIcons ? lockSvg : "🔒" })
        property var logout: ({ type: usePowerIcons ? "svg" : "text", value: usePowerIcons ? logoutSvg : "🚪" })
        property var sleep: ({ type: usePowerIcons ? "svg" : "text", value: usePowerIcons ? sleepSvg : "😴" })
        property var reboot: ({ type: usePowerIcons ? "svg" : "text", value: usePowerIcons ? rebootSvg : "🔄" })
        property var shutdown: ({ type: usePowerIcons ? "svg" : "text", value: usePowerIcons ? shutdownSvg : "⭕" })

        property var launcher: ({ type: "svg", value: appLauncherSvg })
        property var calendar: ({ type: "text", value: "📅" })
        property var music: ({ type: useMusicIcons ? "svg" : "text", value: useMusicIcons ? musicSvg : "🎵" })
        property var search: ({ type: "svg", value: searchSvg })
        property var notification: ({ type: "svg", value: notificationSvg })
        property var wallpaper: ({ type: "svg", value: wallpaperSvg })
        property var clipboard: ({ type: "svg", value: clipboardSvg })
        property var ai: ({ type: "svg", value: aiSvg })
        property var eyeOpen: ({ type: "svg", value: basePath + "/eye-open.svg" })
        property var eyeClosed: ({ type: "svg", value: basePath + "/eye-closed.svg" })
        property var screenshot: ({ type: "svg", value: basePath + "/screenshot.svg" })
    }

    function getVolumeIcon(volume, isMuted, isHeadphone) {
        if (isHeadphone && useVolumeIcons) {
            return { type: "svg", value: headphonesSvg }
        } else if (isHeadphone && !useVolumeIcons) {
            return { type: "text", value: "🎧" }
        }
        
        if (useVolumeIcons) {
            if (volume === 0 || isMuted) {
                return { type: "svg", value: volumeMutedSvg }
            } else if (volume < 50) {
                return { type: "svg", value: volumeDownSvg }
            } else {
                return { type: "svg", value: volumeUpSvg }
            }
        } else {
            if (volume === 0 || isMuted) {
                return { type: "text", value: "🔇" }
            } else if (volume < 50) {
                return { type: "text", value: "🔉" }
            } else {
                return { type: "text", value: "🔊" }
            }
        }
    }

    function getImeIcon(imeState) {
        if (useImeIcons) {
            if (imeState.includes("あ") || imeState.includes("mozc") || imeState.includes("Mozc")) {
                return { type: "svg", value: imeMozcSvg }
            } else if (imeState.includes("JP") || imeState.includes("jp")) {
                return { type: "svg", value: imeJpSvg }
            } else {
                return { type: "svg", value: imeUsSvg }
            }
        } else {
            return { type: "text", value: imeState }
        }
    }

    function getPlayPauseIcon(isPlaying) {
        if (useMusicIcons) {
            return { type: "svg", value: isPlaying ? pauseSvg : playSvg }
        } else {
            return { type: "text", value: isPlaying ? "⏸" : "▶" }
        }
    }

    function getPreviousIcon() {
        return useMusicIcons
            ? { type: "svg", value: trackPreviousSvg }
            : { type: "text", value: "⏮" }
    }

    function getNextIcon() {
        return useMusicIcons
            ? { type: "svg", value: trackNextSvg }
            : { type: "text", value: "⏭" }
    }

    function getBluetoothIcon(isPowered, isScanning, hasConnectedDevices) {
        if (!isPowered) {
            return { type: "svg", value: bluetoothSlashSvg }
        } else if (isScanning) {
            return { type: "svg", value: bluetoothSearchingSvg }
        } else if (hasConnectedDevices) {
            return { type: "svg", value: bluetoothConnectedSvg }
        } else {
            return { type: "svg", value: bluetoothSvg }
        }
    }

    function getCustomIcon(iconName) {
        return basePath + "/" + iconName + ".svg"
    }

    Component.onCompleted: {
    }
}
