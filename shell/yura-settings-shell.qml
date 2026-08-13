//@ pragma UseQApplication

// Yura's own settings window. Split out of settings-shell because its sections
// outnumbered every other category put together.

import QtQuick
import Quickshell
import Quickshell.Io
import "./lib" as Theme
import "./components/content" as Content

ShellRoot {
    id: root

    Theme.Colors {
        id: themeColors
    }

    Theme.SettingsManager {
        id: settingsManager
    }

    QtObject {
        id: modeStub

        function scale(v) {
            return v
        }

        function isMode(name) {
            return false
        }

        function bump() {
        }
    }

    function openAiConfig() {
        let cfgHome = Quickshell.env("XDG_CONFIG_HOME")
        if (!cfgHome || cfgHome === "") cfgHome = Quickshell.env("HOME") + "/.config"
        openAiConfigProcess.command = ["xdg-open", cfgHome + "/mugen-ai/config.toml"]
        openAiConfigProcess.running = true
    }

    function restartAi() {
        restartAiProcess.command = ["systemctl", "--user", "restart", "mugen-ai.service"]
        restartAiProcess.running = true
    }

    Process {
        id: openAiConfigProcess
        command: []
        running: false
    }

    Process {
        id: restartAiProcess
        command: []
        running: false
    }

    FloatingWindow {
        id: yuraSettingsWindow

        visible: true
        title: "Yura Settings"
        color: "transparent"
        implicitWidth: 1100
        implicitHeight: 740
        minimumSize: Qt.size(800, 540)

        Content.YuraSettingsContent {
            anchors.fill: parent
            modeManager: modeStub
            theme: themeColors
            settingsManager: settingsManager

            onEditAiConfig: root.openAiConfig()
            onRestartAi: root.restartAi()
        }
    }
}
