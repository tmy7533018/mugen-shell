//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Services.Notifications as NS
import "./windows" as Windows

ShellRoot {
    id: root

    Windows.Bar {
        id: barWindow
        // Pin the bar to the first known screen. Without this the
        // wlr-layer-shell surface drifts onto whatever output is
        // currently focused, and panels opened from the bar would end
        // up on the wrong monitor when a fullscreen window was active
        // on the bar's display.
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    Connections {
        target: Quickshell

        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup()
        }

        function onReloadFailed(errorString) {
            Quickshell.inhibitReloadPopup()
        }
    }

    NS.NotificationServer {
        id: notifySrv

        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        persistenceSupported: true
    }

    Connections {
        target: notifySrv

        function onNotification(n) {
            barWindow.notificationManager.addNotification(n)
        }
    }
}
