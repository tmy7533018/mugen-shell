//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import "./lib" as Theme
import "./components/yura" as Yura

ShellRoot {
    id: root

    Theme.Colors { id: themeColors }
    Theme.IconProvider { id: icons }
    Theme.AiBackend { id: aiBackend }
    Theme.SettingsManager { id: settingsManager }

    Theme.YuraState {
        id: yuraState
        panelSide: settingsManager.yuraPanelSide
        panelWidth: settingsManager.yuraPanelWidth
        panelHeight: settingsManager.yuraPanelHeight
    }

    Yura.YuraChatPanel {
        id: chatPanel
        yuraState: yuraState
        theme: themeColors
        icons: icons
        aiBackend: aiBackend
        settingsManager: settingsManager
    }

    IpcHandler {
        target: "yura"
        function toggle() { yuraState.toggle() }
        function open()   { yuraState.open() }
        function close()  { yuraState.close() }
        // Called by the bar spotlight orb with its screen position, so the
        // panel orb can fly in from there ("one orb" illusion).
        function toggleFrom(x: int, y: int, size: int) { yuraState.toggleFrom(x, y, size) }
        // Voice daemon: land the panel on the voice conversation.
        function show_conversation(id: int) { chatPanel.showConversation(id) }
        // Voice daemon capture state; flips the mic button into a cancel button.
        function set_listening(on: bool) { chatPanel.setVoiceListening(on) }
        // TTS playback state; the same button becomes a stop control.
        function set_speaking(on: bool) { chatPanel.setVoiceSpeaking(on) }
    }
}
