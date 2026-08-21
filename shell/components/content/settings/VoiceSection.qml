import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../common" as Common
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    width: parent ? parent.width : 420
    height: contentColumn.implicitHeight + 24
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    readonly property var speedOptions: [0.9, 1.0, 1.1, 1.2]

    // Values carry an engine prefix ("aivis:<id>" | "local:<model-dir>") to match voice.tts.
    property var voices: []
    property bool voiceExpanded: false

    readonly property var voiceOptions: section.editingLang === ""
        ? section.voices
        : [{ label: "Same as Default", value: "" }, ...section.voices]

    // "" edits voice.tts (used when no override matches); a language code edits voice.ttsByLang[code].
    readonly property var langOptions: ["", "ja", "en"]
    // Bound, never assigned: settings arrive asynchronously, so a read at creation gets the default.
    readonly property string editingLang: settingsManager ? settingsManager.voiceEditingLang : ""

    function langLabel(code) {
        return code === "" ? "Default" : code.toUpperCase()
    }

    function voiceFor(lang) {
        if (!settingsManager) return ""
        if (lang === "") return settingsManager.voiceTts
        const map = settingsManager.voiceTtsByLang || ({})
        return map[lang] || ""
    }

    function applyVoice(lang, value) {
        if (!settingsManager) return
        if (lang === "") {
            settingsManager.voiceTts = value
        } else {
            // Reassign rather than mutate: a var property doesn't notify on an in-place key write.
            let map = Object.assign({}, settingsManager.voiceTtsByLang || ({}))
            map[lang] = value
            settingsManager.voiceTtsByLang = map
        }
        save()
    }

    function clearVoice(lang) {
        if (!settingsManager || lang === "") return
        let map = Object.assign({}, settingsManager.voiceTtsByLang || ({}))
        delete map[lang]
        settingsManager.voiceTtsByLang = map
        save()
    }

    function voiceLabel() {
        const value = voiceFor(section.editingLang)
        if (value === "") return section.editingLang === "" ? "Automatic" : "Same as Default"
        for (const v of voices) {
            if (v.value === value) return v.label
        }
        return value
    }

    Process {
        id: voicesProc
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "4",
                  "--unix-socket", Theme.YuraCtl.socket,
                  "http://localhost/voices"]

        stdout: StdioCollector { onStreamFinished: voicesProc.buf = text }
        onRunningChanged: { if (running) buf = "" }

        onExited: (exitCode) => {
            if (exitCode !== 0) return
            try {
                section.voices = JSON.parse(voicesProc.buf).voices || []
            } catch (e) {}
        }
    }

    Component.onCompleted: {
        voicesProc.running = true
    }

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function save() {
        if (settingsManager) settingsManager.saveSettings()
        section.bump()
    }

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Common.SettingLabel { theme: section.theme;
                title: "Read aloud"
                desc: "Speaking replies out loud; off stops the daemon entirely"
            }

            Common.Switch {
                Layout.alignment: Qt.AlignVCenter
                theme: section.theme
                checked: section.settingsManager ? section.settingsManager.voiceEnabled : true
                onToggled: value => {
                    if (!section.settingsManager) return
                    section.settingsManager.voiceEnabled = value
                    section.save()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Common.SettingLabel { theme: section.theme;
                title: "Voice per language"
                desc: "Which language the voice below applies to"
            }

            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: section.langOptions

                    Common.Chip { theme: section.theme;
                        required property string modelData
                        label: section.langLabel(modelData)
                            + (modelData !== "" && section.voiceFor(modelData) !== "" ? " ●" : "")
                        selected: section.editingLang === modelData
                        onClicked: {
                            if (!section.settingsManager) return
                            section.settingsManager.voiceEditingLang = modelData
                            section.save()
                            section.bump()
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: voiceHeader.implicitHeight

            RowLayout {
                id: voiceHeader
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 12

                Common.SettingLabel { theme: section.theme;
                    title: "Voice"
                    desc: section.editingLang === ""
                        ? "Spoken replies in any language without its own voice"
                        : "Spoken replies when the language is " + section.langLabel(section.editingLang)
                }

                Text {
                    text: section.voiceLabel()
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                    opacity: 0.85
                }

                Text {
                    text: section.voiceExpanded ? "▴" : "▾"
                    color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    opacity: 0.7
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    section.voiceExpanded = !section.voiceExpanded
                    section.bump()
                }
            }
        }

        Text {
            visible: section.voiceExpanded && section.voices.length === 0
            text: "No voices found (the voice daemon is not running, or no engine answered)"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            opacity: 0.6
        }

        ListView {
            id: voiceList
            visible: section.voiceExpanded && section.voices.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 220 : 0
            clip: true
            model: section.voiceOptions
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: voiceRow
                required property var modelData
                width: voiceList.width
                height: 30
                radius: 8

                readonly property bool isSelected:
                    section.voiceFor(section.editingLang) === modelData.value

                color: rowMouse.containsMouse
                    ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25))
                    : (isSelected
                        ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4))
                        : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.value === "") {
                            section.clearVoice(section.editingLang)
                        } else {
                            section.applyVoice(section.editingLang, modelData.value)
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: playChip.left
                    anchors.rightMargin: 8
                    text: voiceRow.modelData.label
                    elide: Text.ElideRight
                    color: voiceRow.isSelected
                        ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.85, 1.0, 1.0))
                        : (section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                    font.weight: voiceRow.isSelected ? Font.Medium : Font.Normal
                }

                Rectangle {
                    id: playChip
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 20
                    radius: 10
                    visible: voiceRow.modelData.value !== ""
                        && (rowMouse.containsMouse || playMouse.containsMouse)
                    color: playMouse.containsMouse
                        ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5))
                        : Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: "▶"
                        color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                        font.pixelSize: 9
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: section.preview(voiceRow.modelData.value)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Common.SettingLabel { theme: section.theme;
                title: "Speech speed"
                desc: "Playback rate for spoken replies"
            }

            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: section.speedOptions

                    Common.Chip { theme: section.theme;
                        required property real modelData
                        label: modelData.toFixed(1) + "x"
                        selected: section.settingsManager
                            && Math.abs(section.settingsManager.voiceSpeed - modelData) < 0.05
                        onClicked: {
                            if (!section.settingsManager) return
                            section.settingsManager.voiceSpeed = modelData
                            section.save()
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Common.SettingLabel { theme: section.theme;
                title: "Yura volume"
                desc: "Loudness of spoken replies"
            }

            Common.Slider {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 180
                theme: section.theme
                from: 0.0
                to: 1.0
                stepSize: 0.05
                value: section.settingsManager ? section.settingsManager.voiceVolume : 1.0
                display: Math.round(value * 100) + "%"
                onMoved: nv => {
                    if (section.settingsManager) section.settingsManager.voiceVolume = nv
                }
                onReleased: section.save()
            }
        }

    }
}
