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
    }
}
