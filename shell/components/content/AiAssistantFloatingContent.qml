import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../ui" as UI
import "../common" as Common
import "./ai" as Ai

FocusScope {
    id: root

    required property var modeManager
    property var theme
    property var icons
    property var aiBackend
    property var settingsManager
    property bool showInternalOrb: true

    // Orb sizing knobs so external owners (Yura) can scale up without
    // editing the empty-state formula or the active-state base width.
    property real orbEmptyScale: 0.28      // ratio of min(mainPane.w, h)
    property real orbActiveBase: 36        // base px (then modeManager.scale'd)

    // Orb position / size mirrored from the internal Item, expressed in
    // root coordinates (mainPane.x + orb.x). Lets a separate global orb
    // window track the same morph an external client (e.g. Yura) needs.
    readonly property real orbExternalX: orb.x + mainPane.x
    readonly property real orbExternalY: orb.y + mainPane.y
    readonly property real orbExternalSize: orb.width
    readonly property bool orbExternalEmptyState: orb.isInEmptyState

    // Fallback used when no AiBackend is wired (e.g. legacy embedding paths).
    readonly property string _baseUrl: aiBackend ? aiBackend.baseUrl : "http://127.0.0.1:11435"

    property var messages: []
    property bool streaming: false
    property bool aiAvailable: false
    property bool hasModel: false
    property bool healthChecked: false
    property bool userScrolled: false
    property string currentModel: ""
    // The model the *next* new conversation will start with — i.e. the
    // backend registry default. Tracked separately so opening an old chat
    // can show its bound model without clobbering this preference.
    property string defaultModel: ""
    property var availableModels: []
    property bool modelDropdownOpen: false

    property var conversations: []
    property int currentConvId: 0
    property bool sidebarCollapsed: false
    readonly property int sidebarWidth: modeManager.scale(200)

    readonly property bool isEmpty: messages.length === 0
    readonly property var suggestedPrompts: [
        "Help me brainstorm an idea",
        "Explain a concept simply",
        "Write a short poem about the moon"
    ]

    function appendMessage(role, content) {
        let copy = messages.slice()
        copy.push({ role: role, content: content })
        messages = copy
    }

    function updateLastMessage(content) {
        if (messages.length === 0) return
        let copy = messages.slice()
        copy[copy.length - 1] = {
            role: copy[copy.length - 1].role,
            content: copy[copy.length - 1].content + content
        }
        messages = copy
    }

    function sendMessage(text) {
        if (!text || streaming) return
        appendMessage("user", text)
        appendMessage("assistant", "")
        streaming = true
        userScrolled = false
        chatProcess.payload = JSON.stringify({
            message: text,
            conversation_id: currentConvId,
            model: currentModel
        })
        chatProcess.running = true
    }

    function stopStreaming() {
        if (!streaming) return
        chatProcess.signal(15)
        streaming = false
    }

    function newChat() {
        if (streaming) stopStreaming()
        messages = []
        currentConvId = 0
        userScrolled = false
        // Coming back from an old conversation may have left currentModel
        // stuck on that conversation's bound model — restore it to the
        // backend default so the dropdown shows what the next chat will use.
        if (defaultModel !== "") currentModel = defaultModel
        // No backend call — the conversation is auto-created on first user message,
        // so abandoning a blank "New chat" leaves no empty row in the store.
    }

    function selectConversation(convId) {
        if (convId === currentConvId) return
        if (streaming) stopStreaming()
        currentConvId = convId
        messages = []
        userScrolled = false
        selectConvProcess.payload = String(convId)
        selectConvProcess.running = true
    }

    function deleteConversation(convId) {
        deleteConvProcess.payload = String(convId)
        deleteConvProcess.running = true
    }

    function refreshConversations() {
        listConvProcess.running = true
    }

    function loadCurrentConversation() {
        if (streaming) return
        loadCurrentProcess.running = true
    }

    // Split on ``` — even parts are markdown prose, odd parts are code
    // blocks. An unclosed ``` mid-stream still renders as a code block so
    // partial code shows up immediately.
    function parseBlocks(content) {
        if (!content) return []
        let blocks = []
        let parts = content.split("```")
        for (let i = 0; i < parts.length; i++) {
            let part = parts[i]
            if (i % 2 === 0) {
                if (part.length > 0) blocks.push({ type: "text", content: part })
            } else {
                let nl = part.indexOf("\n")
                let lang = ""
                let body = part
                if (nl >= 0) {
                    let firstLine = part.substring(0, nl).trim()
                    if (/^[a-zA-Z0-9_+\-]*$/.test(firstLine)) {
                        lang = firstLine
                        body = part.substring(nl + 1)
                    }
                }
                if (body.endsWith("\n")) body = body.substring(0, body.length - 1)
                blocks.push({ type: "code", lang: lang, content: body })
            }
        }
        return blocks
    }

    Timer {
        id: focusTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (root.aiAvailable) inputField.forceActiveFocus()
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.06, 0.04, 0.12, 1.0) }
            GradientStop { position: 0.5; color: Qt.rgba(0.04, 0.025, 0.09, 1.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.025, 0.015, 0.07, 1.0) }
        }
    }

    Item {
        anchors.fill: parent
        Canvas {
            id: nebula
            anchors.fill: parent
            opacity: 0.55
            property color glow: root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.85)
            onGlowChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                let ctx = getContext("2d")
                ctx.reset()
                let cx = width / 2
                let cy = height * 0.45
                let r = Math.max(width, height) * 0.55
                let g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                g.addColorStop(0, Qt.rgba(glow.r, glow.g, glow.b, 0.18))
                g.addColorStop(0.6, Qt.rgba(glow.r, glow.g, glow.b, 0.04))
                g.addColorStop(1, Qt.rgba(glow.r, glow.g, glow.b, 0))
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
            }
        }
    }

    Canvas {
        id: particles
        anchors.fill: parent
        opacity: 0.5

        property var points: []
        property color particleColor: root.theme ? root.theme.glowPrimary : Qt.rgba(0.85, 0.78, 1.0, 0.85)

        Component.onCompleted: {
            points = []
            for (let i = 0; i < 22; i++) {
                points.push({
                    x: Math.random(),
                    y: Math.random(),
                    r: 0.6 + Math.random() * 1.4,
                    phase: Math.random() * Math.PI * 2,
                    speed: 0.0006 + Math.random() * 0.0014,
                    drift: 0.00015 + Math.random() * 0.00035
                })
            }
            requestPaint()
        }

        onPaint: {
            let ctx = getContext("2d")
            ctx.reset()
            for (let i = 0; i < points.length; i++) {
                let p = points[i]
                let alpha = 0.25 + 0.55 * (0.5 + 0.5 * Math.sin(p.phase))
                let x = p.x * width
                let y = p.y * height
                ctx.beginPath()
                ctx.arc(x, y, p.r, 0, Math.PI * 2)
                ctx.fillStyle = Qt.rgba(particleColor.r, particleColor.g, particleColor.b, alpha)
                ctx.fill()
            }
        }

        Timer {
            interval: 60
            running: true
            repeat: true
            onTriggered: {
                let pts = particles.points
                for (let i = 0; i < pts.length; i++) {
                    pts[i].phase += pts[i].speed * 60
                    pts[i].y -= pts[i].drift
                    if (pts[i].y < -0.02) {
                        pts[i].y = 1.02
                        pts[i].x = Math.random()
                    }
                }
                particles.requestPaint()
            }
        }
    }

    Ai.ConversationList {
        id: sidebar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.sidebarCollapsed ? 0 : root.sidebarWidth
        clip: true
        z: 6
        modeManager: root.modeManager
        theme: root.theme
        icons: root.icons
        conversations: root.conversations
        currentId: root.currentConvId

        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

        onNewChatRequested: root.newChat()
        onConversationSelected: id => root.selectConversation(id)
        onConversationDeleteRequested: id => root.deleteConversation(id)
        onToggleRequested: root.sidebarCollapsed = !root.sidebarCollapsed
    }

    // Visible only while the sidebar is collapsed.
    Item {
        id: expandToggle
        anchors.left: sidebar.right
        anchors.top: parent.top
        anchors.leftMargin: modeManager.scale(10)
        anchors.topMargin: modeManager.scale(14)
        width: modeManager.scale(28)
        height: modeManager.scale(28)
        z: 7
        opacity: root.sidebarCollapsed ? 1.0 : 0.0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        UI.SvgIcon {
            anchors.centerIn: parent
            width: modeManager.scale(17)
            height: modeManager.scale(17)
            source: root.icons ? root.icons.sidebarSvg : ""
            color: expandMouse.containsMouse
                ? (root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))
                : (root.theme ? root.theme.textSecondary : Qt.rgba(0.78, 0.78, 0.88, 0.85))
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
            id: expandMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.sidebarCollapsed = false
        }
    }

    Item {
        id: mainPane
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        z: 2

    RowLayout {
        id: topChrome
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: modeManager.scale(14)
        anchors.rightMargin: modeManager.scale(18)
        spacing: modeManager.scale(10)
        z: 5

        Ai.ModelSelector {
            visible: root.aiAvailable && root.currentModel !== ""
            theme: root.theme
            modeManager: root.modeManager
            currentModel: root.currentModel
            availableModels: root.availableModels
            isOpen: root.modelDropdownOpen
            // The selector only edits the *next* conversation's default model.
            // While a chat is active, it shows that chat's bound model
            // read-only so the user can't accidentally switch mid-stream.
            editable: root.currentConvId === 0

            onToggled: {
                if (!editable) return
                root.modelDropdownOpen = !root.modelDropdownOpen
            }
            onModelChosen: name => {
                if (name !== root.currentModel) {
                    root.currentModel = name
                    root.defaultModel = name
                    switchModelProcess.payload = JSON.stringify({ model: name })
                    switchModelProcess.running = true
                }
                root.modelDropdownOpen = false
            }
        }
    }

    // Morphs between empty-state (centered, large) and active-state
    // (bottom-left of latest AI message). Position animates so during
    // streaming the orb trails the growing text.
    Item {
        id: orb
        z: 4
        visible: root.showInternalOrb

        readonly property real emptySize: Math.min(mainPane.width, mainPane.height) * root.orbEmptyScale
        readonly property real activeSize: modeManager.scale(root.orbActiveBase)
        readonly property real emptyX: (mainPane.width - emptySize) / 2
        readonly property real emptyY: mainPane.height * 0.18

        property real activeX: activeOverlay.x
        property real activeY: 0
        property bool activePosReady: false

        // Hold at empty position until we know where to land in active state,
        // so the orb doesn't briefly jump to (0,0) before reaching the message.
        readonly property bool isInEmptyState: root.isEmpty || !activePosReady

        Connections {
            target: root
            function onMessagesChanged() { Qt.callLater(orb.updateActivePos) }
        }

        function updateActivePos() {
            if (root.messages.length === 0) {
                activePosReady = false
                return
            }
            let lastIdx = root.messages.length - 1
            let item = chatList.itemAtIndex(lastIdx)
            if (!item) {
                activePosReady = false
                return
            }
            activeX = activeOverlay.x
            activeY = activeOverlay.y + item.y - chatList.contentY + item.height - modeManager.scale(40)
            activePosReady = true
        }

        x: isInEmptyState ? emptyX : activeX
        y: isInEmptyState ? emptyY : activeY
        width: isInEmptyState ? emptySize : activeSize
        height: width

        // External consumers (Yura) animate the orb in their own window
        // and watch orbExternalX/Y/Size as the source of truth — running
        // a Behavior here too would just stack a 900ms lag on top.
        Behavior on x {
            enabled: root.showInternalOrb && !chatList.moving && !chatList.flicking
            NumberAnimation { duration: 900; easing.type: Easing.InOutCubic }
        }
        Behavior on y {
            enabled: root.showInternalOrb && !chatList.moving && !chatList.flicking
            NumberAnimation { duration: 900; easing.type: Easing.InOutCubic }
        }
        Behavior on width {
            enabled: root.showInternalOrb
            NumberAnimation { duration: 900; easing.type: Easing.InOutCubic }
        }

        Ai.AmbientOrb {
            anchors.fill: parent
            orbColor: root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.9)
            streaming: !root.isEmpty && root.streaming
            haloScale: root.isEmpty ? 1.5 : 1.8
            haloOpacity: root.isEmpty ? 0.45 : 0.6
        }

        Connections {
            target: chatList
            function onContentYChanged() { orb.updateActivePos() }
            function onContentHeightChanged() { orb.updateActivePos() }
            function onCountChanged() { Qt.callLater(orb.updateActivePos) }
        }
    }

    Item {
        id: emptyOverlay
        anchors.fill: parent
        z: 3
        opacity: root.isEmpty && root.aiAvailable && root.hasModel ? 1.0 : 0.0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.18 + orb.emptySize + modeManager.scale(28)
            spacing: modeManager.scale(18)
            width: Math.min(parent.width - modeManager.scale(64), modeManager.scale(560))

            Common.GlowText {
                Layout.alignment: Qt.AlignHCenter
                text: "What's on your mind?"
                font.pixelSize: modeManager.scale(20)
                font.family: "M PLUS 2"
                font.italic: true
                font.weight: Font.Light
                font.letterSpacing: 0.8
                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.92)

                enableGlow: true
                glowColor: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5)
                glowSamples: 24
                glowRadius: 14
                glowSpread: 0.4
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: modeManager.scale(10)

                Repeater {
                    model: root.suggestedPrompts
                    delegate: Ai.PromptChip {
                        Layout.alignment: Qt.AlignHCenter
                        theme: root.theme
                        modeManager: root.modeManager
                        label: modelData
                        onClicked: {
                            if (!root.streaming) {
                                inputField.text = ""
                                root.sendMessage(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: activeOverlay
        anchors.fill: parent
        anchors.topMargin: modeManager.scale(60)
        anchors.bottomMargin: inputBar.height + modeManager.scale(16)
        anchors.leftMargin: modeManager.scale(40)
        anchors.rightMargin: modeManager.scale(40)
        z: 3
        opacity: !root.isEmpty ? 1.0 : 0.0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }

        ListView {
            id: chatList
            anchors.fill: parent
            spacing: modeManager.scale(14)
            clip: true
            model: root.messages
            interactive: true

            onContentHeightChanged: {
                if (!root.userScrolled) positionViewAtEnd()
            }

            onMovingChanged: {
                if (moving) root.userScrolled = true
            }

            onAtYEndChanged: {
                if (atYEnd) root.userScrolled = false
            }

            delegate: Item {
                id: delegateRoot
                width: chatList.width
                implicitHeight: msgCol.implicitHeight + modeManager.scale(8)

                readonly property bool isAssistant: modelData.role === "assistant"
                readonly property bool isLatest: index === root.messages.length - 1
                readonly property bool isThinking: root.streaming
                    && isLatest
                    && isAssistant
                    && modelData.content === ""
                readonly property bool showInlineOrb: isAssistant && isLatest
                readonly property var assistantBlocks: isAssistant && !isThinking
                    ? root.parseBlocks(modelData.content)
                    : []

                Column {
                    id: msgCol
                    width: parent.width
                    spacing: modeManager.scale(6)

                    Text {
                        visible: !delegateRoot.isAssistant && modelData.content !== ""
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        text: modelData.content
                        wrapMode: Text.WordWrap
                        color: root.theme ? root.theme.textSecondary : Qt.rgba(0.78, 0.78, 0.88, 0.85)
                        font.pixelSize: modeManager.scale(14)
                        font.family: "M PLUS 2"
                        font.letterSpacing: 0.3
                        lineHeight: 1.5
                    }

                    Repeater {
                        model: delegateRoot.assistantBlocks

                        delegate: Item {
                            width: msgCol.width
                            implicitHeight: blockText.visible ? blockText.implicitHeight : codeBlock.implicitHeight

                            Text {
                                id: blockText
                                visible: modelData.type === "text"
                                anchors.left: parent.left
                                anchors.right: parent.right
                                text: visible ? modelData.content : ""
                                textFormat: Text.MarkdownText
                                wrapMode: Text.WordWrap
                                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                                font.pixelSize: modeManager.scale(14)
                                font.family: "M PLUS 2"
                                font.letterSpacing: 0.3
                                lineHeight: 1.5
                                linkColor: root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1.0)
                                onLinkActivated: link => Qt.openUrlExternally(link)
                            }

                            Ai.CodeBlock {
                                id: codeBlock
                                visible: modelData.type === "code"
                                anchors.left: parent.left
                                anchors.right: parent.right
                                modeManager: root.modeManager
                                theme: root.theme
                                icons: root.icons
                                lang: visible ? modelData.lang : ""
                                code: visible ? modelData.content : ""
                                onCopyRequested: text => {
                                    copyProcess.text = text
                                    copyProcess.running = true
                                }
                            }
                        }
                    }

                    // Reserves space for the global orb that lands here.
                    Item {
                        visible: delegateRoot.isAssistant && delegateRoot.isLatest
                        width: 1
                        height: modeManager.scale(40)
                    }
                }
            }
        }
    }

    Item {
        id: inputBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: modeManager.scale(40)
        anchors.rightMargin: modeManager.scale(40)
        anchors.bottomMargin: modeManager.scale(22)
        height: modeManager.scale(46)
        z: 5
        visible: root.aiAvailable && root.hasModel

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: inputField.activeFocus
                ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.85) : Qt.rgba(0.65, 0.55, 0.85, 0.85))
                : Qt.rgba(0.5, 0.5, 0.65, 0.25)

            Behavior on color { ColorAnimation { duration: 250 } }

            layer.enabled: inputField.activeFocus
            layer.effect: Glow {
                samples: 18
                radius: 8
                spread: 0.3
                color: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6)
                transparentBorder: true
            }
        }

        TextInput {
            id: inputField
            anchors.left: parent.left
            anchors.right: sendIcon.left
            anchors.rightMargin: modeManager.scale(12)
            anchors.verticalCenter: parent.verticalCenter
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
            font.pixelSize: modeManager.scale(15)
            font.family: "M PLUS 2"
            font.letterSpacing: 0.3
            selectByMouse: true
            clip: true
            verticalAlignment: TextInput.AlignVCenter
            inputMethodHints: Qt.ImhNone

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    let txt = inputField.text.trim()
                    if (txt.length > 0 && !root.streaming) {
                        root.sendMessage(txt)
                        inputField.text = ""
                    }
                    event.accepted = true
                }
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: root.streaming ? "Thinking..." : "Ask anything"
                color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.6)
                font.pixelSize: parent.font.pixelSize
                font.family: parent.font.family
                font.letterSpacing: parent.font.letterSpacing
                font.italic: true
                visible: parent.text.length === 0
                    && parent.preeditText.length === 0
                    && !parent.inputMethodComposing
            }
        }

        Item {
            id: sendIcon
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: modeManager.scale(34)
            height: modeManager.scale(34)
            opacity: (root.streaming || inputField.text.trim().length > 0) ? 1.0 : 0.35

            Behavior on opacity { NumberAnimation { duration: 200 } }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: width / 2
                color: sendMouse.containsMouse
                    ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.32) : Qt.rgba(0.65, 0.55, 0.85, 0.32))
                    : (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.18) : Qt.rgba(0.65, 0.55, 0.85, 0.18))

                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Text {
                anchors.centerIn: parent
                text: root.streaming ? "■" : "↑"
                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                font.pixelSize: modeManager.scale(root.streaming ? 12 : 16)
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

    Item {
        anchors.fill: parent
        z: 3
        visible: root.healthChecked && (!root.aiAvailable || !root.hasModel)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: modeManager.scale(10)

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: !root.aiAvailable ? "mugen-ai is not running" : "No models available"
                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.9)
                font.pixelSize: modeManager.scale(16)
                font.family: "M PLUS 2"
                font.weight: Font.Light
                font.italic: true
                font.letterSpacing: 0.8
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: !root.aiAvailable
                    ? "Install mugen-ai from this repo:\nmake install-ai"
                    : "Pull an Ollama model (e.g. ollama pull gemma3:4b)\nor configure Gemini in ~/.config/mugen-ai/config.toml"
                color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.7)
                font.pixelSize: modeManager.scale(12)
                font.family: !root.aiAvailable ? "monospace" : "M PLUS 2"
                lineHeight: 1.4
            }
        }
    }
    } // mainPane

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
                        if (obj.model) root.currentModel = obj.model
                        return
                    }
                    if (obj.error) {
                        root.updateLastMessage("\n[error: " + obj.error + "]")
                        return
                    }
                    if (obj.content) {
                        root.updateLastMessage(obj.content)
                    }
                } catch (e) {
                }
            }
        }

        onExited: (exitCode) => {
            root.streaming = false
            if (exitCode !== 0) {
                root.updateLastMessage("\n[connection failed]")
            }
            // Refresh the sidebar so the active conversation moves to the top
            // and picks up its derived title once the first user message lands.
            root.refreshConversations()
        }
    }

    Process {
        id: listConvProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "2", root._baseUrl + "/conversations"]

        stdout: SplitParser { onRead: data => { listConvProcess.buf += data } }
        onRunningChanged: { if (running) buf = "" }

        onExited: (exitCode) => {
            if (exitCode !== 0) return
            try {
                let obj = JSON.parse(listConvProcess.buf)
                root.conversations = obj.conversations || []
            } catch (e) {}
        }
    }

    Process {
        id: loadCurrentProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "2", root._baseUrl + "/conversations/current"]

        stdout: SplitParser { onRead: data => { loadCurrentProcess.buf += data } }
        onRunningChanged: { if (running) buf = "" }

        onExited: (exitCode) => {
            if (exitCode !== 0) return
            try {
                let obj = JSON.parse(loadCurrentProcess.buf)
                root.currentConvId = obj.id || 0
                let msgs = obj.messages || []
                root.messages = msgs.map(m => ({ role: m.role, content: m.content }))
                // Sync the dropdown to the conversation's bound model so the
                // selector reflects what's actually being used.
                if (root.currentConvId !== 0 && obj.model) {
                    root.currentModel = obj.model
                }
            } catch (e) {}
        }
    }

    Process {
        id: selectConvProcess
        running: false
        property string payload: ""
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "2", "-X", "POST",
                  root._baseUrl + "/conversations/" + payload + "/select"]

        stdout: SplitParser { onRead: data => { selectConvProcess.buf += data } }
        onRunningChanged: { if (running) buf = "" }

        onExited: (exitCode) => {
            if (exitCode !== 0) return
            // After selection, fetch the messages of the now-current conversation.
            loadCurrentProcess.running = true
        }
    }

    Process {
        id: deleteConvProcess
        running: false
        property string payload: ""
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "2", "-X", "DELETE",
                  root._baseUrl + "/conversations/" + payload]

        stdout: SplitParser { onRead: data => { deleteConvProcess.buf += data } }
        onRunningChanged: { if (running) buf = "" }

        onExited: (exitCode) => {
            if (exitCode !== 0) return
            let newCurrent = 0
            try {
                let obj = JSON.parse(deleteConvProcess.buf)
                newCurrent = obj.current_id || 0
            } catch (e) {}
            // If we deleted the active conversation, reload to reflect the new current
            // (or empty state if none remain). Otherwise just refresh the list.
            if (parseInt(deleteConvProcess.payload) === root.currentConvId) {
                root.currentConvId = newCurrent
                root.messages = []
                if (newCurrent !== 0) loadCurrentProcess.running = true
            }
            root.refreshConversations()
        }
    }

    Process {
        id: copyProcess
        property string text: ""
        running: false
        command: ["wl-copy", text]
    }

    Process {
        id: healthProcess
        running: false
        property string buf: ""
        command: ["curl", "-sSf", "--max-time", "2", root._baseUrl + "/health"]

        stdout: SplitParser {
            onRead: data => { healthProcess.buf += data }
        }

        onRunningChanged: { if (running) buf = "" }

        onExited: (exitCode) => {
            root.aiAvailable = (exitCode === 0)
            root.healthChecked = true
            if (exitCode === 0) {
                try {
                    let obj = JSON.parse(buf)
                    root.currentModel = obj.model || ""
                    root.defaultModel = obj.model || ""
                    root.hasModel = obj.status === "ok"
                } catch (e) {}
                modelsProcess.running = true
                // Float opens in fresh-chat state to match bar AI; the sidebar
                // still lists every past conversation so they can be picked.
                root.refreshConversations()
            }
        }
    }

    Process {
        id: modelsProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "2", root._baseUrl + "/models"]

        stdout: SplitParser {
            onRead: data => { modelsProcess.buf += data }
        }

        onRunningChanged: { if (running) buf = "" }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                try {
                    let obj = JSON.parse(buf)
                    if (obj.models) root.availableModels = obj.models
                } catch (e) {}
            }
        }
    }

    Process {
        id: switchModelProcess
        running: false
        property string payload: ""
        command: ["curl", "-sS", "-X", "PUT",
                  root._baseUrl + "/model",
                  "-H", "Content-Type: application/json",
                  "-d", payload]

        // PUT /model now only changes the *default* model for the next new
        // conversation. The current view stays on whatever it was — no
        // history wipe, no surprise empty-conversation row in the sidebar.
    }

    Component.onCompleted: {
        healthProcess.running = true
        focusTimer.restart()
    }
}
