import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../ui" as UI
import "../common" as Common
import "./ai" as Ai

FocusScope {
    id: root

    required property var modeManager
    property var theme
    property var icons
    property bool isStandalone: false

    // Spotlight-style: keep the bar at its normal height, just give the AI mode
    // a centered horizontal slot wide enough for a sentence or two.
    readonly property var requiredBarSize: ({
        "height": modeManager.scale(60),
        "leftMargin": modeManager.scale(620),
        "rightMargin": modeManager.scale(620),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })

    property bool streaming: false
    property bool aiAvailable: false
    property bool hasModel: false
    property bool healthChecked: false
    property string currentModel: ""
    property int currentConvId: 0

    // While streaming, the partial response goes into responseDisplay and is
    // shown in the placeholder. Once the stream completes we move the full
    // response into the input field itself (read-only) so the user can scroll
    // through long replies with arrow keys / Home / End and copy with Ctrl+C.
    // The first non-navigation keypress clears it back into typing mode.
    property string responseDisplay: ""
    property bool displayingResponse: false

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
            // Bar AI is single-line: collapse newlines so the text flows
            // horizontally rather than wrapping or pushing layout downward.
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
        chatProcess.payload = JSON.stringify({
            message: text,
            conversation_id: currentConvId
        })
        chatProcess.running = true
    }

    function stopStreaming() {
        if (!streaming) return
        chatProcess.signal(15) // SIGTERM
        streaming = false
    }

    function newChat() {
        if (streaming) stopStreaming()
        currentConvId = 0
        responseDisplay = ""
        displayingResponse = false
        inputField.text = ""
        // Backend auto-creates a conversation on the first user message.
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("ai")) {
                // Bar AI is the "quick question" entry point — always open as a
                // fresh blank chat. Long-running conversations live in the float
                // window where the sidebar exposes history.
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
        // Match the bar surface inset (requiredBarSize.leftMargin) so the row
        // sits inside the rounded visual bar instead of overflowing it.
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
                    PauseAnimation { duration: 200 }
                    NumberAnimation { property: "opacity"; duration: 300; easing.type: Easing.InOutCubic }
                }
            },
            Transition {
                from: "visible"
                to: ""
                NumberAnimation { property: "opacity"; duration: 200; easing.type: Easing.OutCubic }
            }
        ]

        // Single row: orb + input pill + detach icon.
        RowLayout {
            anchors.fill: parent
            anchors.topMargin: modeManager.scale(8)
            anchors.bottomMargin: modeManager.scale(8)
            spacing: modeManager.scale(12)

            // Ambient orb on the left — also a portal: click to detach into the
            // floating window. Hover gently scales it up to hint interactivity.
            Item {
                id: orbSlot
                Layout.preferredWidth: modeManager.scale(36)
                Layout.preferredHeight: modeManager.scale(36)
                Layout.alignment: Qt.AlignVCenter

                Ai.AmbientOrb {
                    anchors.fill: parent
                    orbColor: root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                    streaming: root.streaming
                    haloScale: orbHover.containsMouse ? 1.7 : 1.5
                    haloOpacity: orbHover.containsMouse ? 0.65 : 0.5

                    Behavior on haloScale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on haloOpacity { NumberAnimation { duration: 220 } }
                }

                MouseArea {
                    id: orbHover
                    anchors.fill: parent
                    anchors.margins: -modeManager.scale(4)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.isStandalone
                    onClicked: {
                        modeManager.closeAllModes()
                        Hyprland.dispatch("exec ~/.config/quickshell/mugen-shell/scripts/toggle-ai.sh")
                    }
                }
            }

            // Input pill — TextInput + send button inside a rounded glass rect
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

                Behavior on border.color { ColorAnimation { duration: 200 } }

                TextInput {
                    id: inputField
                    anchors.left: parent.left
                    anchors.right: sendIcon.left
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

                    // Step size for arrow-key navigation while reading a long
                    // response. Per-char moves rarely scroll the visible
                    // window in a 1-row Spotlight, so we jump in chunks for
                    // a more responsive scroll feel.
                    readonly property int navStep: 25

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            modeManager.closeAllModes()
                            event.accepted = true
                            return
                        }

                        if (root.displayingResponse) {
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
                            // Ignore modifier-only / function keys (event.text
                            // is empty for Ctrl, Shift, Alt, F1-F12, etc).
                            if (!event.text || event.text.length === 0) {
                                event.accepted = true
                                return
                            }
                            // Printable key — switch into typing mode and use
                            // this character as the first input.
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
                        // Match the float "What's on your mind?" styling — same
                        // family/weight/letterSpacing — and bump it slightly
                        // when thinking so the bar feels in tune with float.
                        font.pixelSize: root.isThinking
                            ? modeManager.scale(15)
                            : parent.font.pixelSize
                        font.family: "M PLUS 2"
                        font.weight: Font.Light
                        font.letterSpacing: root.isThinking ? 1.2 : 0.3
                        font.italic: !(root.responseDisplay.length > 0 && !root.isThinking)
                        // While streaming, keep the *latest* chunk visible by
                        // eliding from the left so the head turns into "…"
                        // and the tail flows under the cursor.
                        elide: root.streaming && root.responseDisplay.length > 0
                            ? Text.ElideLeft
                            : Text.ElideRight
                        // Hide while the user is composing IME preedit text too,
                        // otherwise the response and the half-typed Japanese
                        // characters render on top of each other.
                        visible: parent.text.length === 0
                            && parent.preeditText.length === 0
                            && !parent.inputMethodComposing

                        enableGlow: root.isThinking
                        glowColor: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55)
                        glowSamples: 18
                        glowRadius: 8
                        glowSpread: 0.35

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on font.letterSpacing { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        // Breath pulse — opacity oscillates while thinking,
                        // syncing with the orb's idle breath rhythm. Snaps back
                        // to 1.0 once the response starts streaming in.
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

                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: sendMouse.containsMouse
                            ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4))
                            : (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.22) : Qt.rgba(0.65, 0.55, 0.85, 0.22))

                        Behavior on color { ColorAnimation { duration: 200 } }
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
            }

        }
    }

    // ── Process objects (chat / health / models / switch / current) ─────
    Process {
        id: chatProcess
        property string payload: ""
        running: false
        command: ["curl", "-sS", "-N", "-X", "POST",
                  "http://127.0.0.1:11435/chat",
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
                    if (obj.content) {
                        root.responseDisplay += obj.content
                    }
                } catch (e) {}
            }
        }

        onExited: (exitCode) => {
            root.streaming = false
            if (exitCode !== 0 && root.responseDisplay.length === 0) {
                root.responseDisplay = "[connection failed]"
            }
            // Move the full response into the input field so the user can
            // scroll, select, and copy it. Any printable keypress flips back
            // into typing mode (handled in inputField.Keys.onPressed).
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
        command: ["curl", "-sSf", "--max-time", "2", "http://127.0.0.1:11435/health"]

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
