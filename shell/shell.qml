//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Services.Notifications as NS
import "./windows" as Windows

ShellRoot {
    id: root

    Windows.Bar {
        id: barWindow
        // Unpinned, the layer-shell surface drifts onto whatever output is
        // focused, so bar panels open on the wrong monitor.
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
