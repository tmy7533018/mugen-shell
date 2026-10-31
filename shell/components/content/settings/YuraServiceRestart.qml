import Quickshell.Io

Process {
    id: root

    signal result(bool ok)

    running: false
    // systemd counts a Type=simple unit as started at fork, so a config that kills mugen-ai only shows in is-active.
    command: ["sh", "-c", "systemctl --user restart mugen-ai.service && sleep 1 && systemctl --user is-active --quiet mugen-ai.service && echo ok"]
    stdout: StdioCollector {
        onStreamFinished: root.result(this.text.trim() === "ok")
    }
}
