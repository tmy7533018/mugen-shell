import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../../lib" as Theme

// Expose mugen-shell's own tools as an MCP server so external clients
// (Claude Desktop, Cursor, any Streamable HTTP client) can drive the shell.
// Mirrors [mcp_expose] in config.toml: enabled + read-only tools + opt-in
// writable categories.
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
    property bool dirty: false
    property string statusText: ""

    property bool exposeEnabled: false
    property bool readonlyOn: true
    property var exposedSet: ({})
    property int dirtyTick: 0  // bump to re-evaluate bindings that read exposedSet

    readonly property var categories: [
        { id: "audio",        label: "Audio",         desc: "Volume, mic, mute" },
        { id: "music",        label: "Music",         desc: "Play / pause / skip (MPRIS)" },
        { id: "brightness",   label: "Brightness",    desc: "Display backlight" },
        { id: "theme",        label: "Theme",         desc: "Dark / light switching" },
        { id: "wallpaper",    label: "Wallpaper",     desc: "Switch / list wallpapers" },
        { id: "notification", label: "Notifications", desc: "DnD, unread count, clear all" },
        { id: "timer",        label: "Timer",         desc: "Countdown timer" },
        { id: "calendar",     label: "Calendar",      desc: "Events: add / list / delete" },
        { id: "panel",        label: "Panels",        desc: "Open / close mugen-shell panels" },
        { id: "app",          label: "App launcher",  desc: "Launch apps (gated by allowlist)" },
        { id: "memory",       label: "Memory",        desc: "Yura's long-term memory" },
        { id: "weather",      label: "Weather",       desc: "Current weather & forecast" }
    ]

    readonly property string desktopSnippet:
        '{\n  "mcpServers": {\n    "mugen-shell": {\n      "command": "mugen-ai",\n      "args": ["mcp-server"]\n    }\n  }\n}'

    readonly property int expandedHeight: 64 + contentColumn.implicitHeight + 16

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function isExposed(catId) {
        let _ = section.dirtyTick
        return !!section.exposedSet[catId]
    }

    function setExposed(catId, on) {
        let next = Object.assign({}, section.exposedSet)
        if (on) next[catId] = true
        else delete next[catId]
        section.exposedSet = next
        section.dirtyTick++
        section.dirty = true
    }

    function summary() {
        if (!loaded) return "loading…"
        if (!exposeEnabled) return "off" + (dirty ? " · unsaved" : "")
        let writable = 0
        for (let i = 0; i < categories.length; i++) {
            if (exposedSet[categories[i].id]) writable++
        }
        let s = readonlyOn ? "read-only tools" : "no reads"
        if (writable > 0) s += " + " + writable + " writable"
        return s + (dirty ? " · unsaved" : "")
    }

    function save() {
        if (saveProcess.running || getCurrentProcess.running) return
        section.saving = true
        section.statusText = "saving…"
        getCurrentProcess.running = true
    }

    Behavior on height {
        NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
    }

    Process {
        id: loadProcess
        running: false
        property string buf: ""
        command: ["curl", "-fsS", "--max-time", "3", aiBackend.baseUrl + "/config"]
        stdout: SplitParser { onRead: data => loadProcess.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) { section.statusText = "load failed"; return }
            try {
                let obj = JSON.parse(loadProcess.buf)
                let e = (obj.config && obj.config.mcp_expose) || {}
                section.exposeEnabled = !!e.enabled
                section.readonlyOn = e.readonly !== false
                let m = {}
                let cats = e.categories || []
                for (let i = 0; i < cats.length; i++) m[cats[i]] = true
                section.exposedSet = m
                section.dirtyTick++
                section.dirty = false
                section.loaded = true
            } catch (err) {
                section.statusText = "parse failed"
            }
        }
    }

    // Save chain: re-fetch config, splice in mcp_expose, PUT, restart.
    Process {
        id: getCurrentProcess
        running: false
        property string buf: ""
        command: ["curl", "-fsS", "--max-time", "3", aiBackend.baseUrl + "/config"]
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
                let cats = []
                for (let i = 0; i < section.categories.length; i++) {
                    let id = section.categories[i].id
                    if (section.exposedSet[id]) cats.push(id)
                }
                cfg.mcp_expose = {
                    enabled: section.exposeEnabled,
                    readonly: section.readonlyOn,
                    categories: cats
                }
                saveProcess.payload = JSON.stringify(cfg)
                saveProcess.running = true
            } catch (err) {
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
        command: ["curl", "-fsS", "--max-time", "5",
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
        command: ["curl", "-fsS", "--max-time", "3",
                  "-X", "POST", aiBackend.baseUrl + "/config/restart"]
        onExited: (exitCode) => {
            section.saving = false
            section.dirty = false
            section.statusText = exitCode === 0 ? "applied" : "applied (restart pending)"
        }
    }

    Component.onCompleted: loadProcess.running = true

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
                text: "Expose as MCP server"
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
            text: "Let external MCP clients (Claude Desktop, Cursor, …) control mugen-shell. External clients skip Yura's confirmation prompts, so writable categories are opt-in."
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            opacity: 0.65
            wrapMode: Text.WordWrap
        }

        // Master toggle + read-only toggle share one row pattern.
        Repeater {
            model: [
                { key: "enabled",  label: "Enable",          desc: "Serve tools at /mcp and to `mugen-ai mcp-server`" },
                { key: "readonly", label: "Read-only tools", desc: "Expose every get / list / current tool" }
            ]

            RowLayout {
                id: toggleRow
                required property var modelData
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: toggleRow.modelData.label
                        color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.92)
                        font.pixelSize: 11
                        font.family: "M PLUS 2"
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: toggleRow.modelData.desc
                        color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
                        font.pixelSize: 9
                        font.family: "M PLUS 2"
                        opacity: 0.6
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: togglePill
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    radius: 10

                    readonly property bool on: toggleRow.modelData.key === "enabled"
                        ? section.exposeEnabled : section.readonlyOn

                    color: togglePill.on
                        ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                        : Qt.rgba(0.3, 0.3, 0.36, 0.5)
                    border.width: 1
                    border.color: togglePill.on
                        ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95))
                        : Qt.rgba(1, 1, 1, 0.10)
                    Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

                    Rectangle {
                        width: 14
                        height: 14
                        radius: 7
                        color: section.theme ? section.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                        y: 3
                        x: togglePill.on ? togglePill.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (toggleRow.modelData.key === "enabled") section.exposeEnabled = !section.exposeEnabled
                            else section.readonlyOn = !section.readonlyOn
                            section.dirty = true
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            visible: section.exposeEnabled
            text: "Writable categories"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            font.letterSpacing: 0.5
            opacity: 0.75
        }

        Repeater {
            model: section.exposeEnabled ? section.categories : []

            RowLayout {
                id: catRow
                required property var modelData
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: catRow.modelData.label
                        color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.92)
                        font.pixelSize: 11
                        font.family: "M PLUS 2"
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: catRow.modelData.desc
                        color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
                        font.pixelSize: 9
                        font.family: "M PLUS 2"
                        opacity: 0.6
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: catPill
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    radius: 10

                    readonly property bool on: section.isExposed(catRow.modelData.id)

                    color: catPill.on
                        ? Qt.rgba(0.95, 0.74, 0.42, 0.45)
                        : Qt.rgba(0.3, 0.3, 0.36, 0.5)
                    border.width: 1
                    border.color: catPill.on
                        ? Qt.rgba(0.95, 0.74, 0.42, 0.95)
                        : Qt.rgba(1, 1, 1, 0.10)
                    Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

                    Rectangle {
                        width: 14
                        height: 14
                        radius: 7
                        color: section.theme ? section.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                        y: 3
                        x: catPill.on ? catPill.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: section.setExposed(catRow.modelData.id, !catPill.on)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            visible: section.exposeEnabled
            text: "HTTP endpoint: " + aiBackend.baseUrl + "/mcp\nClaude Desktop config (claude_desktop_config.json):"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: snippetText.implicitHeight + 16
            visible: section.exposeEnabled
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.3)
            border.width: 1
            border.color: section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.12)

            TextEdit {
                id: snippetText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                text: section.desktopSnippet
                readOnly: true
                selectByMouse: true
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                selectionColor: section.theme ? Qt.rgba(section.theme.glowPrimary.r, section.theme.glowPrimary.g, section.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                font.pixelSize: 10
                font.family: "monospace"
                wrapMode: TextEdit.Wrap
            }
        }

        // Status + Save & Apply.
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
