//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications as NS
import "./windows" as Windows
import "./lib" as Lib

ShellRoot {
    id: root

    Windows.Bar {
        id: barWindow
        // screen is resolved inside Bar.qml (settings.display.monitor), not
        // here — it needs SettingsManager, which lives inside the bar window.
    }

    GlobalShortcut {
        appid: "mugen-shell"
        name: "ptt"
        description: "Hold to talk to Yura"

        onPressed: Lib.YuraCtl.pttDown(!barWindow.yuraSurfaceOpen)
        onReleased: Lib.YuraCtl.pttUp()
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
