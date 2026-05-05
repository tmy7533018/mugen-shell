// Standalone Quickshell entry for the floating calendar window.
//
// Run with:
//   quickshell -p $HOME/.config/quickshell/mugen-shell/calendar-shell.qml -d

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

        function scale(v) {
            return v
        }

        function bump() {
        }

        function quitApp() {
            Qt.quit()
        }
    }

    FloatingWindow {
        id: calendarWindow

        visible: true
        title: "Mugen Calendar"
        color: "transparent"
        width: 900
        height: 560
        minimumSize: Qt.size(800, 500)

        Content.CalendarFloatingContent {
            anchors.fill: parent
            modeManager: modeStub
            theme: themeColors
        }
    }
}
