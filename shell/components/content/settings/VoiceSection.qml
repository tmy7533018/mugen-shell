import QtQuick
import QtQuick.Layouts
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

    readonly property var wakeOpenOptions: ["panel", "bar", "none"]
    readonly property var speedOptions: [0.9, 1.0, 1.1, 1.2]

    // One list, two engines: the picked value carries the engine prefix
    // ("voicevox:<style-id>" | "piper:<voice>"), matching voice.tts.
    property var voicevoxVoices: []
    property var aivisVoices: []
    property var piperVoices: []
    readonly property var voices: [...aivisVoices, ...voicevoxVoices, ...piperVoices]
    property bool voiceExpanded: false

    function voiceLabel() {
        const tts = settingsManager ? settingsManager.voiceTts : ""
        for (const v of voices) {
            if (v.value === tts) return v.label
        }
        return tts !== "" ? tts : "voicevox:14"
    }

    // Same env fallbacks as yurad (YURA_PIPER_BIN / YURA_PIPER_VOICES /
    // YURA_VOICEVOX_URL) so the preview follows a relocated engine, and the
    // same -23 loudness target so previews match what yurad will play.
    readonly property string playNormalized:
        'n=$(mktemp --suffix=.wav); ffmpeg -hide_banner -loglevel error -y -i "$w" -af loudnorm=I=-23:TP=-2 "$n" && pw-play "$n"; rm -f "$n"'

    function preview(value) {
        const engine = value.split(":")[0]
        const voice = value.slice(engine.length + 1)
        let script
        if (engine === "piper") {
            if (!/^[A-Za-z0-9._+-]+$/.test(voice)) return
            script = 'w=$(mktemp --suffix=.wav); trap \'rm -f "$w"\' EXIT; '
                + 'echo "Hi! I\'m Yura. How does this voice sound?" | '
                + '"${YURA_PIPER_BIN:-piper}" --model "${YURA_PIPER_VOICES:-$HOME/.local/share/piper/voices}/' + voice + '.onnx" --output_file "$w" && '
                + playNormalized
        } else {
            const enc = encodeURIComponent("こんにちは、ユラだよ。この声はどうかな")
            const base = engine === "aivis"
                ? 'vv="${YURA_AIVIS_URL:-http://127.0.0.1:10101}"; '
                : 'vv="${YURA_VOICEVOX_URL:-http://127.0.0.1:50021}"; '
            script = 'q=$(mktemp); w=$(mktemp --suffix=.wav); trap \'rm -f "$q" "$w"\' EXIT; '
                + base
                + 'curl -s -m 5 -X POST "$vv/audio_query?text=' + enc + '&speaker=' + voice + '" -o "$q" && '
                + 'curl -s -m 20 -X POST "$vv/synthesis?speaker=' + voice + '" -H "Content-Type: application/json" -d @"$q" -o "$w" && '
                + playNormalized
        }
        previewProc.running = false
        previewProc.command = ["bash", "-c", script]
        previewProc.running = true
    }

    Process {
        id: previewProc
        running: false
    }

    Process {
        id: speakersProc
        running: false
        property string buf: ""
        command: ["bash", "-c", "curl -sS --max-time 2 \"${YURA_VOICEVOX_URL:-http://127.0.0.1:50021}/speakers\""]

        stdout: SplitParser { onRead: data => { speakersProc.buf += data } }
        onRunningChanged: { if (running) buf = "" }

        onExited: (exitCode) => {
            if (exitCode !== 0) return
            try {
                let list = []
                for (const sp of JSON.parse(speakersProc.buf)) {
                    for (const st of sp.styles) {
                        list.push({ label: sp.name + " (" + st.name + ")",
                                    value: "voicevox:" + st.id })
                    }
                }
                section.voicevoxVoices = list
            } catch (e) {}
        }
    }

    Process {
        id: aivisProc
        running: false
        property string buf: ""
        command: ["bash", "-c", "curl -sS --max-time 2 \"${YURA_AIVIS_URL:-http://127.0.0.1:10101}/speakers\""]

        stdout: SplitParser { onRead: data => { aivisProc.buf += data } }
        onRunningChanged: { if (running) buf = "" }

        onExited: (exitCode) => {
            if (exitCode !== 0) return
            try {
                let list = []
                for (const sp of JSON.parse(aivisProc.buf)) {
                    for (const st of sp.styles) {
                        list.push({ label: "Aivis: " + sp.name + " (" + st.name + ")",
                                    value: "aivis:" + st.id })
                    }
                }
                section.aivisVoices = list
            } catch (e) {}
        }
    }

    Process {
        id: piperProc
        running: false
        property string buf: ""
        command: ["bash", "-c", "ls -1 \"${YURA_PIPER_VOICES:-$HOME/.local/share/piper/voices}\"/*.onnx 2>/dev/null"]

        stdout: SplitParser { onRead: data => { piperProc.buf += data + "\n" } }
        onRunningChanged: { if (running) buf = "" }

        onExited: () => {
            let list = []
            for (const line of piperProc.buf.split("\n")) {
                const f = line.trim()
                if (!f.endsWith(".onnx")) continue
                const name = f.split("/").pop().replace(/\.onnx$/, "")
                // Names feed the preview's bash line; refuse shell metachars.
                if (!/^[A-Za-z0-9._+-]+$/.test(name)) continue
                list.push({ label: "Piper: " + name, value: "piper:" + name })
            }
            section.piperVoices = list
        }
    }

    Component.onCompleted: {
        speakersProc.running = true
        aivisProc.running = true
        piperProc.running = true
    }

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function save() {
        if (settingsManager) settingsManager.saveSettings()
        section.bump()
    }

    component RowLabel: ColumnLayout {
        property string title: ""
        property string desc: ""
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 2

        Text {
            Layout.fillWidth: true
            text: parent.title
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.letterSpacing: 0.5
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: parent.desc
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            opacity: 0.6
            elide: Text.ElideRight
        }
    }

    component Chip: Rectangle {
        property string label: ""
        property bool selected: false
        signal clicked()

        width: chipText.implicitWidth + 16
        height: 22
        radius: 11
        color: selected
            ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.45) : Qt.rgba(0.65, 0.55, 0.85, 0.45))
            : (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
        border.width: 1
        border.color: selected
            ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95))
            : Qt.rgba(1, 1, 1, 0.10)

        Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: parent.label
            color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            font.pixelSize: 10
            font.family: "M PLUS 2"
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
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

            RowLabel {
                title: "Voice input"
                desc: "Wake word listening; off releases the microphone"
            }

            Common.Switch {
                Layout.alignment: Qt.AlignVCenter
                theme: section.theme
                checked: section.settingsManager ? section.settingsManager.voiceEnabled : true
                onToggled: {
                    if (!section.settingsManager) return
                    section.settingsManager.voiceEnabled = checked
                    section.save()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLabel {
                title: "Follow-up listening"
                desc: "After a reply, keep listening — no wake word needed"
            }

            Common.Switch {
                Layout.alignment: Qt.AlignVCenter
                theme: section.theme
                checked: section.settingsManager ? section.settingsManager.voiceFollowUp : true
                onToggled: {
                    if (!section.settingsManager) return
                    section.settingsManager.voiceFollowUp = checked
                    section.save()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLabel {
                title: "On wake"
                desc: "What opens when Yura hears you"
            }

            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: section.wakeOpenOptions

                    Chip {
                        required property string modelData
                        label: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                        selected: section.settingsManager
                            && section.settingsManager.voiceWakeOpens === modelData
                        onClicked: {
                            if (!section.settingsManager) return
                            section.settingsManager.voiceWakeOpens = modelData
                            section.save()
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

                RowLabel {
                    title: "Voice"
                    desc: "VOICEVOX speaker for spoken replies"
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
            text: "No voices found (VOICEVOX engine down, no Piper voices installed)"
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
            model: section.voices
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData
                width: voiceList.width
                height: 30
                radius: 8

                readonly property bool isSelected: section.settingsManager
                    && section.settingsManager.voiceTts === modelData.value

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
                        if (!section.settingsManager) return
                        section.settingsManager.voiceTts = modelData.value
                        section.save()
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: playChip.left
                    anchors.rightMargin: 8
                    text: parent.modelData.label
                    elide: Text.ElideRight
                    color: parent.isSelected
                        ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.85, 1.0, 1.0))
                        : (section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                    font.weight: parent.isSelected ? Font.Medium : Font.Normal
                }

                Rectangle {
                    id: playChip
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 20
                    radius: 10
                    visible: rowMouse.containsMouse || playMouse.containsMouse
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
                        onClicked: section.preview(parent.parent.modelData.value)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLabel {
                title: "Speech speed"
                desc: "VOICEVOX speedScale for replies"
            }

            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: section.speedOptions

                    Chip {
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

            RowLabel {
                title: "Speech recognition"
                desc: "Whisper language; Auto detects per utterance"
            }

            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: ["auto", "ja", "en"]

                    Chip {
                        required property string modelData
                        label: modelData === "auto" ? "Auto" : modelData.toUpperCase()
                        selected: section.settingsManager
                            && section.settingsManager.voiceSttLang === modelData
                        onClicked: {
                            if (!section.settingsManager) return
                            section.settingsManager.voiceSttLang = modelData
                            section.save()
                        }
                    }
                }
            }
        }
    }
}
