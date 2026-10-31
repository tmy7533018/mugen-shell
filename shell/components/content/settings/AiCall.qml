import Quickshell.Io

Process {
    id: root

    required property var backend
    property string path: ""
    property string method: "GET"
    property string maxTime: "3"
    property string buf: ""

    running: false
    command: ["curl", ...root.backend.transportArgs, "-fsS", "--max-time", root.maxTime]
        .concat(root.method === "GET" ? [] : ["-X", root.method])
        .concat([root.backend.baseUrl + root.path])
    stdout: SplitParser { onRead: data => root.buf += data }
    onRunningChanged: { if (running) buf = "" }
}
