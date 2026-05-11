import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// External tool entry point for the MCP layer in mugen-ai. Each target maps
// 1:1 to a tool group exposed to the LLM. Keep handlers thin — defer to the
// underlying manager rather than reimplementing logic here.
Item {
    id: ipcRouter

    required property var audioManager
    required property var musicPlayerManager
    required property var modeManager
    required property var brightnessManager
    required property var wallpaperManager
    required property var notificationManager
    required property var theme

    IpcHandler {
        target: "audio"

        function set_volume(vol: int): int {
            // Return the requested value rather than re-reading; pavucontrol
            // updates the property asynchronously so the post-set read would
            // race and surface the previous level.
            ipcRouter.audioManager.setVolume(vol)
            return vol
        }

        function get_volume(): int {
            return ipcRouter.audioManager.volume
        }

        function toggle_mute(): bool {
            ipcRouter.audioManager.toggleMute()
            return ipcRouter.audioManager.isMuted
        }

        function set_mic_volume(vol: int): string {
            if (!ipcRouter.audioManager.micAvailable) {
                return "error: microphone not available"
            }
            // Same async-race story as set_volume — return the request.
            ipcRouter.audioManager.setMicVolume(vol)
            return String(vol)
        }

        function get_mic_volume(): string {
            if (!ipcRouter.audioManager.micAvailable) {
                return "error: microphone not available"
            }
            return String(ipcRouter.audioManager.micVolume)
        }

        function toggle_mic_mute(): string {
            if (!ipcRouter.audioManager.micAvailable) {
                return "error: microphone not available"
            }
            ipcRouter.audioManager.toggleMicMute()
            return String(ipcRouter.audioManager.micMuted)
        }
    }

    IpcHandler {
        target: "music"

        function toggle(): void {
            ipcRouter.musicPlayerManager.playPause()
        }

        function next(): void {
            ipcRouter.musicPlayerManager.next()
        }

        function previous(): void {
            ipcRouter.musicPlayerManager.previous()
        }
    }

    // settings / calendar / shortcuts run as separate quickshell processes —
    // switchMode would just empty the bar. Route those through their toggle
    // scripts so the actual window appears.
    readonly property var _detachedScripts: ({
        "settings": "toggle-settings.sh",
        "calendar": "toggle-calendar.sh",
        "shortcuts": "toggle-shortcuts.sh"
    })

    IpcHandler {
        target: "panel"

        function open(name: string): void {
            let script = ipcRouter._detachedScripts[name]
            if (script) {
                Hyprland.dispatch("exec ~/.config/quickshell/mugen-shell/scripts/" + script)
                return
            }
            ipcRouter.modeManager.switchMode(name, true)
        }

        function close(): void {
            // Only affects the bar's inline modes; detached panels close
            // via their own toggle (call open() again or press ESC in them).
            ipcRouter.modeManager.closeAllModes()
        }
    }

    IpcHandler {
        target: "brightness"

        function set(percent: int): string {
            if (!ipcRouter.brightnessManager.isAvailable) {
                return "error: brightness control not available on this machine"
            }
            ipcRouter.brightnessManager.setBrightness(percent)
            return String(percent)
        }

        function get(): string {
            if (!ipcRouter.brightnessManager.isAvailable) {
                return "error: brightness control not available on this machine"
            }
            return String(ipcRouter.brightnessManager.brightness)
        }
    }

    IpcHandler {
        target: "theme"

        function set(mode: string): string {
            // Accept "dark" or "light"; ignore anything else so a stray
            // call can't put the shell in an invalid state.
            if (mode !== "dark" && mode !== "light") return ipcRouter.theme.themeMode
            ipcRouter.theme.themeMode = mode
            ipcRouter.theme.saveThemeMode()
            return mode
        }

        function toggle(): string {
            ipcRouter.theme.toggleThemeMode()
            return ipcRouter.theme.themeMode
        }

        function get(): string {
            return ipcRouter.theme.themeMode
        }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): string {
            ipcRouter.wallpaperManager.setWallpaper(path)
            return path
        }

        function current(): string {
            return ipcRouter.wallpaperManager.currentWallpaperPath
        }

        function list(): string {
            return JSON.stringify(ipcRouter.wallpaperManager.wallpapers || [])
        }
    }

    IpcHandler {
        target: "notification"

        function toggle_dnd(): bool {
            // "DnD on" = notifications suppressed = notificationsEnabled false.
            // Flip and return the new DnD state so the LLM gets a clean bool.
            ipcRouter.notificationManager.notificationsEnabled = !ipcRouter.notificationManager.notificationsEnabled
            return !ipcRouter.notificationManager.notificationsEnabled
        }

        function set_dnd(enabled: bool): bool {
            // Idempotent setter so "turn DnD on" doesn't accidentally flip
            // an already-on state back off via toggle_dnd.
            ipcRouter.notificationManager.notificationsEnabled = !enabled
            return enabled
        }

        function get_dnd(): bool {
            return !ipcRouter.notificationManager.notificationsEnabled
        }

        function clear_all(): int {
            let n = (ipcRouter.notificationManager.notifications || []).length
            ipcRouter.notificationManager.clearAll()
            return n
        }

        function unread(): int {
            return ipcRouter.notificationManager.unreadCount
        }
    }
}
