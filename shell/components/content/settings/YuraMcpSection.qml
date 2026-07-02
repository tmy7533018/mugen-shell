import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager

    Theme.AiBackend { id: aiBackend }

    width: parent ? parent.width : 420
    height: section.isExpanded ? expandedHeight : 64
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)
    clip: true

    property bool isExpanded: false
    property bool loaded: false
    property bool saving: false
    property string statusText: ""

    // servers: editable definitions from config — [{name, command, args[], env{}, disabled}].
    // statusByName: live runtime status from /mcp/servers, keyed by name.
    property var servers: []
    property var statusByName: ({})
    property bool dirty: false

    // Add-server form state.
    property bool addingServer: false
    property string formName: ""
    property string formCommand: ""
    property string formEnv: ""

    readonly property int expandedHeight: 64 + contentColumn.implicitHeight + 16

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function summary() {
        if (!loaded) return "loading…"
        if (servers.length === 0) return dirty ? "0 servers · unsaved" : "none configured"
        let connected = 0
        for (let i = 0; i < servers.length; i++) {
            let st = statusByName[servers[i].name]
            if (st && st.connected) connected++
        }
        return connected + " / " + servers.length + " connected" + (dirty ? " · unsaved" : "")
    }

    function removeServer(name) {
        let next = []
        for (let i = 0; i < servers.length; i++) {
            if (servers[i].name !== name) next.push(servers[i])
        }
        section.servers = next
        section.dirty = true
        section.statusText = "removed — Save & Apply to confirm"
    }

    // patchServer rebuilds the list with one field of one server changed,
    // preserving every other field so a toggle never drops sibling state.
    function patchServer(name, key, value) {
        let next = []
        for (let i = 0; i < servers.length; i++) {
            let s = servers[i]
            if (s.name === name) {
                let copy = {
                    name: s.name, command: s.command, args: s.args,
                    env: s.env, disabled: s.disabled, trusted: s.trusted
                }
                copy[key] = value
                next.push(copy)
            } else {
                next.push(s)
            }
        }
        section.servers = next
        section.dirty = true
    }

    function setDisabled(name, off) { patchServer(name, "disabled", off) }

    function setTrusted(name, on) { patchServer(name, "trusted", on) }

    function parseEnv(text) {
        // One KEY=value per line; blank lines and lines without "=" are skipped.
        let env = {}
        let lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            let ln = lines[i].trim()
            let eq = ln.indexOf("=")
            if (eq <= 0) continue
            let k = ln.substring(0, eq).trim()
            if (k.length > 0) env[k] = ln.substring(eq + 1).trim()
        }
        return env
    }

    function addServer() {
        let name = formName.trim().toLowerCase()
        if (name.length === 0) { section.statusText = "name is required"; return }
        if (/[^a-z0-9-]/.test(name)) { section.statusText = "name: lowercase letters, digits and - only"; return }
        for (let i = 0; i < servers.length; i++) {
            if (servers[i].name === name) { section.statusText = "\"" + name + "\" already exists"; return }
        }
        let toks = formCommand.trim().split(/\s+/).filter(t => t.length > 0)
        if (toks.length === 0) { section.statusText = "command is required"; return }

        let next = servers.slice()
        next.push({
            name: name,
            command: toks[0],
            args: toks.slice(1),
            env: parseEnv(formEnv),
            disabled: false,
            trusted: false
        })
        section.servers = next
        section.dirty = true
        section.formName = ""
        section.formCommand = ""
        section.formEnv = ""
        section.addingServer = false
        section.statusText = "added \"" + name + "\" — Save & Apply to start it"
    }

    function save() {
        if (saveProcess.running || getCurrentProcess.running) return
        section.saving = true
        section.statusText = "saving…"
        getCurrentProcess.running = true
    }

    // revert discards unsaved edits by reloading the server list from the
    // backend — the undo for a mistaken remove or toggle.
    function revert() {
        if (saveProcess.running || getCurrentProcess.running) return
        section.addingServer = false
        section.formName = ""
        section.formCommand = ""
        section.formEnv = ""
        section.statusText = "reverted unsaved changes"
        loadConfigProcess.running = true
    }

    Behavior on height {
        NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
    }

    // Initial load: config (editable definitions) then status (runtime state).
    Process {
        id: loadConfigProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "3", aiBackend.baseUrl + "/config"]
        stdout: SplitParser { onRead: data => loadConfigProcess.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) { section.statusText = "load failed"; return }
            try {
                let obj = JSON.parse(loadConfigProcess.buf)
                let m = (obj.config && obj.config.mcp && obj.config.mcp.servers) || {}
                let names = Object.keys(m).sort()
                let list = []
                for (let i = 0; i < names.length; i++) {
                    let s = m[names[i]] || {}
                    list.push({
                        name: names[i],
                        command: s.command || "",
                        args: s.args || [],
                        env: s.env || ({}),
                        disabled: !!s.disabled,
                        trusted: !!s.trusted
                    })
                }
                section.servers = list
                section.dirty = false
                section.loaded = true
                loadStatusProcess.running = true
            } catch (e) {
                section.statusText = "parse failed"
            }
        }
    }

    Process {
        id: loadStatusProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "3", aiBackend.baseUrl + "/mcp/servers"]
        stdout: SplitParser { onRead: data => loadStatusProcess.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) return
            try {
                let arr = (JSON.parse(loadStatusProcess.buf).servers) || []
                let m = {}
                for (let i = 0; i < arr.length; i++) m[arr[i].name] = arr[i]
                section.statusByName = m
            } catch (e) {}
        }
    }

    // Save chain: re-fetch config, splice in the edited mcp.servers map, PUT, restart.
    Process {
        id: getCurrentProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "3", aiBackend.baseUrl + "/config"]
        stdout: SplitParser { onRead: data => getCurrentProcess.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                section.saving = false
                section.statusText = "load before save failed"
                return
            }
            try {
                let cfg = (JSON.parse(getCurrentProcess.buf).config) || {}
                if (!cfg.mcp) cfg.mcp = {}
                let m = {}
                for (let i = 0; i < section.servers.length; i++) {
                    let s = section.servers[i]
                    m[s.name] = { command: s.command, args: s.args, env: s.env, disabled: s.disabled, trusted: s.trusted }
                }
                cfg.mcp.servers = m
                saveProcess.payload = JSON.stringify(cfg)
                saveProcess.running = true
            } catch (e) {
                section.saving = false
                section.statusText = "parse failed"
            }
        }
    }

    Process {
        id: saveProcess
        running: false
        property string buf: ""
        property string payload: ""
        command: ["curl", "-sS", "--max-time", "5",
                  "-X", "PUT", aiBackend.baseUrl + "/config",
                  "-H", "Content-Type: application/json",
                  "-d", payload]
        stdout: SplitParser { onRead: data => saveProcess.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode === 0 && saveProcess.buf.indexOf("saved") >= 0) {
                section.statusText = "saved, restarting mugen-ai…"
                restartProcess.running = true
            } else {
                section.saving = false
                section.statusText = "save failed"
            }
        }
    }

    Process {
        id: restartProcess
        running: false
        command: ["curl", "-sS", "--max-time", "3",
                  "-X", "POST", aiBackend.baseUrl + "/config/restart"]
        onExited: (exitCode) => {
            section.saving = false
            section.dirty = false
            section.statusText = exitCode === 0 ? "applied — reloading status…" : "applied (restart pending)"
            // The backend re-spawns its MCP servers on restart; give it a
            // moment, then reload so the rows reflect the new state.
            reloadTimer.start()
        }
    }

    Timer {
        id: reloadTimer
        // mugen-ai needs a beat to come back up and re-handshake its MCP
        // servers after a restart; reload once it should be listening again.
        interval: 4000
        onTriggered: loadConfigProcess.running = true
    }

    Component.onCompleted: loadConfigProcess.running = true

    MouseArea {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 64
        cursorShape: Qt.PointingHandCursor

        TapHandler {
            onTapped: {
                section.isExpanded = !section.isExpanded
                section.bump()
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "MCP servers"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.letterSpacing: 0.5
                elide: Text.ElideRight
            }

            Text {
                text: section.summary()
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: 11
                font.family: "M PLUS 2"
                font.italic: !section.loaded
                opacity: 0.85
            }

            Text {
                text: section.isExpanded ? "▴" : "▾"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                opacity: 0.7
            }
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 4
        spacing: 8
        visible: section.isExpanded

        Text {
            Layout.fillWidth: true
            text: "Add or remove external MCP servers. Save & Apply writes config.toml and restarts mugen-ai. The command must be on PATH (npx needs Node.js, uvx needs uv)."
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            opacity: 0.65
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: section.loaded && section.servers.length === 0
            text: "No MCP servers yet — add one below."
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            opacity: 0.7
        }

        Repeater {
            model: section.servers

            Rectangle {
                id: serverRow
                required property var modelData

                // Live status for this server, or null when it hasn't been
                // applied yet (newly added, still unsaved).
                readonly property var st: section.statusByName[modelData.name] || null
                readonly property bool pending: st === null && !modelData.disabled

                Layout.fillWidth: true
                Layout.preferredHeight: serverBody.implicitHeight + 16
                radius: 10
                color: section.theme ? section.theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.3)
                border.width: 1
                border.color: section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.12)

                ColumnLayout {
                    id: serverBody
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: serverRow.modelData.disabled
                                ? Qt.rgba(0.6, 0.6, 0.65, 0.7)
                                : serverRow.pending
                                    ? Qt.rgba(0.85, 0.7, 0.4, 0.9)
                                    : (serverRow.st && serverRow.st.connected)
                                        ? Qt.rgba(0.45, 0.85, 0.55, 0.95)
                                        : Qt.rgba(0.85, 0.45, 0.45, 0.85)
                        }

                        Text {
                            text: serverRow.modelData.name
                            color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95)
                            font.pixelSize: 12
                            font.family: "M PLUS 2"
                            font.weight: Font.Medium
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: serverRow.modelData.disabled
                                ? "disabled"
                                : serverRow.pending
                                    ? "not applied"
                                    : (serverRow.st && serverRow.st.connected)
                                        ? "running"
                                        : "failed"
                            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
                            font.pixelSize: 10
                            font.family: "M PLUS 2"
                            opacity: 0.7
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignRight
                        }

                        // Enable / disable toggle.
                        Rectangle {
                            id: pill
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 20
                            Layout.alignment: Qt.AlignVCenter
                            radius: 10

                            readonly property bool on: !serverRow.modelData.disabled

                            color: pill.on
                                ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                                : Qt.rgba(0.3, 0.3, 0.36, 0.5)
                            border.width: 1
                            border.color: pill.on
                                ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95))
                                : Qt.rgba(1, 1, 1, 0.10)
                            Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                                y: 3
                                x: pill.on ? pill.width - width - 3 : 3
                                Behavior on x { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: section.setDisabled(serverRow.modelData.name, pill.on)
                            }
                        }

                        // Remove.
                        Rectangle {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            Layout.alignment: Qt.AlignVCenter
                            radius: 11
                            color: removeMouse.containsMouse
                                ? Qt.rgba(0.85, 0.4, 0.4, 0.35)
                                : Qt.rgba(0.85, 0.4, 0.4, 0.16)
                            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: Qt.rgba(0.95, 0.7, 0.7, 0.95)
                                font.pixelSize: 14
                                font.family: "M PLUS 2"
                            }

                            MouseArea {
                                id: removeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { section.removeServer(serverRow.modelData.name); section.bump() }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        readonly property bool failed: !serverRow.modelData.disabled && !serverRow.pending
                            && !(serverRow.st && serverRow.st.connected)
                        text: serverRow.modelData.disabled
                            ? "Skipped — toggle on and Save & Apply to start."
                            : serverRow.pending
                                ? "Not running yet — Save & Apply to start it."
                                : (serverRow.st && serverRow.st.connected)
                                    ? (serverRow.st.tool_count + " tool" + (serverRow.st.tool_count === 1 ? "" : "s")
                                       + "  ·  " + serverRow.modelData.command)
                                    : ((serverRow.st && serverRow.st.error) || "Handshake failed.")
                        color: failed
                            ? Qt.rgba(0.9, 0.55, 0.55, 0.9)
                            : (section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85))
                        font.pixelSize: 10
                        font.family: "M PLUS 2"
                        opacity: failed ? 0.95 : 0.7
                        wrapMode: Text.WordWrap
                    }

                    // Trusted toggle — on = this server's destructive tools
                    // run without the per-call approval prompt.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 8

                        Rectangle {
                            id: trustPill
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 18
                            Layout.alignment: Qt.AlignVCenter
                            radius: 9

                            readonly property bool on: !!serverRow.modelData.trusted

                            color: trustPill.on
                                ? Qt.rgba(0.95, 0.74, 0.42, 0.45)
                                : Qt.rgba(0.3, 0.3, 0.36, 0.5)
                            border.width: 1
                            border.color: trustPill.on
                                ? Qt.rgba(0.95, 0.74, 0.42, 0.95)
                                : Qt.rgba(1, 1, 1, 0.10)
                            Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                                y: 3
                                x: trustPill.on ? trustPill.width - width - 3 : 3
                                Behavior on x { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: section.setTrusted(serverRow.modelData.name, !trustPill.on)
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: "Trusted — run this server's tools without an approval prompt"
                            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
                            font.pixelSize: 10
                            font.family: "M PLUS 2"
                            opacity: trustPill.on ? 0.85 : 0.6
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        // "+ Add server" toggle button.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            visible: !section.addingServer
            radius: 10
            color: addMouse.containsMouse ? Qt.rgba(0.55, 0.55, 0.65, 0.30) : Qt.rgba(0.55, 0.55, 0.65, 0.18)
            border.width: 1
            border.color: section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.12)
            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

            Text {
                anchors.centerIn: parent
                text: "+ Add server"
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: 11
                font.family: "M PLUS 2"
                font.weight: Font.Medium
            }

            MouseArea {
                id: addMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    section.addingServer = true
                    section.statusText = ""
                    section.bump()
                }
            }
        }

        // Add-server form.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: addForm.implicitHeight + 20
            visible: section.addingServer
            radius: 10
            color: section.theme ? section.theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.3)
            border.width: 1
            border.color: section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.12)

            ColumnLayout {
                id: addForm
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 10
                spacing: 6

                // name + command share the labelled-input pattern.
                Repeater {
                    model: [
                        { key: "name", label: "Name", hint: "memory" },
                        { key: "command", label: "Command", hint: "npx -y @modelcontextprotocol/server-memory" }
                    ]

                    RowLayout {
                        id: fieldRow
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.preferredWidth: 64
                            text: fieldRow.modelData.label
                            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                            font.pixelSize: 11
                            font.family: "M PLUS 2"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            color: "transparent"
                            radius: 8
                            border.width: 1
                            border.color: fieldInput.activeFocus
                                ? (section.theme ? section.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                                : (section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18))
                            Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

                            TextInput {
                                id: fieldInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                text: fieldRow.modelData.key === "name" ? section.formName : section.formCommand
                                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                                selectionColor: section.theme ? Qt.rgba(section.theme.glowPrimary.r, section.theme.glowPrimary.g, section.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                                font.pixelSize: 11
                                font.family: "M PLUS 2"
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                onTextChanged: {
                                    if (fieldRow.modelData.key === "name") section.formName = text
                                    else section.formCommand = text
                                }

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 0
                                    verticalAlignment: Text.AlignVCenter
                                    visible: parent.text.length === 0
                                    text: fieldRow.modelData.hint
                                    color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.45)
                                    font.pixelSize: 10
                                    font.family: "M PLUS 2"
                                    opacity: 0.5
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Env (optional) — KEY=value per line. Stored as plaintext in config.toml; use ${VAR} to read a secret from the environment instead."
                    color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
                    font.pixelSize: 10
                    font.family: "M PLUS 2"
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "transparent"
                    radius: 8
                    border.width: 1
                    border.color: envInput.activeFocus
                        ? (section.theme ? section.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                        : (section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18))
                    Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }
                    clip: true

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true

                        TextArea {
                            id: envInput
                            text: section.formEnv
                            color: section.theme ? section.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                            selectionColor: section.theme ? Qt.rgba(section.theme.glowPrimary.r, section.theme.glowPrimary.g, section.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                            font.pixelSize: 10
                            font.family: "M PLUS 2"
                            wrapMode: TextEdit.Wrap
                            background: null
                            padding: 0
                            onTextChanged: section.formEnv = text
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 26
                        radius: 13
                        color: cancelMouse.containsMouse ? Qt.rgba(0.55, 0.55, 0.65, 0.32) : Qt.rgba(0.55, 0.55, 0.65, 0.22)
                        Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                            font.pixelSize: 10
                            font.family: "M PLUS 2"
                        }

                        MouseArea {
                            id: cancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                section.addingServer = false
                                section.formName = ""
                                section.formCommand = ""
                                section.formEnv = ""
                                section.statusText = ""
                                section.bump()
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 26
                        radius: 13
                        color: addToListMouse.containsMouse ? Qt.rgba(0.45, 0.65, 0.90, 0.45) : Qt.rgba(0.45, 0.65, 0.90, 0.3)
                        Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                        Text {
                            anchors.centerIn: parent
                            text: "Add to list"
                            color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                            font.pixelSize: 10
                            font.family: "M PLUS 2"
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: addToListMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { section.addServer(); section.bump() }
                        }
                    }
                }
            }
        }

        // Status line + Refresh + Save & Apply.
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: section.statusText
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
                font.pixelSize: 10
                font.family: "M PLUS 2"
                opacity: section.statusText ? 0.85 : 0
                elide: Text.ElideRight
                Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }
            }

            Rectangle {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 28
                radius: 14
                color: refreshMouse.containsMouse ? Qt.rgba(0.55, 0.55, 0.65, 0.32) : Qt.rgba(0.55, 0.55, 0.65, 0.22)
                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                Text {
                    anchors.centerIn: parent
                    text: "Refresh"
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Re-poll status only; never clobber unsaved edits to the list.
                    onClicked: { loadStatusProcess.running = true; section.bump() }
                }
            }

            // Revert — discards unsaved edits; only shown when there are any.
            Rectangle {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 28
                visible: section.dirty && !section.saving
                radius: 14
                color: revertMouse.containsMouse ? Qt.rgba(0.85, 0.55, 0.42, 0.32) : Qt.rgba(0.85, 0.55, 0.42, 0.18)
                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                Text {
                    anchors.centerIn: parent
                    text: "Revert"
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                }

                MouseArea {
                    id: revertMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { section.revert(); section.bump() }
                }
            }

            Rectangle {
                Layout.preferredWidth: 110
                Layout.preferredHeight: 28
                radius: 14
                enabled: section.dirty && !section.saving
                opacity: (section.dirty && !section.saving) ? 1.0 : 0.5
                color: saveMouse.containsMouse ? Qt.rgba(0.45, 0.65, 0.90, 0.45) : Qt.rgba(0.45, 0.65, 0.90, 0.3)
                Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

                Text {
                    anchors.centerIn: parent
                    text: section.saving ? "…" : "Save & Apply"
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: saveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: section.dirty && !section.saving
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { section.save(); section.bump() }
                }
            }
        }
    }
}
