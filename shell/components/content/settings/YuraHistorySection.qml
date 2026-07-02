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
    property string statusText: ""

    // Stats from GET /conversations/stats.
    property string dbPath: ""
    property int convCount: 0
    property real dbSize: 0

    // Retention: retainDays is the edited value, savedRetainDays the on-disk
    // one; they diverge while there is an unapplied change.
    property int retainDays: 0
    property int savedRetainDays: 0
    readonly property bool retainDirty: retainDays !== savedRetainDays
    property bool saving: false

    // Clear all is destructive — the button arms a confirm step first.
    property bool confirmingClear: false

    readonly property var retainPresets: [0, 7, 30, 90, 365]

    readonly property int expandedHeight: 64 + contentColumn.implicitHeight + 16

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function fmtSize(bytes) {
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
        return (bytes / (1024 * 1024)).toFixed(1) + " MB"
    }

    function retainLabel(days) {
        if (days === 0) return "Off"
        if (days === 365) return "1 year"
        return days + " days"
    }

    function summary() {
        if (!loaded) return "loading…"
        let s = convCount + (convCount === 1 ? " conversation" : " conversations")
        if (retainDays > 0) s += " · auto-delete " + retainLabel(retainDays)
        return s
    }

    function applyRetention() {
        if (saveProcess.running || getCurrentProcess.running) return
        section.saving = true
        section.statusText = "saving…"
        getCurrentProcess.running = true
    }

    function doExport() {
        if (exportProcess.running) return
        let ts = Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss")
        exportProcess.outPath = Quickshell.env("HOME") + "/mugen-ai-conversations-" + ts + ".json"
        section.statusText = "exporting…"
        exportProcess.running = true
    }

    function doClear() {
        if (clearProcess.running) return
        section.confirmingClear = false
        section.statusText = "clearing…"
        clearProcess.running = true
    }

    Behavior on height {
        NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
    }

    // Initial load: stats + the retention setting from config.
    Process {
        id: loadStatsProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "3", aiBackend.baseUrl + "/conversations/stats"]
        stdout: SplitParser { onRead: data => loadStatsProcess.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) { section.statusText = "load failed"; return }
            try {
                let o = JSON.parse(loadStatsProcess.buf)
                section.dbPath = o.path || ""
                section.convCount = o.count || 0
                section.dbSize = o.size_bytes || 0
                section.loaded = true
            } catch (e) {
                section.statusText = "parse failed"
            }
        }
    }

    Process {
        id: loadConfigProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "3", aiBackend.baseUrl + "/config"]
        stdout: SplitParser { onRead: data => loadConfigProcess.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) return
            try {
                let cfg = (JSON.parse(loadConfigProcess.buf).config) || {}
                let rd = (cfg.history && cfg.history.retain_days) || 0
                section.retainDays = rd
                section.savedRetainDays = rd
            } catch (e) {}
        }
    }

    // Apply chain for retain_days: re-fetch config, splice the value in, PUT,
    // restart. The retention prune runs at mugen-ai startup, so applying the
    // setting means bouncing the service.
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
                if (!cfg.history) cfg.history = {}
                cfg.history.retain_days = section.retainDays
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
            section.savedRetainDays = section.retainDays
            section.statusText = exitCode === 0 ? "applied — reloading…" : "applied (restart pending)"
            reloadTimer.start()
        }
    }

    Timer {
        id: reloadTimer
        // mugen-ai needs a beat to come back up after the restart; reload the
        // stats once it should be listening again (a prune may have run).
        interval: 4000
        onTriggered: {
            loadStatsProcess.running = true
            loadConfigProcess.running = true
        }
    }

    Process {
        id: exportProcess
        running: false
        property string outPath: ""
        command: ["curl", "-sS", "--max-time", "20", "-o", outPath,
                  aiBackend.baseUrl + "/conversations/export"]
        onExited: (exitCode) => {
            section.statusText = exitCode === 0
                ? "exported to " + exportProcess.outPath
                : "export failed"
        }
    }

    Process {
        id: clearProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "5",
                  "-X", "DELETE", aiBackend.baseUrl + "/conversations"]
        stdout: SplitParser { onRead: data => clearProcess.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode === 0 && clearProcess.buf.indexOf("cleared") >= 0) {
                section.statusText = "all conversations cleared"
                loadStatsProcess.running = true
            } else {
                section.statusText = "clear failed"
            }
        }
    }

    Component.onCompleted: {
        loadStatsProcess.running = true
        loadConfigProcess.running = true
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
                text: "Conversation history"
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
            text: "Conversations are stored locally in SQLite. Export keeps a JSON backup; auto-delete prunes idle conversations on the next mugen-ai start."
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            opacity: 0.65
            wrapMode: Text.WordWrap
        }

        // Stats block.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: statsCol.implicitHeight + 16
            radius: 10
            color: section.theme ? section.theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.3)
            border.width: 1
            border.color: section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.12)

            ColumnLayout {
                id: statsCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 8
                spacing: 4

                Repeater {
                    model: [
                        { k: "Conversations", v: section.loaded ? String(section.convCount) : "—" },
                        { k: "Database size", v: section.loaded ? section.fmtSize(section.dbSize) : "—" }
                    ]

                    RowLayout {
                        id: statRow
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: statRow.modelData.k
                            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
                            font.pixelSize: 11
                            font.family: "M PLUS 2"
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: statRow.modelData.v
                            color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95)
                            font.pixelSize: 11
                            font.family: "M PLUS 2"
                            font.weight: Font.Medium
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    text: "Storage"
                    color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                }

                Text {
                    Layout.fillWidth: true
                    text: section.dbPath || "—"
                    color: section.theme ? section.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.65)
                    font.pixelSize: 10
                    font.family: "M PLUS 2"
                    wrapMode: Text.WrapAnywhere
                }
            }
        }

        // Auto-delete retention.
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: "Auto-delete conversations idle longer than"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85)
            font.pixelSize: 11
            font.family: "M PLUS 2"
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: section.retainPresets

                Rectangle {
                    id: presetChip
                    required property int modelData
                    readonly property bool selected: section.retainDays === modelData

                    width: chipLabel.implicitWidth + 22
                    height: 26
                    radius: 13
                    color: presetChip.selected
                        ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                        : (chipMouse.containsMouse ? Qt.rgba(0.55, 0.55, 0.65, 0.30) : Qt.rgba(0.55, 0.55, 0.65, 0.16))
                    border.width: 1
                    border.color: presetChip.selected
                        ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95))
                        : Qt.rgba(1, 1, 1, 0.10)
                    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                    Text {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: section.retainLabel(presetChip.modelData)
                        color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.92)
                        font.pixelSize: 10
                        font.family: "M PLUS 2"
                        font.weight: presetChip.selected ? Font.Medium : Font.Normal
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { section.retainDays = presetChip.modelData; section.bump() }
                    }
                }
            }
        }

        // Apply (only while the retention value has an unsaved change).
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            visible: section.retainDirty || section.saving
            radius: 10
            enabled: section.retainDirty && !section.saving
            opacity: enabled ? 1.0 : 0.6
            color: applyMouse.containsMouse
                ? Qt.rgba(0.45, 0.65, 0.90, 0.45)
                : Qt.rgba(0.45, 0.65, 0.90, 0.3)
            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

            Text {
                anchors.centerIn: parent
                text: section.saving ? "…" : "Apply — restarts mugen-ai"
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: 11
                font.family: "M PLUS 2"
                font.weight: Font.Medium
            }

            MouseArea {
                id: applyMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: section.retainDirty && !section.saving
                cursorShape: Qt.PointingHandCursor
                onClicked: { section.applyRetention(); section.bump() }
            }
        }

        // Export / Clear actions.
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8
            visible: !section.confirmingClear

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 10
                color: exportMouse.containsMouse ? Qt.rgba(0.55, 0.55, 0.65, 0.32) : Qt.rgba(0.55, 0.55, 0.65, 0.20)
                border.width: 1
                border.color: section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.12)
                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                Text {
                    anchors.centerIn: parent
                    text: "Export all"
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                }

                MouseArea {
                    id: exportMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { section.doExport(); section.bump() }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 10
                enabled: section.convCount > 0
                opacity: enabled ? 1.0 : 0.5
                color: clearMouse.containsMouse ? Qt.rgba(0.85, 0.42, 0.42, 0.30) : Qt.rgba(0.85, 0.42, 0.42, 0.16)
                border.width: 1
                border.color: Qt.rgba(0.88, 0.50, 0.50, 0.40)
                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                Text {
                    anchors.centerIn: parent
                    text: "Clear all"
                    color: Qt.rgba(0.96, 0.79, 0.79, 0.95)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: section.convCount > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { section.confirmingClear = true; section.bump() }
                }
            }
        }

        // Clear-all confirm step.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: confirmCol.implicitHeight + 16
            visible: section.confirmingClear
            radius: 10
            color: Qt.rgba(0.85, 0.42, 0.42, 0.12)
            border.width: 1
            border.color: Qt.rgba(0.88, 0.50, 0.50, 0.45)

            ColumnLayout {
                id: confirmCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 8
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Delete all " + section.convCount + " conversation"
                        + (section.convCount === 1 ? "" : "s") + "? This cannot be undone."
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 76
                        Layout.preferredHeight: 28
                        radius: 14
                        color: cancelMouse.containsMouse ? Qt.rgba(0.55, 0.55, 0.65, 0.32) : Qt.rgba(0.55, 0.55, 0.65, 0.22)
                        Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                            font.pixelSize: 11
                            font.family: "M PLUS 2"
                        }

                        MouseArea {
                            id: cancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { section.confirmingClear = false; section.bump() }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 28
                        radius: 14
                        color: deleteMouse.containsMouse ? Qt.rgba(0.85, 0.42, 0.42, 0.55) : Qt.rgba(0.85, 0.42, 0.42, 0.34)
                        border.width: 1
                        border.color: Qt.rgba(0.88, 0.50, 0.50, 0.60)
                        Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                        Text {
                            anchors.centerIn: parent
                            text: "Delete all"
                            color: Qt.rgba(0.98, 0.88, 0.88, 0.98)
                            font.pixelSize: 11
                            font.family: "M PLUS 2"
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: deleteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { section.doClear(); section.bump() }
                        }
                    }
                }
            }
        }

        // Status line + Refresh.
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
                    onClicked: {
                        loadStatsProcess.running = true
                        loadConfigProcess.running = true
                        section.bump()
                    }
                }
            }
        }
    }
}
