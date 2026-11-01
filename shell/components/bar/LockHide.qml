import QtQuick
import Quickshell.Io
import "../../lib" as Theme

Item {
    id: root

    required property var modeManagerRef

    property bool lockHidden: false
    property real lockOpacity: 1.0
    property int lockClientPid: 0

    function showAfterLock() {
        if (!lockHidden) return
        lockFadeOut.stop()
        lockClientPid = 0
        lockHidden = false
        lockFadeIn.start()
    }

    function hide(pid: int): void {
        root.lockClientPid = pid
        if (!root.lockHidden) {
            root.lockHidden = true
            lockFadeIn.stop()
            lockFadeOut.start()
        }
    }

    NumberAnimation {
        id: lockFadeOut
        target: root
        property: "lockOpacity"
        to: 0
        duration: Theme.Motion.micro
        easing.type: Easing.OutCubic
        onFinished: root.modeManagerRef.closeAllModes()
    }

    NumberAnimation {
        id: lockFadeIn
        target: root
        property: "lockOpacity"
        to: 1
        duration: Theme.Motion.standard
        easing.type: Easing.OutCubic
    }

    Timer {
        id: lockAliveCheck
        interval: 60000
        repeat: true
        running: root.lockHidden && root.lockClientPid > 0
        onTriggered: lockProbe.running = true
    }

    Process {
        id: lockProbe
        running: false
        // The verdict is on stdout because qmllint rejects any onExited handler.
        command: ["sh", "-c",
                  "kill -0 \"$1\" 2>/dev/null && echo alive || echo dead",
                  "sh", String(root.lockClientPid)]

        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "alive") root.showAfterLock()
            }
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        running: root.lockHidden && root.lockClientPid <= 0
        onTriggered: root.showAfterLock()
    }
}
