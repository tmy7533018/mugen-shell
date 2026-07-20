import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../common" as Common
import "../../managers" as Managers
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

    // The daemon owns enrollment (SIGRTMIN+2); the verifier pkl is the only
    // "enrolled?" signal across the process boundary.
    property bool enrolling: false
    // mtime (epoch secs), 0 = never registered. mtime rather than existence,
    // so a re-register waits for a NEW file instead of stopping instantly on
    // the previous registration's leftover pkl.
    property real pklMtime: 0
    property real enrollStartTime: 0
    readonly property bool enrolled: pklMtime > 0
    // Mirrors the daemon's .enrolling marker, which clears on every exit path,
    // including an abort that never writes a verifier.
    property bool daemonEnrolling: false
    property bool sawDaemonEnrolling: false

    Managers.MicCavaManager { id: enrollCava }

    Process {
        id: enrollCheck
        command: ["bash", "-c",
            "d=\"$HOME/.local/share/mugen-shell/verifier\"; "
            + "echo \"$(stat -c %Y \"$d/hey_yura_verifier.pkl\" 2>/dev/null || echo 0) "
            + "$(test -e \"$d/.enrolling\" && echo 1 || echo 0)\""]
        stdout: SplitParser {
            onRead: d => {
                const parts = d.trim().split(/\s+/)
                section.pklMtime = parseInt(parts[0]) || 0
                section.daemonEnrolling = parts[1] === "1"
            }
        }
    }

    Process {
        id: enrollStart
        command: ["systemctl", "--user", "kill", "-s", "SIGRTMIN+2",
                  "--kill-whom=main", "yura-voice.service"]
    }

    Process {
        id: enrollCancel
        command: ["systemctl", "--user", "kill", "-s", "SIGUSR2",
                  "--kill-whom=main", "yura-voice.service"]
    }

    // Training lands the pkl a while after the last clip, with no signal back.
    Timer {
        id: enrollPoll
        interval: 2000
        repeat: true
        running: section.enrolling
        onTriggered: {
            enrollCheck.running = true
            if (section.pklMtime > section.enrollStartTime) {
                section.stopEnroll()
            } else if (section.daemonEnrolling) {
                section.sawDaemonEnrolling = true
            } else if (section.sawDaemonEnrolling) {
                // Marker cleared with no new verifier: the daemon aborted.
                // Gated on having seen it, because the daemon only reads the
                // signal between turns — possibly tens of seconds into a
                // reply — and giving up early leaves it recording unattended.
                section.stopEnroll()
            }
        }
    }

    // Enrollment runs minutes at most; never leave the mic tapped forever.
    Timer {
        id: enrollTimeout
        interval: 4 * 60 * 1000
        running: section.enrolling
        onTriggered: section.stopEnroll()
    }

    function startEnroll() {
        section.enrollStartTime = Math.floor(Date.now() / 1000)
        section.daemonEnrolling = false
        section.sawDaemonEnrolling = false
        section.enrolling = true
        enrollCava.start()
        enrollStart.running = true
    }

    function stopEnroll() {
        section.enrolling = false
        enrollCava.stop()
        enrollCheck.running = true
    }

    // Values carry an engine prefix ("voicevox:<style-id>" | "piper:<voice>")
    // to match what voice.tts expects.
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

    // Stored cue values: "" = built-in beep, "none" = silent, anything else
    // is a filename inside soundsDir.
    readonly property string soundsDir: Theme.Paths.soundsDir
    property var cueFiles: []
    readonly property var cueOptions: [
        { label: "Beep (built-in)", value: "" },
        { label: "None", value: "none" },
        ...cueFiles.map(f => ({ label: f, value: f }))
    ]

    function cueValue(key) {
        if (!settingsManager) return ""
        if (key === "soundWake") return settingsManager.voiceSoundWake
        if (key === "soundFollowUp") return settingsManager.voiceSoundFollowUp
        return settingsManager.voiceSoundEnd
    }

    function cueLabel(value) {
        return value === "" ? "Beep" : (value === "none" ? "None" : value)
    }

    function applyCue(key, name) {
        if (!settingsManager) return
        if (key === "soundWake") settingsManager.voiceSoundWake = name
        else if (key === "soundFollowUp") settingsManager.voiceSoundFollowUp = name
        else settingsManager.voiceSoundEnd = name
        save()
        if (name !== "" && name !== "none") {
            cuePreviewProc.running = false
            cuePreviewProc.command = ["paplay", soundsDir + "/" + name]
            cuePreviewProc.running = true
        }
    }

    // Env fallbacks and the -23 loudness target must stay in sync with yurad,
    // or previews drift from what actually gets played.
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
            // Style ids get spliced into the shell line below; only digits
            // may pass.
            if (!/^[0-9]+$/.test(voice)) return
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

    Process {
        id: cueSoundsProc
        running: false
        property string buf: ""
        command: ["sh", "-c", "d=\"" + section.soundsDir + "\"; mkdir -p \"$d\"; ls -1 \"$d\" 2>/dev/null | grep -E '\\.(wav|ogg|mp3|oga|flac)$' || true"]

        stdout: SplitParser { onRead: data => { cueSoundsProc.buf += data + "\n" } }
        onRunningChanged: { if (running) buf = "" }

        onExited: () => {
            let list = []
            for (const line of cueSoundsProc.buf.split("\n")) {
                const f = line.trim()
                if (f !== "") list.push(f)
            }
            section.cueFiles = list
        }
    }

    Process {
        id: cuePreviewProc
        running: false
    }

    Process {
        id: openSoundsFolderProc
        running: false
    }

    Component.onCompleted: {
        speakersProc.running = true
        aivisProc.running = true
        piperProc.running = true
        enrollCheck.running = true
        cueSoundsProc.running = true
    }

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function save() {
        if (settingsManager) settingsManager.saveSettings()
        section.bump()
    }

    component SoundPicker: ColumnLayout {
        id: picker
        property string title: ""
        property string desc: ""
        property string settingKey: ""
        // Bound by each instance: section.cueOptions resolves as undefined
        // from inside an inline component.
        property var options: []
        property bool expanded: false
        Layout.fillWidth: true
        spacing: 8

        Item {
            Layout.fillWidth: true
            implicitHeight: pickerHeader.implicitHeight

            RowLayout {
                id: pickerHeader
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 12

                Common.SettingLabel { theme: section.theme;
                    title: picker.title
                    desc: picker.desc
                }

                Text {
                    Layout.maximumWidth: 180
                    text: section.cueLabel(section.cueValue(picker.settingKey))
                    elide: Text.ElideMiddle
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                    opacity: 0.85
                }

                Text {
                    text: picker.expanded ? "▴" : "▾"
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
                    picker.expanded = !picker.expanded
                    // Rescan so files dropped in while Settings is open show up.
                    if (picker.expanded) cueSoundsProc.running = true
                    section.bump()
                }
            }
        }

        ListView {
            id: cueList
            visible: picker.expanded
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.min((picker.options || []).length, 5) * 30 : 0
            clip: true
            model: picker.options
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData
                width: cueList.width
                height: 30
                radius: 8

                readonly property bool isSelected:
                    section.cueValue(picker.settingKey) === modelData.value

                color: cueRowMouse.containsMouse
                    ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25))
                    : (isSelected
                        ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4))
                        : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                MouseArea {
                    id: cueRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        section.applyCue(picker.settingKey, modelData.value)
                        picker.expanded = false
                        section.bump()
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    text: parent.modelData.label
                    elide: Text.ElideRight
                    color: parent.isSelected
                        ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.85, 1.0, 1.0))
                        : (section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                    font.weight: parent.isSelected ? Font.Medium : Font.Normal
                }
            }
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

            Common.SettingLabel { theme: section.theme;
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

            Common.SettingLabel { theme: section.theme;
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

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Common.SettingLabel { theme: section.theme;
                    title: "Voice enrollment"
                    desc: section.enrolling
                        ? "Say “Hey Yura” after each beep…"
                        : (section.enrolled
                            ? "Registered — Yura answers only to your voice"
                            : "Teach Yura your voice so others can’t wake it")
                }

                Common.BarVisualizer {
                    visible: section.enrolling
                    Layout.alignment: Qt.AlignVCenter
                    cavaManager: enrollCava
                    barCount: 12
                    barIndices: [15, 12, 9, 6, 3, 0, 1, 4, 7, 10, 13, 14]
                    maxHeightMultipliers: [0.5, 0.65, 0.8, 0.9, 1.0, 1.0, 1.0, 1.0, 0.9, 0.8, 0.65, 0.5]
                    barColor: section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95)
                    baseColor: section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95)
                }

                Common.Chip { theme: section.theme;
                    label: section.enrolling
                        ? "Cancel"
                        : (section.enrolled ? "Re-register" : "Register my voice")
                    selected: section.enrolling
                    onClicked: {
                        if (section.enrolling) {
                            enrollCancel.running = true
                            section.stopEnroll()
                        } else {
                            section.startEnroll()
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Common.SettingLabel { theme: section.theme;
                title: "On wake"
                desc: "What opens when Yura hears you"
            }

            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: section.wakeOpenOptions

                    Common.Chip { theme: section.theme;
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Common.SettingLabel { theme: section.theme;
                title: "Wake sensitivity"
                desc: "Higher rejects more false wakes; lower catches quiet calls"
            }

            Common.Slider {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 180
                theme: section.theme
                from: 0.5
                to: 0.95
                stepSize: 0.01
                value: section.settingsManager ? section.settingsManager.voiceWakeThreshold : 0.85
                display: value.toFixed(2)
                onMoved: nv => {
                    if (section.settingsManager) section.settingsManager.voiceWakeThreshold = nv
                }
                onReleased: section.save()
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

            Common.SettingLabel { theme: section.theme;
                title: "Speech speed"
                desc: "VOICEVOX speedScale for replies"
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Common.SettingLabel { theme: section.theme;
                title: "Speech recognition"
                desc: "Whisper language; Auto detects per utterance"
            }

            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: ["auto", "ja", "en"]

                    Common.Chip { theme: section.theme;
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

        SoundPicker {
            title: "Wake sound"
            desc: "When Yura starts listening"
            settingKey: "soundWake"
            options: section.cueOptions
        }

        SoundPicker {
            title: "Follow-up sound"
            desc: "When the mic reopens after a reply"
            settingKey: "soundFollowUp"
            options: section.cueOptions
        }

        SoundPicker {
            title: "End sound"
            desc: "When listening closes without speech"
            settingKey: "soundEnd"
            options: section.cueOptions
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: 16

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Open sounds folder ↗"
                color: openSoundsMouse.containsMouse
                    ? (section.theme ? section.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                    : (section.theme ? section.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.65))
                font.pixelSize: 11
                font.family: "M PLUS 2"
                font.letterSpacing: 0.5

                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
            }

            MouseArea {
                id: openSoundsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    openSoundsFolderProc.command = ["xdg-open", section.soundsDir]
                    openSoundsFolderProc.running = true
                }
            }
        }
    }
}
