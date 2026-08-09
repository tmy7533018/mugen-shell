pragma Singleton
import QtQuick
import Quickshell

// The voice daemon's control socket, used instead of signalling the unit — signals
// carry no arguments and report nothing back.
QtObject {
    readonly property string socket: Paths.yuraCtlSocket
    readonly property bool available: socket !== ""

    // Fire-and-forget; callers needing the daemon's answer run their own Process against `socket`.
    function post(path, payload) {
        if (!available) return
        let args = ["curl", "-sS", "--max-time", "5",
                    "--unix-socket", socket, "-X", "POST"]
        if (payload !== undefined) {
            args.push("-H", "Content-Type: application/json",
                      "--data-binary", JSON.stringify(payload))
        }
        args.push("http://localhost" + path)
        Quickshell.execDetached(args)
    }

    function pttDown(fresh) {
        post("/ptt/start", { fresh: fresh === true })
    }

    function pttUp() {
        post("/ptt/stop")
    }

    // What the mic button does depends on what the daemon is already doing.
    function micPressed(voiceActive, conversationId) {
        if (voiceActive) post("/cancel")
        else post("/turn", { fresh: conversationId === 0 })
    }
}
