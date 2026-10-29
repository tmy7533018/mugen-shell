// Standalone Quickshell entry for the floating calendar window.

//@ pragma UseQApplication

import QtQuick
import Quickshell
import "./lib" as Theme
import "./components/content" as Content

ShellRoot {
    id: root

    Theme.Colors {
        id: themeColors
        settings: settingsManager
    }

    Theme.SettingsManager {
        id: settingsManager
    }

    FloatingWindow {
        id: calendarWindow

        visible: true
        // A compositor close only hides the window, and the toggle script reads a live process as open.
        onVisibleChanged: if (!visible) Qt.quit()
        title: "Mugen Calendar"
        color: "transparent"
        implicitWidth: 900
        implicitHeight: 560
        minimumSize: Qt.size(800, 500)

        Content.CalendarFloatingContent {
            anchors.fill: parent
            theme: themeColors
            settingsManager: settingsManager
        }
    }
}
