// A separate process so its rendering can't compete with the main
// mugen-shell render thread.

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

    QtObject {
        id: modeStub

        property bool shortcutsVisible: true

        function scale(v) {
            return v
        }

        function bump() {
        }

        function closeShortcuts() {
            Qt.quit()
        }
    }

    FloatingWindow {
        id: shortcutsWindow

        visible: true
        title: "Mugen Shortcuts"
        color: "transparent"
        minimumSize: Qt.size(560, 540)

        Content.KeyboardShortcutsContent {
            anchors.fill: parent
            modeManager: modeStub
            theme: themeColors
        }
    }
}
