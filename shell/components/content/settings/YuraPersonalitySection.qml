import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager

    signal editConfig()
    signal restartService()

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

    property string formName: ""
    property string formTone: ""
    property string formLanguage: ""
    property string formSystemPrompt: ""

    readonly property var toneOptions: ["calm", "friendly", "formal"]
    readonly property var languageOptions: [
        { code: "", name: "Auto — match the user's language" },
        { code: "ja", name: "Japanese (日本語)" },
        { code: "en", name: "English" },
        { code: "zh", name: "Chinese (中文)" },
        { code: "ko", name: "Korean (한국어)" },
        { code: "es", name: "Spanish (Español)" },
        { code: "fr", name: "French (Français)" },
        { code: "de", name: "German (Deutsch)" },
        { code: "it", name: "Italian (Italiano)" },
        { code: "pt", name: "Portuguese (Português)" },
        { code: "ru", name: "Russian (Русский)" },
        { code: "ar", name: "Arabic (العربية)" },
        { code: "hi", name: "Hindi (हिन्दी)" },
        { code: "bn", name: "Bengali (বাংলা)" },
        { code: "id", name: "Indonesian (Bahasa Indonesia)" },
        { code: "ms", name: "Malay (Bahasa Melayu)" },
        { code: "th", name: "Thai (ภาษาไทย)" },
        { code: "vi", name: "Vietnamese (Tiếng Việt)" },
        { code: "tr", name: "Turkish (Türkçe)" },
        { code: "fa", name: "Persian (فارسی)" },
        { code: "ur", name: "Urdu (اردو)" },
        { code: "he", name: "Hebrew (עברית)" },
        { code: "nl", name: "Dutch (Nederlands)" },
        { code: "sv", name: "Swedish (Svenska)" },
        { code: "no", name: "Norwegian (Norsk)" },
        { code: "da", name: "Danish (Dansk)" },
        { code: "fi", name: "Finnish (Suomi)" },
        { code: "is", name: "Icelandic (Íslenska)" },
        { code: "pl", name: "Polish (Polski)" },
        { code: "cs", name: "Czech (Čeština)" },
        { code: "sk", name: "Slovak (Slovenčina)" },
        { code: "hu", name: "Hungarian (Magyar)" },
        { code: "ro", name: "Romanian (Română)" },
        { code: "bg", name: "Bulgarian (Български)" },
        { code: "sr", name: "Serbian (Српски)" },
        { code: "hr", name: "Croatian (Hrvatski)" },
        { code: "sl", name: "Slovenian (Slovenščina)" },
        { code: "uk", name: "Ukrainian (Українська)" },
        { code: "be", name: "Belarusian (Беларуская)" },
        { code: "el", name: "Greek (Ελληνικά)" },
        { code: "mk", name: "Macedonian (Македонски)" },
        { code: "sq", name: "Albanian (Shqip)" },
        { code: "et", name: "Estonian (Eesti)" },
        { code: "lv", name: "Latvian (Latviešu)" },
        { code: "lt", name: "Lithuanian (Lietuvių)" },
        { code: "ca", name: "Catalan (Català)" },
        { code: "gl", name: "Galician (Galego)" },
        { code: "eu", name: "Basque (Euskara)" },
        { code: "ga", name: "Irish (Gaeilge)" },
        { code: "cy", name: "Welsh (Cymraeg)" },
        { code: "mt", name: "Maltese (Malti)" },
        { code: "af", name: "Afrikaans" },
        { code: "sw", name: "Swahili (Kiswahili)" },
        { code: "am", name: "Amharic (አማርኛ)" },
        { code: "yo", name: "Yoruba" },
        { code: "ha", name: "Hausa" },
        { code: "zu", name: "Zulu (isiZulu)" },
        { code: "xh", name: "Xhosa (isiXhosa)" },
        { code: "ig", name: "Igbo" },
        { code: "ta", name: "Tamil (தமிழ்)" },
        { code: "te", name: "Telugu (తెలుగు)" },
        { code: "ml", name: "Malayalam (മലയാളം)" },
        { code: "kn", name: "Kannada (ಕನ್ನಡ)" },
        { code: "mr", name: "Marathi (मराठी)" },
        { code: "gu", name: "Gujarati (ગુજરાતી)" },
        { code: "pa", name: "Punjabi (ਪੰਜਾਬੀ)" },
        { code: "or", name: "Odia (ଓଡ଼ିଆ)" },
        { code: "si", name: "Sinhala (සිංහල)" },
        { code: "ne", name: "Nepali (नेपाली)" },
        { code: "my", name: "Burmese (မြန်မာ)" },
        { code: "km", name: "Khmer (ខ្មែរ)" },
        { code: "lo", name: "Lao (ລາວ)" },
        { code: "ka", name: "Georgian (ქართული)" },
        { code: "hy", name: "Armenian (Հայերեն)" },
        { code: "az", name: "Azerbaijani (Azərbaycan)" },
        { code: "kk", name: "Kazakh (Қазақша)" },
        { code: "ky", name: "Kyrgyz (Кыргызча)" },
        { code: "uz", name: "Uzbek (Oʻzbek)" },
        { code: "mn", name: "Mongolian (Монгол)" },
        { code: "tg", name: "Tajik (Тоҷикӣ)" },
        { code: "tl", name: "Tagalog (Filipino)" },
        { code: "jv", name: "Javanese (Basa Jawa)" },
        { code: "su", name: "Sundanese (Basa Sunda)" },
        { code: "eo", name: "Esperanto" },
        { code: "la", name: "Latin (Latina)" }
    ]
    property string languageFilter: ""
    property bool languageDropdownOpen: false
    readonly property var filteredLanguages: {
        if (!languageFilter) return languageOptions
        let q = languageFilter.toLowerCase()
        return languageOptions.filter(l => l.code.toLowerCase().indexOf(q) >= 0 || l.name.toLowerCase().indexOf(q) >= 0)
    }
    readonly property int languageDropdownExtra: languageDropdownOpen ? 200 : 0
    readonly property int expandedHeight: 64 + 24 + 36 + 12 + 36 + 12 + (28 + languageDropdownExtra) + 12 + 24 + 12 + 160 + 12 + 40 + 16

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
                let p = obj.config && obj.config.personality ? obj.config.personality : {}
                section.formName = p.name || "Yura"
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

    function reload() { loadProcess.running = true }

    function save() {
        if (saveProcess.running) return
        section.saving = true
        section.statusText = "saving…"
        let getReq = getCurrentProcess
        getReq.running = true
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
                if (!cfg.personality) cfg.personality = {}
                cfg.personality.name = section.formName
                cfg.personality.tone = section.formTone
                cfg.personality.language = section.formLanguage
                cfg.personality.system_prompt = section.formSystemPrompt
                saveProcess.payload = JSON.stringify(cfg)
                saveProcess.running = true
            } catch (e) {
                section.saving = false
                section.statusText = "parse failed"
            }
        }
    }

    Component.onCompleted: reload()

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
                text: "Personality"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Normal
                font.letterSpacing: 0.5
            }

            Text {
                text: section.summary()
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: 11
                font.family: "M PLUS 2"
                font.italic: !section.loaded || section.summary() === "not configured"
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
                            color: parent.isSelected
                                ? (section.theme ? section.theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95))
                                : (section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90))
                            font.pixelSize: 11
                            font.family: "M PLUS 2"
                            font.weight: parent.isSelected ? Font.Medium : Font.Normal
                        }

                        MouseArea {
                            id: toneMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: section.formTone = parent.modelData
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.preferredWidth: 80
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 6
                text: "Language"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 11
                font.family: "M PLUS 2"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: 8
                    color: langHeaderMouse.containsMouse
                        ? Qt.rgba(0.45, 0.45, 0.60, 0.2)
                        : "transparent"
                    border.width: 1
                    border.color: section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18)
                    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!section.formLanguage) return "Auto — match the user's language"
                            let opt = section.languageOptions.find(l => l.code === section.formLanguage)
                            return opt ? section.formLanguage + " — " + opt.name : section.formLanguage
                        }
                        color: section.theme ? section.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                        font.pixelSize: 11
                        font.family: "M PLUS 2"
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: section.languageDropdownOpen ? "▴" : "▾"
                        color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                        font.pixelSize: 11
                        font.family: "M PLUS 2"
                        opacity: 0.7
                    }

                    MouseArea {
                        id: langHeaderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            section.languageDropdownOpen = !section.languageDropdownOpen
                            section.bump()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    visible: section.languageDropdownOpen
                    radius: 8
                    color: section.theme ? section.theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.3)
                    border.width: 1
                    border.color: section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18)
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            color: "transparent"
                            radius: 6
                            border.width: 1
                            border.color: filterInput.activeFocus
                                ? (section.theme ? section.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                                : Qt.rgba(1, 1, 1, 0.10)
                            Behavior on border.color { ColorAnimation { duration: Theme.Motion.micro } }

                            TextInput {
                                id: filterInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                text: section.languageFilter
                                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                                selectionColor: section.theme ? Qt.rgba(section.theme.glowPrimary.r, section.theme.glowPrimary.g, section.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                                font.pixelSize: 11
                                font.family: "M PLUS 2"
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                onTextChanged: section.languageFilter = text

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "filter by code or name…"
                                    color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.5)
                                    font: filterInput.font
                                    opacity: filterInput.text.length === 0 ? 0.5 : 0
                                }
                            }
                        }

                        ListView {
                            id: langList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 0
                            model: section.filteredLanguages
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                required property var modelData
                                width: langList.width
                                height: 24
                                radius: 4
                                color: section.formLanguage === modelData.code
                                    ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25))
                                    : (langItemMouse.containsMouse
                                        ? Qt.rgba(1, 1, 1, 0.05)
                                        : "transparent")

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (modelData.code ? modelData.code + " — " : "") + modelData.name
                                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                                    font.pixelSize: 10
                                    font.family: "M PLUS 2"
                                }

                                MouseArea {
                                    id: langItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        section.formLanguage = parent.modelData.code
                                        section.languageDropdownOpen = false
                                        section.languageFilter = ""
                                        section.bump()
                                    }
                                }
                            }
                        }
                    }
                }
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

            Rectangle {
                Layout.preferredWidth: 88
                Layout.preferredHeight: 28
                radius: 14
                color: editMouse.containsMouse
                    ? Qt.rgba(0.55, 0.55, 0.65, 0.32)
                    : Qt.rgba(0.55, 0.55, 0.65, 0.22)
                Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

                Text {
                    anchors.centerIn: parent
                    text: "Edit toml"
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: editMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { section.editConfig(); section.bump() }
                }
            }

            Rectangle {
                Layout.preferredWidth: 88
                Layout.preferredHeight: 28
                radius: 14
                color: restartMouse.containsMouse
                    ? Qt.rgba(0.90, 0.45, 0.55, 0.45)
                    : Qt.rgba(0.90, 0.45, 0.55, 0.3)
                Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

                Text {
                    anchors.centerIn: parent
                    text: "Restart AI"
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: restartMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { section.restartService(); section.bump() }
                }
            }

            Rectangle {
                Layout.preferredWidth: 88
                Layout.preferredHeight: 28
                radius: 14
                enabled: !section.saving
                color: saveMouse.containsMouse
                    ? Qt.rgba(0.45, 0.65, 0.90, 0.45)
                    : Qt.rgba(0.45, 0.65, 0.90, 0.3)
                opacity: section.saving ? 0.5 : 1.0
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
                    enabled: !section.saving
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { section.save(); section.bump() }
                }
            }
        }
    }
}
