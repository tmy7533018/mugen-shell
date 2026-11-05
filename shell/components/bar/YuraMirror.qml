import QtQuick
import Quickshell.Io

Item {
    id: root

    required property bool barHidden
    required property var modeManagerRef
    required property var orbHost

    // Float Yura mirrors its state here over IPC, so auto-close waits for its stream too.
    property bool yuraFloatThinking: false
    property bool yuraPanelOpen: false

    IpcHandler {
        target: "yura"
        function set_thinking(on: bool): void {
            root.yuraFloatThinking = on
            if (on) yuraThinkingFailsafe.restart()
            else yuraThinkingFailsafe.stop()
        }
        function set_panel_open(on: bool): void {
            root.yuraPanelOpen = on
            if (on) yuraPanelFailsafe.restart()
            else yuraPanelFailsafe.stop()
        }
        function orb_home(): string {
            if (root.barHidden || !root.modeManagerRef.isMode("normal")) return ""
            if (!root.orbHost || !root.orbHost.available) return ""
            const r = root.orbHost.screenRect()
            return Math.round(r.x) + " " + Math.round(r.y) + " " + Math.round(r.size)
        }
    }

    // If yura-shell dies mid-stream its clearing IPC never arrives, so the icon would glow forever.
    Timer {
        id: yuraThinkingFailsafe
        interval: 15 * 60 * 1000
        onTriggered: root.yuraFloatThinking = false
    }

    Timer {
        id: yuraPanelFailsafe
        interval: 30 * 60 * 1000
        onTriggered: root.yuraPanelOpen = false
    }
}
