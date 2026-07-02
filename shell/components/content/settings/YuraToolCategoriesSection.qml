import QtQuick
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

    property var disabledSet: ({})
    property int dirtyTick: 0  // bump to re-evaluate bindings that read disabledSet

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
        { id: "memory",       label: "Memory",        desc: "Long-term memory (off hides saved facts too)" }
    ]

    readonly property int expandedHeight: 64 + contentColumn.implicitHeight + 16

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function isEnabled(catId) {
        // Touch dirtyTick so the binding refreshes when we mutate the map.
        let _ = section.dirtyTick
        return !section.disabledSet[catId]
    }

    function setEnabled(catId, on) {
        let next = Object.assign({}, section.disabledSet)
        if (on) delete next[catId]
        else next[catId] = true
        section.disabledSet = next
        section.dirtyTick++
    }

    function summary() {
        if (!loaded) return "loading…"
        let off = 0
        for (let i = 0; i < categories.length; i++) {
            if (disabledSet[categories[i].id]) off++
        }
        let on = categories.length - off
        return on + " / " + categories.length + " enabled"
    }

    Behavior on height {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    Process {
        id: loadProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "3", aiBackend.baseUrl + "/config"]
        stdout: SplitParser { onRead: data => loadProcess.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                section.statusText = "load failed"
                return
            }
            try {
                let obj = JSON.parse(loadProcess.buf)
                let arr = obj.config && obj.config.tools && obj.config.tools.disabled_categories
                    ? obj.config.tools.disabled_categories
                    : []
                let m = {}
                for (let i = 0; i < arr.length; i++) m[arr[i]] = true
                section.disabledSet = m
                section.dirtyTick++
                section.loaded = true
                section.statusText = ""
            } catch (e) {
                section.statusText = "parse failed"
            }
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
                let list = []
                for (let k in section.disabledSet) {
                    if (section.disabledSet[k]) list.push(k)
                }
                cfg.tools.disabled_categories = list
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

    function allOn() {
        section.disabledSet = ({})
        section.dirtyTick++
    }

    function allOff() {
        let m = {}
        for (let i = 0; i < categories.length; i++) m[categories[i].id] = true
        section.disabledSet = m
        section.dirtyTick++
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
                text: "Tool categories"
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Disabled categories disappear from Yura's tool list and are rejected if invoked."
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
                font.pixelSize: 10
                font.family: "M PLUS 2"
                opacity: 0.65
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 24
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
                    onClicked: section.allOn()
                }
            }

            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 24
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
                    onClicked: section.allOff()
                }
            }
        }

        Repeater {
            model: section.categories

            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: parent.parent.modelData.label
                        color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.92)
                        font.pixelSize: 11
                        font.family: "M PLUS 2"
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: parent.parent.modelData.desc
                        color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
                        font.pixelSize: 9
                        font.family: "M PLUS 2"
                        opacity: 0.6
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: pill
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    radius: 10

                    readonly property bool on: section.isEnabled(parent.modelData.id)

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

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: section.setEnabled(parent.parent.modelData.id, !pill.on)
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
