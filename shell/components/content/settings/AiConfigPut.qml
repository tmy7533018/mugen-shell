import Quickshell.Io

Process {
    id: root

    required property var backend
    property string buf: ""
    property string payload: ""

    signal savedOk()
    signal saveFailed()

    running: false
    stdinEnabled: true
    command: ["curl", ...root.backend.transportArgs, "-fsS", "--max-time", "5",
              "-X", "PUT", root.backend.baseUrl + "/config",
              "-H", "Content-Type: application/json",
              "--data-binary", "@-"]
    // argv is world-readable through /proc and the config carries secrets, so the body goes over stdin.
    onStarted: {
        root.write(root.payload)
        root.stdinEnabled = false
    }
    stdout: SplitParser { onRead: data => root.buf += data }
    onRunningChanged: { if (running) buf = "" }
    onExited: (exitCode) => {
        // The onStarted assignment severs the binding, so re-arm or the next save never closes stdin.
        root.stdinEnabled = true
        if (exitCode === 0 && root.buf.indexOf("saved") >= 0)
            root.savedOk()
        else
            root.saveFailed()
    }
}
