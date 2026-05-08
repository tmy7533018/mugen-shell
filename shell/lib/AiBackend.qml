import QtQuick
import Quickshell

// Single source of truth for the mugen-ai backend address. Both the bar AI,
// the floating AI, and Settings → Bar AI model use baseUrl + path so that
// changing the port (via the MUGEN_AI_PORT env var, or by editing the
// defaults below) only happens in one place.
//
// The systemd unit can set MUGEN_AI_PORT in EnvironmentFile to keep the
// backend's --port flag and the shell client in sync without code edits.
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
