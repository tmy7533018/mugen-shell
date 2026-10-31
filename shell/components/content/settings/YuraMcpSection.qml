import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../common" as Common
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
    readonly property bool canSave: loaded && dirty && !saving
    property bool saving: false
    property string statusText: ""

    property var servers: []
    property var statusByName: ({})
    property bool dirty: false

    property bool addingServer: false
    property string formName: ""
    property string formCommand: ""
    property string formUrl: ""
    property string formEnv: ""

    property var discoverCandidates: []
    readonly property var unaddedCandidates: discoverCandidates.filter(c => !servers.some(s => s.name.toLowerCase() === c.name.toLowerCase()))

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

    // Copies every field so toggling one never drops sibling state.
    function patchServer(name, key, value) {
        let next = []
        for (let i = 0; i < servers.length; i++) {
            let s = servers[i]
            if (s.name === name) {
                let copy = Object.assign({}, s)
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

    // The args reach exec untouched, so quoting is the only syntax; $, ~ and backslashes stay literal.
    function splitCommand(text) {
        let words = []
        let word = null
        let quote = ""
        for (const c of text) {
            if (quote) {
                if (c === quote) quote = ""
                else word += c
            } else if (c === "'" || c === "\"") {
                quote = c
                if (word === null) word = ""
            } else if (/\s/.test(c)) {
                if (word !== null) words.push(word)
                word = null
            } else {
                word = (word === null ? "" : word) + c
            }
        }
        if (quote) return null
        if (word !== null) words.push(word)
        return words
    }

    function joinCommand(words) {
        return words.map(w => /^[^\s'"]+$/.test(w) ? w
            : w.indexOf("'") < 0 ? "'" + w + "'"
            : w.indexOf("\"") < 0 ? "\"" + w + "\""
            : "'" + w.replace(/'/g, "'\"'\"'") + "'").join(" ")
    }

    function prefillCandidate(candidate) {
        section.formName = candidate.name
        section.formCommand = joinCommand([candidate.command].concat(candidate.args || []))
        section.formUrl = ""
        section.addingServer = true
        section.statusText = ""
        section.bump()
    }

    function addServer() {
        let name = formName.trim().toLowerCase()
        if (name.length === 0) { section.statusText = "name is required"; return }
        if (!/^[a-z][a-z0-9-]*$/.test(name)) { section.statusText = "name: a-z first, then a-z, 0-9 or -"; return }
        for (let i = 0; i < servers.length; i++) {
            if (servers[i].name.toLowerCase() === name) { section.statusText = "\"" + servers[i].name + "\" already exists"; return }
        }
        let toks = splitCommand(formCommand)
        if (toks === null) { section.statusText = "command: unclosed quote"; return }
        let command = toks.length > 0 ? toks[0] : ""
        let url = formUrl.trim()
        if (command.length === 0 && url.length === 0) { section.statusText = "command or URL is required"; return }
        if (url.length > 0 && !/^https?:\/\//.test(url)) { section.statusText = "URL must start with http:// or https://"; return }

        let next = servers.slice()
        next.push({
            name: name,
            command: command,
            args: toks.slice(1),
            env: parseEnv(formEnv),
            url: url,
            disabled: false,
            trusted: false
        })
        section.servers = next
        section.dirty = true
        section.formName = ""
        section.formCommand = ""
        section.formUrl = ""
        section.formEnv = ""
        section.addingServer = false
        section.statusText = "added \"" + name + "\" — Save & Apply to start it"
    }

    // Only this subtree: the whole document would revert whatever another section just saved.
    // `existing` carries the per-server fields this section does not model.
    function savePayload(existing) {
        let m = {}
        for (let i = 0; i < section.servers.length; i++) {
            let srv = section.servers[i]
            m[srv.name] = Object.assign({}, existing[srv.name] || {}, {
                command: srv.command, args: srv.args, env: srv.env,
                url: srv.url || "", disabled: srv.disabled, trusted: srv.trusted
            })
        }
        return JSON.stringify({ mcp: { servers: m } })
    }

    // Saving before the list loaded would PUT an empty server map over the real one.
    function save() {
        if (!section.loaded || saveProcess.running || getCurrentProcess.running) return
        section.saving = true
        section.statusText = "saving…"
        getCurrentProcess.running = true
    }

    function revert() {
        if (saveProcess.running || getCurrentProcess.running) return
        section.addingServer = false
        section.formName = ""
        section.formCommand = ""
        section.formUrl = ""
        section.formEnv = ""
        section.statusText = "reverted unsaved changes"
        loadConfigProcess.running = true
    }


    // mugen-ai opens its socket only after the MCP handshakes, so a load right after a restart fails.
    Timer {
        id: loadRetry
        interval: 3000
        onTriggered: if ((!section.loaded || !section.dirty) && !loadConfigProcess.running) loadConfigProcess.running = true
    }

    Behavior on height {
        NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
    }

    AiCall {
        id: loadConfigProcess
        backend: aiBackend
        path: "/config"
        onExited: (exitCode) => {
            if (exitCode !== 0) { section.statusText = "load failed"; loadRetry.restart(); return }
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
                        url: s.url || "",
                        disabled: !!s.disabled,
                        trusted: !!s.trusted
                    })
                }
                section.servers = list
                section.dirty = false
                section.loaded = true
                if (section.statusText === "load failed") section.statusText = ""
                loadStatusProcess.running = true
            } catch (e) {
                section.statusText = "parse failed"
            }
        }
    }

    AiCall {
        id: loadStatusProcess
        backend: aiBackend
        path: "/mcp/servers"
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

    AiCall {
        id: getCurrentProcess
        backend: aiBackend
        path: "/config"
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                section.saving = false
                section.statusText = "load before save failed"
                return
            }
            try {
                let cfg = (JSON.parse(getCurrentProcess.buf).config) || {}
                if (!cfg.mcp) cfg.mcp = {}
                // Overlaid onto the config just fetched, so per-server fields this section doesn't model survive.
                saveProcess.payload = section.savePayload(cfg.mcp.servers || {})
                saveProcess.running = true
            } catch (e) {
                section.saving = false
                section.statusText = "parse failed"
            }
        }
    }

    AiConfigPut {
        id: saveProcess
        backend: aiBackend
        onSavedOk: {
            section.statusText = "saved, restarting mugen-ai…"
            restartProcess.running = true
        }
        onSaveFailed: {
            section.saving = false
            section.statusText = "save failed"
        }
    }

    AiCall {
        id: restartProcess
        backend: aiBackend
        path: "/config/restart"
        method: "POST"
        onExited: (exitCode) => {
            section.saving = false
            section.dirty = false
            section.statusText = exitCode === 0 ? "applied — reloading status…" : "applied (restart pending)"
            reloadTimer.start()
        }
    }

    Timer {
        id: reloadTimer
        // Wait for mugen-ai to come back up and re-handshake its MCP servers.
        interval: 4000
        onTriggered: if (!section.dirty) loadConfigProcess.running = true
    }

    AiCall {
        id: discoverProcess
        backend: aiBackend
        path: "/mcp/discover"
        maxTime: "8"
        onExited: (exitCode) => {
            if (exitCode !== 0) { section.statusText = "discover failed"; return }
            try {
                section.discoverCandidates = (JSON.parse(discoverProcess.buf).candidates) || []
                if (section.discoverCandidates.length === 0)
                    section.statusText = "no installed MCP servers found (npm -g)"
                section.bump()
            } catch (e) {
                section.statusText = "discover parse failed"
            }
        }
    }

    Component.onCompleted: loadConfigProcess.running = true

    YuraSectionHeader {
        id: header
        theme: section.theme
        title: "MCP servers"
        summaryText: section.summary()
        summaryItalic: !section.loaded
        expanded: section.isExpanded
        onToggleRequested: {
            section.isExpanded = !section.isExpanded
            section.bump()
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

            YuraMcpServerRow {
                id: serverRow
                theme: section.theme
                st: section.statusByName[serverRow.modelData.name] || null
                onDisableRequested: off => section.setDisabled(serverRow.modelData.name, off)
                onTrustRequested: on => section.setTrusted(serverRow.modelData.name, on)
                onRemoveRequested: { section.removeServer(serverRow.modelData.name); section.bump() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !section.addingServer
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
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

            Rectangle {
                Layout.preferredWidth: 90
                Layout.preferredHeight: 30
                radius: 10
                color: discoverMouse.containsMouse ? Qt.rgba(0.55, 0.55, 0.65, 0.30) : Qt.rgba(0.55, 0.55, 0.65, 0.18)
                border.width: 1
                border.color: section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.12)
                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                Text {
                    anchors.centerIn: parent
                    text: discoverProcess.running ? "…" : "Discover"
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                }

                MouseArea {
                    id: discoverMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        section.statusText = ""
                        discoverProcess.running = true
                        section.bump()
                    }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: !section.addingServer && section.unaddedCandidates.length > 0
            spacing: 6

            Repeater {
                model: section.unaddedCandidates

                Rectangle {
                    id: candidatePill
                    required property var modelData
                    width: candidateLabel.implicitWidth + 20
                    height: 24
                    radius: 12
                    color: candidateMouse.containsMouse ? Qt.rgba(0.45, 0.65, 0.90, 0.35) : Qt.rgba(0.45, 0.65, 0.90, 0.18)
                    border.width: 1
                    border.color: Qt.rgba(0.45, 0.65, 0.90, 0.5)
                    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                    Text {
                        id: candidateLabel
                        anchors.centerIn: parent
                        text: "+ " + candidatePill.modelData.name
                        color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                        font.pixelSize: 10
                        font.family: "M PLUS 2"
                    }

                    MouseArea {
                        id: candidateMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: section.prefillCandidate(candidatePill.modelData)
                    }
                }
            }
        }

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

                Repeater {
                    model: [
                        { key: "name", label: "Name", hint: "memory" },
                        { key: "command", label: "Command", hint: "npx -y @modelcontextprotocol/server-memory" },
                        { key: "url", label: "URL", hint: "http://host:port/mcp — remote server, instead of a command" }
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
                                text: fieldRow.modelData.key === "name" ? section.formName
                                    : fieldRow.modelData.key === "command" ? section.formCommand
                                    : section.formUrl
                                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                                selectionColor: section.theme ? Qt.rgba(section.theme.glowPrimary.r, section.theme.glowPrimary.g, section.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                                font.pixelSize: 11
                                font.family: "M PLUS 2"
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                onTextChanged: {
                                    if (fieldRow.modelData.key === "name") section.formName = text
                                    else if (fieldRow.modelData.key === "command") section.formCommand = text
                                    else section.formUrl = text
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

                    Common.SubtleButton {
                        theme: section.theme
                        label: "Cancel"
                        buttonWidth: 70
                        buttonHeight: 26
                        fontSize: 10
                        onClicked: {
                            section.addingServer = false
                            section.formName = ""
                            section.formCommand = ""
                            section.formUrl = ""
                            section.formEnv = ""
                            section.statusText = ""
                            section.bump()
                        }
                    }

                    Common.SubtleButton {
                        theme: section.theme
                        label: "Add to list"
                        buttonWidth: 90
                        buttonHeight: 26
                        fontSize: 10
                        fontWeight: Font.Medium
                        tint: Qt.rgba(0.45, 0.65, 0.90, 0.30)
                        tintHover: Qt.rgba(0.45, 0.65, 0.90, 0.45)
                        onClicked: { section.addServer(); section.bump() }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8

            YuraStatusText {
                theme: section.theme
                text: section.statusText
            }

            Common.SubtleButton {
                theme: section.theme
                label: "Refresh"
                buttonWidth: 72
                // Re-poll status only; never clobber unsaved edits to the list.
                onClicked: { (section.loaded ? loadStatusProcess : loadConfigProcess).running = true; section.bump() }
            }

            Common.SubtleButton {
                theme: section.theme
                label: "Revert"
                buttonWidth: 72
                visible: section.dirty && !section.saving
                tint: Qt.rgba(0.85, 0.55, 0.42, 0.18)
                tintHover: Qt.rgba(0.85, 0.55, 0.42, 0.32)
                onClicked: { section.revert(); section.bump() }
            }

            Rectangle {
                Layout.preferredWidth: 110
                Layout.preferredHeight: 28
                radius: 14
                enabled: section.canSave
                opacity: section.canSave ? 1.0 : 0.5
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
                    enabled: section.canSave
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { section.save(); section.bump() }
                }
            }
        }
    }
}
