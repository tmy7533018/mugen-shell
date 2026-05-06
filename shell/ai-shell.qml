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
        title: "Mugen AI"
        color: "transparent"
        width: 720
        height: 540
        minimumSize: Qt.size(640, 480)

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.04, 0.03, 0.08, 0.92)

            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    Qt.quit()
                    event.accepted = true
                }
            }

            Content.AiAssistantContent {
                anchors.fill: parent
                modeManager: modeStub
                theme: themeColors
                icons: icons
                isStandalone: true
            }
        }
    }
}
