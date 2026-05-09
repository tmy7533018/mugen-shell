// Standalone Quickshell entry for the floating AI assistant window.
//
// Run with:
//   quickshell -p $HOME/.config/quickshell/mugen-shell/ai-shell.qml -d

//@ pragma UseQApplication

import QtQuick
import Quickshell
import "./lib" as Theme
import "./components/content" as Content

ShellRoot {
    id: root

    Theme.Colors {
        id: themeColors
    }

    Theme.IconProvider {
        id: icons
    }

    Theme.AiBackend {
        id: aiBackend
    }

    QtObject {
        id: modeStub

        property string currentMode: "ai"

        function scale(v) { return v }
        function bump() {}
        function isMode(name) { return name === "ai" }
        function closeAllModes() { Qt.quit() }
        function registerMode(name, instance) {}
    }

    FloatingWindow {
        id: aiWindow

        visible: true
        title: "Yura"
        color: "transparent"
        width: 720
        height: 540
        minimumSize: Qt.size(640, 480)

        Item {
            anchors.fill: parent
            focus: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    Qt.quit()
                    event.accepted = true
                }
            }

            Content.AiAssistantFloatingContent {
                anchors.fill: parent
                modeManager: modeStub
                theme: themeColors
                icons: icons
                aiBackend: aiBackend
            }
        }
    }
}
