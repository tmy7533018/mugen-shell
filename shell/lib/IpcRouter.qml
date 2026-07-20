import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "." as Lib

// Entry point for the MCP layer in mugen-ai: each target maps 1:1 to a tool
// group exposed to the LLM. Handlers must stay thin and defer to the
// underlying manager rather than reimplement its logic.
Item {
    id: ipcRouter

    required property var audioManager
    required property var musicPlayerManager
    required property var modeManager
    required property var brightnessManager
    required property var wallpaperManager
    required property var notificationManager
    required property var theme
    required property var timerManager

    IpcHandler {
        target: "audio"

        function set_volume(vol: int): int {
            // Returns the request, not a re-read: pavucontrol updates the
            // property asynchronously, so a post-set read races and surfaces
            // the previous level.
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

        function now_playing(): string {
            let m = ipcRouter.musicPlayerManager
            if (!m.isAvailable) return JSON.stringify({ available: false })
            return JSON.stringify({
                available: true,
                status: m.status,
                title: m.title,
                artist: m.artist,
                player: m.activePlayer
            })
        }
    }

    IpcHandler {
        target: "window"

        function active(): string {
            let t = ToplevelManager.activeToplevel
            if (!t) return JSON.stringify({})
            return JSON.stringify({ app_id: t.appId, title: t.title })
        }
    }

    // These run as separate quickshell processes, so switchMode would only
    // empty the bar; their toggle scripts are what make a window appear.
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
                Lib.Hypr.exec("~/.config/quickshell/mugen-shell/scripts/" + script)
                return
            }
            ipcRouter.modeManager.switchMode(name, true)
        }

        function close(): void {
            // Only affects the bar's inline modes; detached panels close via
            // their own toggle.
            ipcRouter.modeManager.closeAllModes()
        }

        function current(): string {
            return ipcRouter.modeManager.currentMode
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
            // Models invent paths, so anything outside the wallpaper dir is
            // rejected. Membership in the enumerated list is deliberately NOT
            // required: it refreshes only on startup/picker-open, so a
            // just-added file would be rejected spuriously.
            const known = ipcRouter.wallpaperManager.wallpapers || []
            if (known.indexOf(path) === -1) {
                const dir = ipcRouter.wallpaperManager.wallpaperDir + "/"
                if (!path.startsWith(dir) || path.includes(".."))
                    return "error: unknown wallpaper path; use one returned by wallpaper list"
                ipcRouter.wallpaperManager.loadWallpapers()
            }
            ipcRouter.wallpaperManager.setWallpaper(path)
            return path
        }

        function current(): string {
            return ipcRouter.wallpaperManager.currentWallpaperPath
        }

        function random(): string {
            const known = ipcRouter.wallpaperManager.wallpapers || []
            if (known.length === 0)
                return "error: no wallpapers found"
            // Skip the current one so "random" always visibly changes.
            const current = ipcRouter.wallpaperManager.currentWallpaperPath
            let pick = known[Math.floor(Math.random() * known.length)]
            if (known.length > 1 && pick === current)
                pick = known[(known.indexOf(pick) + 1) % known.length]
            ipcRouter.wallpaperManager.setWallpaper(pick)
            return pick
        }

        function list(): string {
            return JSON.stringify(ipcRouter.wallpaperManager.wallpapers || [])
        }
    }

    IpcHandler {
        target: "app"

        function launch(cmd: string): string {
            let trimmed = (cmd || "").trim()
            if (trimmed === "") return "error: empty command"
            // Exec inherits the user's $PATH, so bare names need no resolving.
            Lib.Hypr.exec(trimmed)
            return "launched: " + trimmed
        }
    }

    IpcHandler {
        target: "timer"

        function start(seconds: int): string {
            if (seconds <= 0) return "error: seconds must be positive"
            ipcRouter.timerManager.start(seconds)
            return "started: " + seconds + "s"
        }

        function pause(): string {
            if (!ipcRouter.timerManager.running) return "error: no timer running"
            ipcRouter.timerManager.pause()
            return "paused"
        }

        function resume(): string {
            if (!ipcRouter.timerManager.paused) return "error: timer is not paused"
            ipcRouter.timerManager.resume()
            return "resumed"
        }

        function cancel(): string {
            if (!ipcRouter.timerManager.running && !ipcRouter.timerManager.paused) {
                return "error: no timer to cancel"
            }
            ipcRouter.timerManager.cancel()
            return "cancelled"
        }

        function dismiss(): string {
            if (!ipcRouter.timerManager.alerting) {
                return "error: timer is not ringing"
            }
            ipcRouter.timerManager.dismissAlert()
            return "dismissed"
        }

        function get(): string {
            return JSON.stringify({
                running: ipcRouter.timerManager.running,
                paused: ipcRouter.timerManager.paused,
                duration_sec: ipcRouter.timerManager.durationSec,
                remaining_sec: ipcRouter.timerManager.remainingSec,
                alerting: ipcRouter.timerManager.alerting
            })
        }
    }

    IpcHandler {
        target: "notification"

        function toggle_dnd(): bool {
            // Inverted polarity: DnD on = notificationsEnabled false.
            ipcRouter.notificationManager.notificationsEnabled = !ipcRouter.notificationManager.notificationsEnabled
            return !ipcRouter.notificationManager.notificationsEnabled
        }

        function set_dnd(enabled: bool): bool {
            // Idempotent, unlike toggle_dnd, so "turn DnD on" can't flip an
            // already-on state back off.
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
