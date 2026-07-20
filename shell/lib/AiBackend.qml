import QtQuick
import Quickshell

// MUGEN_AI_HOST / MUGEN_AI_PORT are honoured so the systemd unit's
// EnvironmentFile keeps the backend's --port and this client in sync.
QtObject {
    id: aiBackend

    readonly property string host: {
        const v = Quickshell.env("MUGEN_AI_HOST")
        return (v && v.length > 0) ? v : "127.0.0.1"
    }
    readonly property int port: {
        const v = Quickshell.env("MUGEN_AI_PORT")
        const n = parseInt(v, 10)
        return (isFinite(n) && n > 0) ? n : 11435
    }
    readonly property string baseUrl: "http://" + host + ":" + port
}
