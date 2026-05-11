import QtQuick
import Quickshell
import Quickshell.Io

// External tool entry point for the MCP layer in mugen-ai. Each target maps
// 1:1 to a tool group exposed to the LLM. Keep handlers thin — defer to the
// underlying manager rather than reimplementing logic here.
Item {
    id: ipcRouter

    required property var audioManager
    required property var musicPlayerManager
    required property var modeManager

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

    IpcHandler {
        target: "panel"

        function open(name: string): void {
            ipcRouter.modeManager.switchMode(name, true)
        }

        function close(): void {
            ipcRouter.modeManager.closeAllModes()
        }
    }
}
