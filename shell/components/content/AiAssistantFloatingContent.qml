import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
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
    property var aiBackend: localBackend
    property var settingsManager
    property bool showInternalOrb: true

    // Lets a host count keyboard-only use as activity; the timer only sees taps and pointer motion.
    signal userActivity()

    property real orbEmptyScale: 0.28
    property real orbActiveBase: 36
    property real orbEmptyYRatio: 0.18

    readonly property real orbExternalX: orb.x + mainPane.x
    readonly property real orbExternalY: orb.y + mainPane.y
    readonly property real orbExternalSize: orb.width
    readonly property bool orbExternalEmptyState: orb.isInEmptyState

    Theme.AiBackend { id: localBackend }

    Ai.YuraChatSession {
        id: session
        aiBackend: root.aiBackend
        settingsManager: root.settingsManager
        onDraftReturned: (text, files) => root.restoreDraft(text, files)
        onScrollToEndRequested: Qt.callLater(() => chatList.positionViewAtEnd())
    }

    property alias messages: session.messages
    property alias streaming: session.streaming

    property alias turnFailure: session.turnFailure

    property alias aiAvailable: session.aiAvailable
    property alias hasModel: session.hasModel
    property alias healthChecked: session.healthChecked
    property alias healthStatus: session.healthStatus
    property alias userScrolled: session.userScrolled
    property alias currentModel: session.currentModel
    property alias contextDropped: session.contextDropped
    property alias availableModels: session.availableModels
    property bool modelDropdownOpen: false
    property alias currentThinking: session.currentThinking

    property alias conversations: session.conversations
    property alias currentConvId: session.currentConvId
    property bool sidebarCollapsed: false
    readonly property int sidebarWidth: modeManager.scale(200)

    readonly property bool isEmpty: messages.length === 0

    readonly property var suggestedPrompts: [
        "What's the weather like?",
        "What am I working on right now?",
        "Set a 10 minute timer",
        "Summarize my unread notifications"
    ]

    property alias pendingConfirm: session.pendingConfirm

    property alias rewinding: session.rewinding
    property alias busy: session.busy

    // Absolute paths staged for the next turn; the backend reads the files.
    property var pendingAttachments: []
    // Matches the backend's per-message cap.
    readonly property int maxAttachments: 4

    function addAttachments(urls) {
        let next = root.pendingAttachments.slice()
        for (const url of urls) {
            // A pretty-printed URL still escapes the delimiters, so `#` and `?` arrive encoded.
            let path = String(url).replace(/^file:\/\//, "")
            try { path = decodeURIComponent(path) } catch (e) {}
            if (next.length >= root.maxAttachments) break
            if (next.indexOf(path) === -1) next.push(path)
        }
        root.pendingAttachments = next
    }

    function removeAttachment(index) {
        let next = root.pendingAttachments.slice()
        next.splice(index, 1)
        root.pendingAttachments = next
    }

    property alias streamRevealed: session.streamRevealed
    property alias revealActive: session.revealActive
    property alias openDetails: session.openDetails
    property alias editingIndex: session.editingIndex

    function toggleDetail(key) { return session.toggleDetail(key) }
    function resolveConfirm(approved) { return session.resolveConfirm(approved) }
    function sendMessage(text, attachments) { return session.sendMessage(text, attachments) }
    function retryFrom(index) { return session.retryFrom(index) }
    function beginEdit(index) { return session.beginEdit(index) }
    function cancelEdit() { return session.cancelEdit() }
    function submitEdit(text) { return session.submitEdit(text) }
    function stopStreaming() { return session.stopStreaming() }
    function newChat() { return session.newChat() }
    function selectConversation(convId) { return session.selectConversation(convId) }
    function deleteConversation(convId) { return session.deleteConversation(convId) }
    function showConversation(convId) { return session.showConversation(convId) }

    function sendComposed(text) {
        if (!root.sendMessage(text, root.pendingAttachments)) return false
        root.pendingAttachments = []
        return true
    }

    function restoreDraft(text, files) {
        inputBar.field.text = inputBar.field.text.trim() === "" ? text : text + "\n" + inputBar.field.text
        pendingAttachments = files.concat(pendingAttachments).slice(0, maxAttachments)
        inputBar.field.cursorPosition = inputBar.field.length
        inputBar.field.forceActiveFocus()
    }

    Timer {
        id: focusTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (root.aiAvailable) inputBar.field.forceActiveFocus()
        }
    }

    Ai.ChatBackdrop {
        anchors.fill: parent
        theme: root.theme
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

        Behavior on width { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.InOutCubic } }

        onNewChatRequested: root.newChat()
        onSettingsRequested: yuraSettingsProcess.running = true
        onConversationSelected: id => root.selectConversation(id)
        onConversationDeleteRequested: id => root.deleteConversation(id)
        onToggleRequested: root.sidebarCollapsed = !root.sidebarCollapsed
    }

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

        Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }

        UI.SvgIcon {
            anchors.centerIn: parent
            width: modeManager.scale(17)
            height: modeManager.scale(17)
            source: root.icons ? root.icons.sidebarSvg : ""
            color: expandMouse.containsMouse
                ? (root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))
                : (root.theme ? root.theme.textSecondary : Qt.rgba(0.78, 0.78, 0.88, 0.85))
            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
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

            onToggled: {
                root.modelDropdownOpen = !root.modelDropdownOpen
            }
            onModelChosen: name => {
                session.chooseModel(name)
                root.modelDropdownOpen = false
            }
        }

        Rectangle {
            id: thinkingPill
            visible: root.aiAvailable && root.currentModel !== ""
            Layout.preferredWidth: modeManager.scale(72)
            Layout.preferredHeight: modeManager.scale(26)
            Layout.alignment: Qt.AlignVCenter
            radius: height / 2

            readonly property bool on: root.currentThinking

            color: thinkingPill.on
                ? (root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                : Qt.rgba(0.3, 0.3, 0.36, 0.4)
            border.width: 1
            border.color: thinkingPill.on
                ? (root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.95))
                : Qt.rgba(1, 1, 1, 0.12)
            Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

            Text {
                anchors.centerIn: parent
                text: thinkingPill.on ? "Think ON" : "Think OFF"
                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95)
                font.pixelSize: modeManager.scale(10)
                font.family: "M PLUS 2"
                font.weight: Font.Medium
                opacity: thinkingPill.on ? 1.0 : 0.7
                Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.currentThinking = !root.currentThinking
            }
        }
    }

    Item {
        id: orb
        z: 4
        visible: root.showInternalOrb

        readonly property real emptySize: Math.min(mainPane.width, mainPane.height) * root.orbEmptyScale
        readonly property real activeSize: modeManager.scale(root.orbActiveBase)
        readonly property real emptyX: (mainPane.width - emptySize) / 2
        readonly property real emptyY: mainPane.height * root.orbEmptyYRatio

        property real activeX: activeOverlay.x
        property real activeY: 0
        property bool activePosReady: false

        property bool _activePosEverReady: false
        onActivePosReadyChanged: if (activePosReady) _activePosEverReady = true

        readonly property bool isInEmptyState: root.isEmpty || (!activePosReady && !_activePosEverReady)

        Connections {
            target: root
            function onMessagesChanged() {
                if (root.messages.length === 0) orb._activePosEverReady = false
                Qt.callLater(orb.updateActivePos)
            }
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
            let rawY = activeOverlay.y + item.y - chatList.contentY + item.height - modeManager.scale(40)
            let minY = activeOverlay.y
            let maxY = activeOverlay.y + activeOverlay.height - orb.activeSize
            activeY = Math.max(minY, Math.min(rawY, maxY))
            activePosReady = true
        }

        x: isInEmptyState ? emptyX : activeX
        y: isInEmptyState ? emptyY : activeY
        width: isInEmptyState ? emptySize : activeSize
        height: width

        Behavior on x {
            enabled: root.showInternalOrb && !chatList.moving && !chatList.flicking
            NumberAnimation { duration: Theme.Motion.drift; easing.type: Easing.InOutCubic }
        }
        Behavior on y {
            enabled: root.showInternalOrb && !chatList.moving && !chatList.flicking
            NumberAnimation { duration: Theme.Motion.drift; easing.type: Easing.InOutCubic }
        }
        Behavior on width {
            enabled: root.showInternalOrb
            NumberAnimation { duration: Theme.Motion.drift; easing.type: Easing.InOutCubic }
        }

        Ai.AmbientOrb {
            anchors.fill: parent
            orbColor: root.theme ? root.theme.glowTertiary : Qt.rgba(0.95, 0.72, 0.74, 0.9)
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

        Behavior on opacity { NumberAnimation { duration: Theme.Motion.slow; easing.type: Easing.InOutCubic } }

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * root.orbEmptyYRatio + orb.emptySize + modeManager.scale(28)
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

            Ai.SuggestionChips {
                Layout.fillWidth: true
                Layout.topMargin: modeManager.scale(6)
                modeManager: root.modeManager
                theme: root.theme
                prompts: root.suggestedPrompts
                onPromptChosen: text => {
                    if (!root.busy) root.sendMessage(text)
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

        Behavior on opacity { NumberAnimation { duration: Theme.Motion.slow; easing.type: Easing.InOutCubic } }

        ListView {
            id: chatList
            anchors.fill: parent
            spacing: modeManager.scale(14)
            clip: true
            model: root.messages.length
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

            delegate: Ai.ChatMessage {
                width: chatList.width
                modeManager: root.modeManager
                theme: root.theme
                icons: root.icons
                msgIndex: index
                message: root.messages[index] || ({ content: "" })
                messageCount: root.messages.length
                editingIndex: root.editingIndex
                streaming: root.streaming
                busy: root.busy
                openDetails: root.openDetails
                contextDropped: root.contextDropped
                revealActive: root.revealActive
                streamRevealed: root.streamRevealed
                onUserActivity: root.userActivity()
                onCancelEditRequested: root.cancelEdit()
                onSubmitEditRequested: text => root.submitEdit(text)
                onDetailToggled: key => root.toggleDetail(key)
                onRetryRequested: root.retryFrom(index)
                onEditRequested: root.beginEdit(index)
                onCopyRequested: text => {
                    copyProcess.text = text
                    copyProcess.running = true
                }
            }

            footer: Item {
                id: confirmFooter
                // Lint reports one unqualified access per root.x read inside a footer, so relay them.
                readonly property var theme: root.theme
                readonly property var modeManager: root.modeManager
                readonly property var pendingConfirm: root.pendingConfirm
                function resolveConfirm(approved) { root.resolveConfirm(approved) }

                width: chatList.width
                height: pendingConfirm === null ? 0 : confirmCard.height + chatList.spacing

                Ai.ApprovalCard {
                    id: confirmCard
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: chatList.spacing
                    modeManager: confirmFooter.modeManager
                    theme: confirmFooter.theme
                    pendingConfirm: confirmFooter.pendingConfirm
                    onResolved: approved => confirmFooter.resolveConfirm(approved)
                }
            }
        }

        Rectangle {
            id: scrollDownBtn
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: modeManager.scale(2)
            width: modeManager.scale(32)
            height: width
            radius: width / 2
            z: 2
            opacity: (root.userScrolled && !chatList.atYEnd) ? 1.0 : 0.0
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }

            color: scrollDownMouse.containsMouse
                ? (root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.32) : Qt.rgba(0.65, 0.55, 0.85, 0.32))
                : (root.theme ? root.theme.surfaceInsetSubtle : Qt.rgba(0.07, 0.06, 0.11, 0.92))
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)

            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

            UI.SvgIcon {
                anchors.centerIn: parent
                width: modeManager.scale(15)
                height: width
                source: root.icons ? root.icons.arrowDownwardSvg : ""
                color: root.theme ? root.theme.textSecondary : Qt.rgba(0.82, 0.80, 0.90, 0.9)
            }

            MouseArea {
                id: scrollDownMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.userScrolled = false
                    chatList.positionViewAtEnd()
                }
            }
        }
    }

    Ai.ChatComposer {
        id: inputBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: modeManager.scale(40)
        anchors.rightMargin: modeManager.scale(40)
        anchors.bottomMargin: modeManager.scale(22)
        z: 5
        visible: root.aiAvailable && root.hasModel
        modeManager: root.modeManager
        theme: root.theme
        icons: root.icons
        streaming: root.streaming
        rewinding: root.rewinding
        busy: root.busy
        turnFailure: root.turnFailure
        pendingAttachments: root.pendingAttachments
        maxAttachments: root.maxAttachments
        onUserActivity: root.userActivity()
        onNewChatRequested: root.newChat()
        onSendRequested: text => { if (root.sendComposed(text)) inputBar.field.text = "" }
        onStopClicked: root.stopStreaming()
        onAttachRequested: attachDialog.open()
        onRemoveAttachmentRequested: index => root.removeAttachment(index)
    }

    FileDialog {
        id: attachDialog
        // The portal shows the caller's title, so Hyprland matches on this too.
        title: "Open Files"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["All files (*)", "Images (*.png *.jpg *.jpeg *.webp *.gif)"]
        onAccepted: root.addAttachments(attachDialog.selectedFiles)
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
                text: !root.aiAvailable ? "mugen-ai is not running"
                    : root.healthStatus === "provider_unavailable" ? "Model provider unreachable"
                    : "No model yet"
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
                    ? "systemctl --user start mugen-ai"
                    : root.healthStatus === "provider_unavailable"
                        ? (root.currentModel || "The configured model") + " did not answer.\nCheck that Ollama, or whichever provider serves it, is running."
                        : "Yura needs a model of your own. Install Ollama and pull one\n(ollama pull qwen3:4b), or put an API key in ~/.config/mugen-ai/.env.\nSettings → Yura → Model lists what the backend can see."
                textFormat: Text.PlainText
                color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.7)
                font.pixelSize: modeManager.scale(12)
                font.family: !root.aiAvailable ? "monospace" : "M PLUS 2"
                lineHeight: 1.4
            }
        }
    }
    } // mainPane

    Process {
        id: copyProcess
        property string text: ""
        running: false
        stdinEnabled: true
        // Over stdin: argv caps one string at 128 KiB; --type keeps wl-copy from sniffing it with xdg-mime.
        command: ["wl-copy", "--type", "text/plain"]
        onStarted: {
            copyProcess.write(copyProcess.text)
            copyProcess.stdinEnabled = false
        }
        onExited: copyProcess.stdinEnabled = true
    }

    Process {
        id: yuraSettingsProcess
        running: false
        command: ["bash", Quickshell.shellDir + "/scripts/toggle-yura-settings.sh", "--open"]
    }

    Component.onCompleted: {
        focusTimer.restart()
    }
}
