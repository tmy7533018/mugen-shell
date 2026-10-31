import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../common" as Common
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager

    signal editConfig()

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
    readonly property bool canSave: loaded && !saving
    property bool saving: false
    property string statusText: ""

    property string formName: ""
    property string formTone: ""
    property string formLanguage: ""
    property string formSystemPrompt: ""

    readonly property var toneOptions: ["calm", "friendly", "formal"]
    YuraLanguageTable { id: languageTable }
    readonly property var languageOptions: languageTable.options
    property string languageFilter: ""
    property bool languageDropdownOpen: false
    readonly property var filteredLanguages: {
        if (!languageFilter) return languageOptions
        let q = languageFilter.toLowerCase()
        return languageOptions.filter(l => l.code.toLowerCase().indexOf(q) >= 0 || l.name.toLowerCase().indexOf(q) >= 0)
    }
    readonly property int expandedHeight: 64 + contentColumn.implicitHeight + 16

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function summary() {
        if (!loaded) return "loading…"
        let parts = []
        if (formName) parts.push(formName)
        if (formTone) parts.push(formTone)
        if (formLanguage) parts.push(formLanguage)
        return parts.length > 0 ? parts.join(" · ") : "not configured"
    }

    Behavior on height {
        NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
    }

    AiCall {
        id: loadProcess
        backend: aiBackend
        path: "/config"
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                section.statusText = "load failed"
                loadRetry.restart()
                return
            }
            try {
                let obj = JSON.parse(loadProcess.buf)
                let p = obj.config && obj.config.personality ? obj.config.personality : {}
                section.formName = p.name || ""
                section.formTone = p.tone || ""
                section.formLanguage = p.language || ""
                section.formSystemPrompt = p.system_prompt || ""
                section.loaded = true
                section.statusText = ""
            } catch (e) {
                section.statusText = "parse failed"
            }
        }
    }

    AiConfigPut {
        id: saveProcess
        backend: aiBackend
        onSavedOk: {
            section.statusText = "saved, applying…"
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
            section.statusText = exitCode === 0 ? "applied" : "applied (restart pending)"
        }
    }

    YuraServiceRestart {
        id: serviceRestartProcess
        onResult: ok => section.statusText = ok ? "restarted" : "restart failed"
    }

    function restartService() {
        if (serviceRestartProcess.running) return
        section.statusText = "restarting mugen-ai…"
        serviceRestartProcess.running = true
    }

    function reload() { loadProcess.running = true }

    // The usual failure is mugen-ai restarting after another section's save, so a retry lands within seconds.
    Timer {
        id: loadRetry
        interval: 3000
        onTriggered: if (!section.loaded) loadProcess.running = true
    }

    // The server merges a partial body, so sending the whole document reverts other sections.
    function savePayload() {
        return JSON.stringify({
            personality: {
                name: section.formName,
                tone: section.formTone,
                language: section.formLanguage,
                system_prompt: section.formSystemPrompt
            }
        })
    }

    // Saving before the config loaded would PUT an empty form over the real one.
    function save() {
        if (!section.loaded || saveProcess.running) return
        section.saving = true
        section.statusText = "saving…"
        saveProcess.payload = savePayload()
        saveProcess.running = true
    }

    Component.onCompleted: reload()

    YuraSectionHeader {
        id: header
        theme: section.theme
        title: "Personality"
        summaryText: section.summary()
        summaryItalic: !section.loaded || section.summary() === "not configured"
        titleElide: Text.ElideNone
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
        spacing: 12
        visible: section.isExpanded

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.preferredWidth: 80
                text: "Name"
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
                border.color: nameInput.activeFocus
                    ? (section.theme ? section.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                    : (section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18))
                Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

                TextInput {
                    id: nameInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    text: section.formName
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                    selectionColor: section.theme ? Qt.rgba(section.theme.glowPrimary.r, section.theme.glowPrimary.g, section.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    onTextChanged: section.formName = text

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Yura"
                        color: section.theme ? section.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                        font: nameInput.font
                        visible: nameInput.text.length === 0 && !nameInput.activeFocus
                        opacity: 0.5
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.preferredWidth: 80
                text: "Tone"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 11
                font.family: "M PLUS 2"
            }

            Row {
                spacing: 6

                Repeater {
                    model: section.toneOptions

                    Rectangle {
                        id: toneChip
                        required property string modelData
                        width: 72
                        height: 28
                        radius: 14

                        readonly property bool isSelected: section.formTone === modelData

                        color: isSelected
                            ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25))
                            : (toneMouse.containsMouse
                                ? (section.theme ? section.theme.chipActiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.2))
                                : "transparent")
                        border.width: 1
                        border.color: isSelected
                            ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
                            : Qt.rgba(1, 1, 1, 0.10)
                        Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                        Behavior on border.color { ColorAnimation { duration: Theme.Motion.micro } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: toneChip.isSelected
                                ? (section.theme ? section.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95))
                                : (section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90))
                            font.pixelSize: 11
                            font.family: "M PLUS 2"
                            font.weight: toneChip.isSelected ? Font.Medium : Font.Normal
                        }

                        MouseArea {
                            id: toneMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: section.formTone = toneChip.modelData
                        }
                    }
                }
            }
        }

        YuraLanguagePicker {
            theme: section.theme
            language: section.formLanguage
            filter: section.languageFilter
            open: section.languageDropdownOpen
            options: section.filteredLanguages
            allOptions: section.languageOptions
            onOpenToggled: {
                section.languageDropdownOpen = !section.languageDropdownOpen
                section.bump()
            }
            onFilterEdited: text => section.languageFilter = text
            onPicked: code => {
                section.formLanguage = code
                section.languageDropdownOpen = false
                section.languageFilter = ""
                section.bump()
            }
        }

        Text {
            Layout.fillWidth: true
            text: "System prompt"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 11
            font.family: "M PLUS 2"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            color: "transparent"
            radius: 10
            border.width: 1
            border.color: promptInput.activeFocus
                ? (section.theme ? section.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                : (section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18))
            Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }
            clip: true

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true

                TextArea {
                    id: promptInput
                    text: section.formSystemPrompt
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                    selectionColor: section.theme ? Qt.rgba(section.theme.glowPrimary.r, section.theme.glowPrimary.g, section.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                    wrapMode: TextEdit.Wrap
                    background: null
                    padding: 0
                    onTextChanged: section.formSystemPrompt = text
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: section.statusText
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
                font.pixelSize: 10
                font.family: "M PLUS 2"
                opacity: section.statusText ? 0.85 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }
            }

            Common.ActionButton {
                theme: section.theme
                label: "Edit toml"
                buttonWidth: 88
                onClicked: { section.editConfig(); section.bump() }
            }

            Common.ActionButton {
                theme: section.theme
                label: "Restart AI"
                buttonWidth: 88
                tint: Qt.rgba(0.90, 0.45, 0.55, 0.30)
                tintHover: Qt.rgba(0.90, 0.45, 0.55, 0.45)
                onClicked: { section.restartService(); section.bump() }
            }

            Rectangle {
                Layout.preferredWidth: 88
                Layout.preferredHeight: 28
                radius: 14
                enabled: section.canSave
                color: saveMouse.containsMouse
                    ? Qt.rgba(0.45, 0.65, 0.90, 0.45)
                    : Qt.rgba(0.45, 0.65, 0.90, 0.3)
                opacity: section.canSave ? 1.0 : 0.5
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
