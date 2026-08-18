import QtQuick
import Quickshell

// The backend listens on a unix socket, not a loopback port: its API is unauthenticated
// and 127.0.0.1 is reachable by every local user. MUGEN_AI_SOCKET overrides the path.
QtObject {
    id: aiBackend

    readonly property string socketPath: {
        const explicit = Quickshell.env("MUGEN_AI_SOCKET")
        if (explicit && explicit.length > 0) {
            return explicit
        }
        return Paths.runtimeDir === "" ? "" : Paths.runtimeDir + "/mugen-ai/mugen-ai.sock"
    }

    // The host is inert once curl dials a socket; callers splice transportArgs in ahead of the URL.
    readonly property string baseUrl: "http://localhost"
    readonly property var transportArgs: ["--unix-socket", socketPath]
}
