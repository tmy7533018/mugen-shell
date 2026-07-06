import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../lib" as Theme
import "../ui" as UI
import "../common" as Common
import "./ai" as Ai

FocusScope {
    id: root

    required property var modeManager
    property var theme
    property var icons
    property var settingsManager
    property var aiBackend
    property bool isStandalone: false
    // Daemon capture state (over IPC); the mic button becomes a cancel button.
    property bool voiceListening: false

    // Fallback used when no AiBackend is wired (e.g. legacy embedding paths).
    readonly property string _baseUrl: aiBackend ? aiBackend.baseUrl : "http://127.0.0.1:11435"

    // Spotlight-style: normal bar height, wide centered slot.
    readonly property var requiredBarSize: ({
        "height": modeManager.scale(60),
        "leftMargin": modeManager.scale(620),
        "rightMargin": modeManager.scale(620),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })

    property bool streaming: false
    // True while the input pill holds an unsent user draft (or a voice
    // transcript mid-turn) — parked responses don't count. Bar.qml blocks
    // the auto-close timer on this so closing never eats unsent text.
    readonly property bool hasDraft: inputField.text.trim().length > 0 && !displayingResponse
    property bool aiAvailable: false
    property bool hasModel: false
    property bool healthChecked: false
    property string currentModel: ""
    property int currentConvId: 0

    // While streaming, partial reply lives in the placeholder. On done we
    // shove the full text into the input field (read-only) so arrow keys
    // scroll it; the first printable keypress flips back to typing mode.
    property string responseDisplay: ""
    property bool displayingResponse: false

    // Set from a tool_confirm SSE event while the backend is blocked waiting
    // for approval of a destructive MCP tool. Shape: { confirm_id, name,
    // arguments }. While set, a confirm strip covers the input pill.
    property var pendingConfirm: null

    readonly property string idlePlaceholder: {
        if (!healthChecked) return "Ask anything…"
        if (!aiAvailable) return "mugen-ai is not running"
        if (!hasModel) return "No model available"
        return "Ask anything…"
    }
    readonly property bool isThinking: streaming && responseDisplay.length === 0

    readonly property string activePlaceholder: {
        if (isThinking) return "thinking"
        if (responseDisplay.length > 0) {
            // Single-line bar: collapse newlines.
            return responseDisplay.replace(/\s*\n+\s*/g, " ")
        }
        return idlePlaceholder
    }

    function sendMessage(text) {
        if (!text || streaming) return
        if (!aiAvailable || !hasModel) return
        responseDisplay = ""
        displayingResponse = false
        streaming = true
        // Empty string falls back to the backend's registry default.
        let modelChoice = (settingsManager && settingsManager.barAiModel) ? settingsManager.barAiModel : ""
        let thinking = settingsManager ? settingsManager.barThinking : false
        chatProcess.payload = JSON.stringify({
            message: text,
            conversation_id: currentConvId,
            model: modelChoice,
            thinking: thinking
        })
        chatProcess.running = true
    }

    function stopStreaming() {
        if (!streaming) return
        chatProcess.signal(15) // SIGTERM
        streaming = false
        // A stopped turn drops its blocked tool prompt; the backend reads
        // the disconnect as a denial, so the strip goes with it.
        pendingConfirm = null
    }

    // resolveConfirm answers a pending tool-approval prompt so the blocked
    // chat turn can run or skip the tool. Fire-and-forget — a lapsed prompt
    // just 404s harmlessly.
    function resolveConfirm(approved) {
        if (!pendingConfirm) return
        confirmProcess.payload = JSON.stringify({
            confirm_id: pendingConfirm.confirm_id,
            approved: approved
        })
        confirmProcess.running = true
        pendingConfirm = null
    }

    function newChat() {
        if (streaming) stopStreaming()
        currentConvId = 0
        responseDisplay = ""
        displayingResponse = false
        inputField.text = ""
        // Backend auto-creates a conversation on the first user message.
    }

    // Voice mirroring (IPC from yurad): transcript sits in the input field
    // while Yura thinks, then the reply grows sentence-by-sentence in sync
    // with the spoken audio and parks like a typed turn's response.
    function showVoiceInput(text) {
        responseDisplay = ""
        displayingResponse = false
        inputField.text = text
    }

    function showVoiceReply(text) {
        responseDisplay = text
        inputField.text = responseDisplay.replace(/\s*\n+\s*/g, " ")
        inputField.cursorPosition = 0
        displayingResponse = true
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("ai")) {
                // Bar = quick-question entry; long chats live in the float.
                root.newChat()
                healthProcess.running = true
                focusTimer.restart()
            } else {
                if (streaming) stopStreaming()
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (root.aiAvailable) inputField.forceActiveFocus()
        }
    }


    // Click outside the panel to dismiss the AI mode.
    MouseArea {
        anchors.fill: parent
        z: 1.5
        enabled: modeManager.isMode("ai") && !root.isStandalone
        visible: enabled
        hoverEnabled: true
        onClicked: modeManager.closeAllModes()
        onPositionChanged: {
            if (modeManager.isMode("ai")) modeManager.bump()
        }
    }

    Item {
        id: panel
        anchors.fill: parent
        // Sit inside the rounded bar surface (requiredBarSize.leftMargin + 20).
        anchors.leftMargin: modeManager.scale(640)
        anchors.rightMargin: modeManager.scale(640)
        z: 3
        opacity: 0
        visible: true

        states: State {
            name: "visible"
            when: modeManager.isMode("ai")
            PropertyChanges { target: panel; opacity: 1.0 }
        }

        transitions: [
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: Theme.Motion.fast }
                    NumberAnimation { property: "opacity"; duration: Theme.Motion.standard; easing.type: Easing.InOutCubic }
                }
            },
            Transition {
                from: "visible"
                to: ""
                NumberAnimation { property: "opacity"; duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
            }
        ]

        RowLayout {
            anchors.fill: parent
            anchors.topMargin: modeManager.scale(8)
            anchors.bottomMargin: modeManager.scale(8)
            spacing: modeManager.scale(12)

            // Click to detach into Yura's corner-popup window.
            Item {
                id: orbSlot
                Layout.preferredWidth: modeManager.scale(36)
                Layout.preferredHeight: modeManager.scale(36)
                Layout.alignment: Qt.AlignVCenter

                Ai.AmbientOrb {
                    anchors.fill: parent
                    orbColor: root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                    streaming: root.streaming
                    breathEnabled: root.settingsManager ? root.settingsManager.yuraIdleBreath : true
                    haloScale: 1.25
                    haloOpacity: orbHover.containsMouse ? 0.75 : 0.5
                    corePointCount: 48
                    coreWaveAmplitude: 0.5
                    haloPointCount: 32
                    haloWaveAmplitude: 1.0
                    idleBreathPeak: 1.14
                    idleBreathDuration: 950

                    Behavior on haloOpacity { NumberAnimation { duration: Theme.Motion.fast } }
                }

                MouseArea {
                    id: orbHover
                    anchors.fill: parent
                    anchors.margins: -modeManager.scale(4)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.isStandalone
                    onClicked: {
                        // Capture screen coords before closeAllModes starts
                        // shrinking the bar. The bar window sits at the screen
                        // origin and the yura window ignores exclusion zones,
                        // so window coords map 1:1 between the two.
                        const p = orbSlot.mapToItem(null, 0, 0)
                        modeManager.closeAllModes()
                        Hyprland.dispatch("exec qs -p ~/.config/quickshell/mugen-shell/yura-shell.qml ipc call yura toggleFrom "
                            + Math.round(p.x) + " " + Math.round(p.y) + " " + Math.round(orbSlot.width))
                    }
                }
            }

            Rectangle {
                id: inputPill
                Layout.fillWidth: true
                Layout.preferredHeight: modeManager.scale(40)
                Layout.alignment: Qt.AlignVCenter
                radius: height / 2
                color: root.theme ? Qt.rgba(0.04, 0.03, 0.10, 0.55) : Qt.rgba(0.04, 0.03, 0.10, 0.55)
                border.color: inputField.activeFocus
                    ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                    : Qt.rgba(0.55, 0.55, 0.75, 0.18)
                border.width: 1

                Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

                TextInput {
                    id: inputField
                    anchors.left: parent.left
                    // Invisible items keep their geometry, so skip the mic
                    // slot when voice input is switched off.
                    anchors.right: micIcon.visible ? micIcon.left : sendIcon.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: modeManager.scale(20)
                    anchors.rightMargin: modeManager.scale(8)
                    color: root.displayingResponse
                        ? (root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.92))
                        : (root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))
                    font.pixelSize: modeManager.scale(14)
                    font.family: "M PLUS 2"
                    font.letterSpacing: 0.3
                    selectByMouse: true
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    inputMethodHints: Qt.ImhNone
                    enabled: root.aiAvailable && root.hasModel && !root.streaming
                    readOnly: root.displayingResponse
                    cursorVisible: true

                    // Single-char arrow moves rarely scroll the 1-row view; jump in chunks.
                    readonly property int navStep: 25

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            modeManager.closeAllModes()
                            event.accepted = true
                            return
                        }

                        if (root.displayingResponse) {
                            // Scrolling a parked reply is reading, not idleness:
                            // keep the auto-close countdown from firing mid-read.
                            modeManager.bump()
                            let pos = inputField.cursorPosition
                            let len = inputField.text.length
                            if (event.key === Qt.Key_Left) {
                                inputField.cursorPosition = Math.max(0, pos - inputField.navStep)
                                event.accepted = true
                                return
                            }
                            if (event.key === Qt.Key_Right) {
                                inputField.cursorPosition = Math.min(len, pos + inputField.navStep)
                                event.accepted = true
                                return
                            }
                            if (event.key === Qt.Key_Home || event.key === Qt.Key_PageUp) {
                                inputField.cursorPosition = 0
                                event.accepted = true
                                return
                            }
                            if (event.key === Qt.Key_End || event.key === Qt.Key_PageDown) {
                                inputField.cursorPosition = len
                                event.accepted = true
                                return
                            }
                            if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                                event.accepted = true
                                return
                            }
                            if (event.modifiers & Qt.ControlModifier) {
                                if (event.key === Qt.Key_C) {
                                    inputField.copy()
                                    event.accepted = true
                                    return
                                }
                                if (event.key === Qt.Key_A) {
                                    inputField.selectAll()
                                    event.accepted = true
                                    return
                                }
                            }
                            // Ignore modifier-only / function keys (event.text is empty).
                            if (!event.text || event.text.length === 0) {
                                event.accepted = true
                                return
                            }
                            inputField.text = event.text
                            inputField.cursorPosition = inputField.text.length
                            root.displayingResponse = false
                            root.responseDisplay = ""
                            event.accepted = true
                            return
                        }

                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            let txt = inputField.text.trim()
                            if (txt.length > 0 && !root.streaming) {
                                root.sendMessage(txt)
                                inputField.text = ""
                            }
                            event.accepted = true
                        }
                    }

                    Common.GlowText {
                        id: placeholderText
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: root.activePlaceholder
                        color: root.responseDisplay.length > 0 || root.streaming
                            ? (root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.92))
                            : (root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.6))
                        font.pixelSize: root.isThinking
                            ? modeManager.scale(15)
                            : parent.font.pixelSize
                        font.family: "M PLUS 2"
                        font.weight: Font.Light
                        font.letterSpacing: root.isThinking ? 1.2 : 0.3
                        font.italic: !(root.responseDisplay.length > 0 && !root.isThinking)
                        // Streaming: ElideLeft keeps the latest chunk visible.
                        elide: root.streaming && root.responseDisplay.length > 0
                            ? Text.ElideLeft
                            : Text.ElideRight
                        // Hide during IME preedit, otherwise it overlaps half-typed CJK.
                        visible: parent.text.length === 0
                            && parent.preeditText.length === 0
                            && !parent.inputMethodComposing

                        enableGlow: root.isThinking
                        glowColor: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55)
                        glowSamples: 18
                        glowRadius: 8
                        glowSpread: 0.35

                        Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
                        Behavior on font.letterSpacing { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }

                        SequentialAnimation on opacity {
                            id: breathAnim
                            loops: Animation.Infinite
                            running: root.isThinking
                            NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                        }
                        Connections {
                            target: breathAnim
                            function onRunningChanged() {
                                if (!breathAnim.running) placeholderText.opacity = 1.0
                            }
                        }
                    }
                }

                // Same push-to-talk / cancel control as the float panel.
                Item {
                    id: micIcon
                    anchors.right: sendIcon.left
                    anchors.rightMargin: modeManager.scale(4)
                    anchors.verticalCenter: parent.verticalCenter
                    width: modeManager.scale(28)
                    height: modeManager.scale(28)
                    visible: !root.settingsManager || root.settingsManager.voiceEnabled
                    opacity: (root.voiceListening || micHover.hovered) ? 1.0 : 0.5

                    Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: (root.voiceListening || micHover.hovered)
                            ? (root.theme ? Qt.rgba(root.theme.glowSecondary.r, root.theme.glowSecondary.g, root.theme.glowSecondary.b, 0.32) : Qt.rgba(0.55, 0.75, 0.85, 0.32))
                            : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
                    }

                    UI.SvgIcon {
                        anchors.centerIn: parent
                        width: modeManager.scale(15)
                        height: modeManager.scale(15)
                        source: root.icons ? root.icons.micSvg : ""
                        color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                        visible: !root.voiceListening
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                        font.pixelSize: modeManager.scale(12)
                        font.family: "M PLUS 2"
                        visible: root.voiceListening
                    }

                    HoverHandler {
                        id: micHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // main only — the broadcast default would signal
                            // the whisper-server child too, which dies on it.
                            Quickshell.execDetached(["systemctl", "--user", "kill",
                                "-s", root.voiceListening ? "SIGUSR2" : "SIGUSR1",
                                "--kill-whom=main", "yura-voice.service"])
                        }
                    }
                }

                Item {
                    id: sendIcon
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: modeManager.scale(6)
                    width: modeManager.scale(28)
                    height: modeManager.scale(28)
                    opacity: root.displayingResponse
                        ? 0.0
                        : ((root.streaming || inputField.text.trim().length > 0) ? 1.0 : 0.4)
                    visible: opacity > 0

                    Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: sendMouse.containsMouse
                            ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4))
                            : (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.22) : Qt.rgba(0.65, 0.55, 0.85, 0.22))

                        Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.streaming ? "■" : "→"
                        color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                        font.pixelSize: modeManager.scale(root.streaming ? 11 : 14)
                        font.family: "M PLUS 2"
                    }

                    MouseArea {
                        id: sendMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.streaming) {
                                root.stopStreaming()
                            } else {
                                let txt = inputField.text.trim()
                                if (txt.length > 0) {
                                    root.sendMessage(txt)
                                    inputField.text = ""
                                }
                            }
                        }
                    }
                }

                // Tool-approval strip — covers the input pill while the
                // backend is blocked on a destructive MCP tool. Approve /
                // Deny answers it; the args are summarised on one line.
                Rectangle {
                    id: confirmStrip
                    anchors.fill: parent
                    radius: parent.radius
                    visible: root.pendingConfirm !== null
                    color: Qt.rgba(0.06, 0.05, 0.11, 0.93)
                    border.width: 1
                    border.color: Qt.rgba(0.95, 0.74, 0.42, 0.60)

                    readonly property var pc: root.pendingConfirm || ({})
                    readonly property string fullName: pc.name || ""
                    readonly property int sep: fullName.indexOf("__")
                    readonly property string serverName: sep > 0 ? fullName.substring(0, sep) : ""
                    readonly property string toolName: sep > 0 ? fullName.substring(sep + 2) : fullName
                    readonly property string argSummary: {
                        let a = pc.arguments
                        if (!a) return ""
                        let parts = []
                        for (let k of Object.keys(a)) {
                            let v = a[k]
                            parts.push(k + ": " + ((typeof v === "string") ? v : JSON.stringify(v)))
                        }
                        return parts.join("   ·   ")
                    }

                    // Eats stray clicks so they can't fall through to the
                    // disabled input or the stop button beneath the strip.
                    MouseArea { anchors.fill: parent }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: modeManager.scale(16)
                        anchors.rightMargin: modeManager.scale(6)
                        spacing: modeManager.scale(8)

                        Text {
                            text: "⚠"
                            color: Qt.rgba(0.96, 0.78, 0.46, 0.95)
                            font.pixelSize: modeManager.scale(14)
                        }

                        Text {
                            text: confirmStrip.serverName !== ""
                                ? (confirmStrip.serverName + " → " + confirmStrip.toolName)
                                : confirmStrip.toolName
                            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                            font.pixelSize: modeManager.scale(13)
                            font.family: "M PLUS 2"
                            font.weight: Font.Medium
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: confirmStrip.argSummary
                            color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.70)
                            font.pixelSize: modeManager.scale(11)
                            font.family: "M PLUS 2"
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: modeManager.scale(62)
                            Layout.preferredHeight: modeManager.scale(28)
                            Layout.alignment: Qt.AlignVCenter
                            radius: height / 2
                            color: denyMouse.containsMouse ? Qt.rgba(0.85, 0.42, 0.42, 0.32) : Qt.rgba(0.85, 0.42, 0.42, 0.16)
                            border.width: 1
                            border.color: Qt.rgba(0.88, 0.50, 0.50, 0.45)
                            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                            Text {
                                anchors.centerIn: parent
                                text: "Deny"
                                color: Qt.rgba(0.96, 0.79, 0.79, 0.95)
                                font.pixelSize: modeManager.scale(11)
                                font.family: "M PLUS 2"
                            }

                            MouseArea {
                                id: denyMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.resolveConfirm(false)
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: modeManager.scale(78)
                            Layout.preferredHeight: modeManager.scale(28)
                            Layout.alignment: Qt.AlignVCenter
                            radius: height / 2
                            color: approveMouse.containsMouse
                                ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                                : (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.32) : Qt.rgba(0.65, 0.55, 0.85, 0.32))
                            border.width: 1
                            border.color: root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                            Text {
                                anchors.centerIn: parent
                                text: "Approve"
                                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.96, 0.95, 1.0, 0.98)
                                font.pixelSize: modeManager.scale(11)
                                font.family: "M PLUS 2"
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: approveMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.resolveConfirm(true)
                            }
                        }
                    }
                }
            }

        }
    }

    // Posts an approval decision for a pending tool_confirm prompt.
    Process {
        id: confirmProcess
        property string payload: ""
        running: false
        command: ["curl", "-sS", "--max-time", "5", "-X", "POST",
                  root._baseUrl + "/chat/confirm",
                  "-H", "Content-Type: application/json",
                  "-d", payload]
    }

    Process {
        id: chatProcess
        property string payload: ""
        running: false
        command: ["curl", "-sS", "-N", "-X", "POST",
                  root._baseUrl + "/chat",
                  "-H", "Content-Type: application/json",
                  "-d", payload]

        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                let line = data.trim()
                if (!line.startsWith("data:")) return
                let jsonStr = line.substring(5).trim()
                if (!jsonStr) return
                try {
                    let obj = JSON.parse(jsonStr)
                    if (obj.conversation_id !== undefined) {
                        root.currentConvId = obj.conversation_id
                        return
                    }
                    if (obj.error) {
                        root.responseDisplay = "[error: " + obj.error + "]"
                        return
                    }
                    // A destructive MCP tool blocks the turn until approved;
                    // the strip must show even on the one-line bar.
                    if (obj.tool_confirm) {
                        root.pendingConfirm = obj.tool_confirm
                        return
                    }
                    // bar Spotlight is a one-line UX; tool calls / results
                    // are dropped here — the LLM's surrounding text already
                    // narrates the action ("音量を 30 にしたよ"). The
                    // floating AI surfaces them as chips instead.
                    if (obj.tool_calls || obj.tool_result) {
                        return
                    }
                    if (obj.content) {
                        root.responseDisplay += obj.content
                    }
                } catch (e) {}
            }
        }

        onExited: (exitCode) => {
            root.streaming = false
            // The stream can end (timeout, error) with the strip still up;
            // never leave a prompt the backend has already abandoned.
            root.pendingConfirm = null
            if (exitCode !== 0 && root.responseDisplay.length === 0) {
                root.responseDisplay = "[connection failed]"
            }
            // Park the response in the input field so it can be scrolled / copied.
            if (root.responseDisplay.length > 0) {
                inputField.text = root.responseDisplay.replace(/\s*\n+\s*/g, " ")
                inputField.cursorPosition = 0
                root.displayingResponse = true
                inputField.forceActiveFocus()
            }
        }
    }

    Process {
        id: healthProcess
        running: false
        property string buf: ""
        command: ["curl", "-sSf", "--max-time", "2", root._baseUrl + "/health"]

        stdout: SplitParser { onRead: data => { healthProcess.buf += data } }
        onRunningChanged: { if (running) buf = "" }

        onExited: (exitCode) => {
            root.aiAvailable = (exitCode === 0)
            root.healthChecked = true
            if (exitCode === 0) {
                try {
                    let obj = JSON.parse(buf)
                    root.currentModel = obj.model || ""
                    root.hasModel = obj.status === "ok"
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("ai", root)
            if (modeManager.isMode("ai")) {
                healthProcess.running = true
                focusTimer.restart()
            }
        }
    }
}
