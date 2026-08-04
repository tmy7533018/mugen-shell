import QtQuick
import Quickshell

// The backend listens on a unix socket rather than a loopback port: its API is
// unauthenticated, and 127.0.0.1 is reachable by every local user.
// MUGEN_AI_SOCKET overrides the path, which the daemon derives the same way.
QtObject {
    id: aiBackend

    readonly property string socketPath: {
        const explicit = Quickshell.env("MUGEN_AI_SOCKET")
        if (explicit && explicit.length > 0) {
            return explicit
        }
        const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR")
        return runtimeDir && runtimeDir.length > 0
            ? runtimeDir + "/mugen-ai/mugen-ai.sock"
            : ""
    }

    // The host is inert once curl is dialling a socket, but a URL still needs
    // one. Callers splice transportArgs into their argv ahead of the URL.
    readonly property string baseUrl: "http://localhost"
    readonly property var transportArgs: ["--unix-socket", socketPath]
}
