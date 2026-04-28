//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Services.Notifications as NS
import "./windows" as Windows

ShellRoot {
    id: root

    Windows.Bar {
        id: barWindow
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
