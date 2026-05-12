import QtQuick
import QtQuick.Layouts
import Quickshell
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

    property var allowedSet: ({})  // map: binary → true
    property int dirtyTick: 0
    property var installedApps: []  // [{ binary, display }]
    property string filterText: ""

    readonly property var allRows: {
        // Apps that exist on disk first (sorted by display name), then any
        // legacy/custom entries from the user's allowlist that aren't in the
        // installed-apps list (CLI tools like htop, hand-edited entries).
        let _ = section.dirtyTick
        let known = {}
        let rows = []
        for (let i = 0; i < section.installedApps.length; i++) {
            let a = section.installedApps[i]
            known[a.binary] = true
            rows.push({ binary: a.binary, display: a.display, custom: false })
        }
        for (let bin in section.allowedSet) {
            if (!known[bin]) rows.push({ binary: bin, display: bin + " (custom / CLI)", custom: true })
        }
        return rows
    }

    readonly property var filteredRows: {
        let q = (section.filterText || "").trim().toLowerCase()
        if (!q) return section.allRows
        let out = []
        for (let i = 0; i < section.allRows.length; i++) {
            let r = section.allRows[i]
            if (r.binary.toLowerCase().indexOf(q) >= 0 || r.display.toLowerCase().indexOf(q) >= 0) {
                out.push(r)
            }
        }
        return out
    }

    readonly property int allowedCount: {
        let _ = section.dirtyTick
        let n = 0
        for (let k in section.allowedSet) if (section.allowedSet[k]) n++
        return n
    }

    readonly property int expandedHeight: 64 + contentColumn.implicitHeight + 16

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function summary() {
        if (!loaded) return "loading…"
        if (section.allowedCount === 0) return "permissive (any app)"
        return section.allowedCount + " app" + (section.allowedCount === 1 ? "" : "s") + " allowed"
    }

    function isAllowed(bin) {
        let _ = section.dirtyTick
        return !!section.allowedSet[bin]
    }

    function toggleAllowed(bin) {
        let next = Object.assign({}, section.allowedSet)
        if (next[bin]) delete next[bin]
        else next[bin] = true
        section.allowedSet = next
        section.dirtyTick++
    }

    // Bulk on/off applies to whatever is currently visible after the search
    // filter — keeps "All on" from accidentally allowing 200 desktop apps
    // when the user just wanted to grant a subset.
    function bulkAllow(on) {
        let next = Object.assign({}, section.allowedSet)
        let rows = section.filteredRows
        for (let i = 0; i < rows.length; i++) {
            let bin = rows[i].binary
            if (on) next[bin] = true
            else delete next[bin]
        }
        section.allowedSet = next
        section.dirtyTick++
    }

    Behavior on height {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    Process {
        id: loadConfig
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "3", aiBackend.baseUrl + "/config"]
        stdout: SplitParser { onRead: data => loadConfig.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) { section.statusText = "load failed"; return }
            try {
                let obj = JSON.parse(loadConfig.buf)
                let arr = obj.config && obj.config.tools && obj.config.tools.app_launch
                    && obj.config.tools.app_launch.allowed_commands
                    ? obj.config.tools.app_launch.allowed_commands
                    : []
                let m = {}
                for (let i = 0; i < arr.length; i++) m[arr[i]] = true
                section.allowedSet = m
                section.dirtyTick++
                section.loaded = true
                section.statusText = ""
            } catch (e) {
                section.statusText = "parse failed"
            }
        }
    }

    Process {
        id: loadApps
        running: false
        property string buf: ""
        command: ["python3", Quickshell.shellDir + "/scripts/list-apps.py"]
        stdout: SplitParser { onRead: data => loadApps.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0 || !loadApps.buf) return
            try {
                let arr = JSON.parse(loadApps.buf)
                let pool = []
                let seen = {}
                for (let i = 0; i < arr.length; i++) {
                    let app = arr[i]
                    if (!app || !app.exec) continue
                    let tokens = String(app.exec).trim().split(/\s+/)
                    if (tokens.length === 0) continue
                    let first = tokens[0]
                    let slash = first.lastIndexOf("/")
                    let bin = slash >= 0 ? first.substring(slash + 1) : first
                    if (!bin || seen[bin]) continue
                    seen[bin] = true
                    pool.push({ binary: bin, display: app.name || bin })
                }
                pool.sort((a, b) => a.display.toLowerCase().localeCompare(b.display.toLowerCase()))
                section.installedApps = pool
            } catch (e) {}
        }
    }

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
                let obj = JSON.parse(getCurrentProcess.buf)
                let cfg = obj.config || {}
                if (!cfg.tools) cfg.tools = {}
                if (!cfg.tools.app_launch) cfg.tools.app_launch = {}
                let list = []
                for (let k in section.allowedSet) {
                    if (section.allowedSet[k]) list.push(k)
                }
                list.sort()
                cfg.tools.app_launch.allowed_commands = list
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
                section.statusText = "saved, applying…"
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
            section.statusText = exitCode === 0 ? "applied" : "applied (restart pending)"
        }
    }

    function save() {
        if (saveProcess.running || getCurrentProcess.running) return
        section.saving = true
        section.statusText = "saving…"
        getCurrentProcess.running = true
    }

    Component.onCompleted: {
        loadConfig.running = true
        loadApps.running = true
    }

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
                text: "Allowed apps"
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
                font.italic: !section.loaded || section.allowedCount === 0
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
        spacing: 10
        visible: section.isExpanded

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Pick the apps Yura is allowed to open. Empty list = any app (permissive — not recommended outside personal setups). Shell metacharacters (; | & $ etc.) are always rejected, so even an allowed app can't be tricked into running side commands."
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
                font.pixelSize: 10
                font.family: "M PLUS 2"
                opacity: 0.65
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignTop
                radius: 12
                color: allOnMouse.containsMouse ? Qt.rgba(0.55, 0.55, 0.65, 0.32) : Qt.rgba(0.55, 0.55, 0.65, 0.22)
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "All on"
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 10
                    font.family: "M PLUS 2"
                }

                MouseArea {
                    id: allOnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.bulkAllow(true)
                }
            }

            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignTop
                radius: 12
                color: allOffMouse.containsMouse ? Qt.rgba(0.55, 0.55, 0.65, 0.32) : Qt.rgba(0.55, 0.55, 0.65, 0.22)
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "All off"
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 10
                    font.family: "M PLUS 2"
                }

                MouseArea {
                    id: allOffMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.bulkAllow(false)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: "transparent"
            radius: 8
            border.width: 1
            border.color: filterInput.activeFocus
                ? (section.theme ? section.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                : (section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18))
            Behavior on border.color { ColorAnimation { duration: 180 } }

            TextInput {
                id: filterInput
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                text: section.filterText
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                selectionColor: section.theme ? Qt.rgba(section.theme.glowPrimary.r, section.theme.glowPrimary.g, section.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                onTextChanged: section.filterText = text

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "filter by app or binary…"
                    color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.5)
                    font: filterInput.font
                    opacity: filterInput.text.length === 0 ? 0.5 : 0
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 260
            radius: 10
            color: section.theme ? section.theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.3)
            border.width: 1
            border.color: section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.12)
            clip: true

            ListView {
                id: appList
                anchors.fill: parent
                anchors.margins: 4
                spacing: 0
                model: section.filteredRows
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                delegate: Rectangle {
                    required property var modelData
                    width: appList.width
                    height: 32
                    radius: 6
                    color: section.isAllowed(modelData.binary)
                        ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.18) : Qt.rgba(0.65, 0.55, 0.85, 0.18))
                        : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: parent.parent.parent.modelData.display
                                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.92)
                                font.pixelSize: 11
                                font.family: "M PLUS 2"
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: parent.parent.parent.modelData.binary
                                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.65)
                                font.pixelSize: 9
                                font.family: "M PLUS 2"
                                opacity: 0.65
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            id: pill
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 20
                            Layout.alignment: Qt.AlignVCenter
                            radius: 10

                            readonly property bool on: section.isAllowed(parent.parent.modelData.binary)

                            color: pill.on
                                ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                                : Qt.rgba(0.3, 0.3, 0.36, 0.5)
                            border.width: 1
                            border.color: pill.on
                                ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95))
                                : Qt.rgba(1, 1, 1, 0.10)
                            Behavior on color { ColorAnimation { duration: 180 } }

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                                y: 3
                                x: pill.on ? pill.width - width - 3 : 3
                                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: section.toggleAllowed(parent.modelData.binary)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
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
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            Rectangle {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 28
                radius: 14
                enabled: !section.saving
                color: saveMouse.containsMouse ? Qt.rgba(0.45, 0.65, 0.90, 0.45) : Qt.rgba(0.45, 0.65, 0.90, 0.3)
                opacity: section.saving ? 0.5 : 1.0
                Behavior on color { ColorAnimation { duration: 180 } }

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
                    enabled: !section.saving
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { section.save(); section.bump() }
                }
            }
        }
    }
}
