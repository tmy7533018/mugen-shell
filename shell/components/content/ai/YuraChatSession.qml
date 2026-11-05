import QtQuick
import Quickshell.Io
import "../../../lib" as Theme

Item {
    id: root

    required property var aiBackend
    property var settingsManager

    signal draftReturned(string text, var files)
    signal scrollToEndRequested()

    readonly property string _baseUrl: aiBackend.baseUrl
    readonly property var _transportArgs: aiBackend.transportArgs

    property var messages: []
    property bool streaming: false
    property bool stopRequested: false
    property bool discardStreamTail: false

    // Kept for the turn in flight, so one the server rolled back can go back into the input.
    property string sentText: ""
    property var sentFiles: []
    property bool sentToNewConv: false
    property int turnConvId: 0
    property bool turnOpened: false
    property bool replyStarted: false
    property string turnError: ""
    property string rejectBody: ""
    property string turnFailure: ""

    property int turnSeq: 0

    property bool aiAvailable: false
    property bool hasModel: false
    property bool healthChecked: false
    // /health status verbatim: "ok", "no_model" (nothing configured) or
    // "provider_unavailable" (a model is set but its backend did not answer).
    property string healthStatus: ""
    property bool userScrolled: false
    property string currentModel: ""
    // Messages before this index were dropped from the window sent to the model.
    property int contextDropped: 0
    // Tracked separately so an old chat can show its bound model without clobbering the default.
    property string defaultModel: ""
    property var availableModels: []
    // The server persists this, so reopening an old chat restores the state it was last sent with.
    property bool currentThinking: false

    property var conversations: []
    property int currentConvId: 0

    // While set, the backend is blocked on approval. Shape: { confirm_id, name, arguments }.
    property var pendingConfirm: null

    readonly property bool rewinding: truncateProcess.running
    readonly property bool busy: streaming || rewinding || chatProcess.running

    // Matches the backend's maxRequestBody; past ~128 KiB curl's argv could not even carry it.
    readonly property int maxRequestBytes: 64 * 1024

    // Reveal state lives here, not in the delegate: every append rebuilds the delegates.
    readonly property string typingSpeed: settingsManager ? settingsManager.yuraTypingSpeed : "instant"
    readonly property int revealStep: typingSpeed === "slow" ? 2 : typingSpeed === "normal" ? 6 : 16
    property int streamRevealed: 0
    property bool revealActive: false
    readonly property string latestStreamContent: {
        if (messages.length === 0) return ""
        let m = messages[messages.length - 1]
        return m.role === "assistant" ? (m.content || "") : ""
    }

    onStreamingChanged: {
        if (streaming) {
            streamRevealed = 0
            revealActive = typingSpeed !== "instant"
            editingIndex = -1
        }
    }

    // An index only means something against the conversation it came from.
    onCurrentConvIdChanged: { editingIndex = -1; openDetails = ({}) }

    // By message index (":<chip index>" added for a tool chip): every append rebuilds the delegates, and call ids may differ on reload.
    property var openDetails: ({})
    function toggleDetail(key) {
        let next = Object.assign({}, openDetails)
        if (next[key]) delete next[key]
        else next[key] = true
        openDetails = next
    }

    // A cut tail's indices get reused by the next messages, which must not inherit its open state.
    onMessagesChanged: {
        let next = null
        for (const key in openDetails) {
            if (parseInt(key) < messages.length) continue
            if (!next) next = Object.assign({}, openDetails)
            delete next[key]
        }
        if (next) openDetails = next
    }

    Timer {
        id: revealTimer
        interval: 30
        repeat: true
        running: root.revealActive
        onTriggered: {
            if (root.streamRevealed < root.latestStreamContent.length) {
                root.streamRevealed = Math.min(
                    root.streamRevealed + root.revealStep,
                    root.latestStreamContent.length)
            } else if (!root.streaming) {
                root.revealActive = false
            }
        }
    }

    function appendMessage(role, content, attachments) {
        let copy = messages.slice()
        copy.push({
            role: role,
            content: content,
            attachments: attachments || [],
            createdAt: Math.floor(Date.now() / 1000)
        })
        messages = copy
    }

    function updateLastMessage(content) {
        if (messages.length === 0) return
        freezeThinking()
        let copy = messages.slice()
        let last = copy[copy.length - 1]
        copy[copy.length - 1] = Object.assign({}, last, {
            content: last.content + content,
            toolCalls: last.toolCalls || []
        })
        messages = copy
    }

    property real thinkingStartedAt: 0

    function appendThinking(delta) {
        if (messages.length === 0) return
        if (thinkingStartedAt === 0) thinkingStartedAt = Date.now()
        let copy = messages.slice()
        let last = copy[copy.length - 1]
        copy[copy.length - 1] = Object.assign({}, last, {
            thinking: (last.thinking || "") + delta
        })
        messages = copy
    }

    // Reasoning stops the moment the answer starts, so the elapsed time is frozen there.
    function freezeThinking() {
        if (thinkingStartedAt === 0) return
        let elapsed = Date.now() - thinkingStartedAt
        thinkingStartedAt = 0
        if (messages.length === 0) return
        let copy = messages.slice()
        let last = copy[copy.length - 1]
        copy[copy.length - 1] = Object.assign({}, last, { thinkingMs: (last.thinkingMs || 0) + Math.max(1, elapsed) })
        messages = copy
    }

    function appendToolCalls(calls) {
        if (messages.length === 0 || !calls || calls.length === 0) return
        let copy = messages.slice()
        let last = copy[copy.length - 1]
        let existing = last.toolCalls || []
        let added = calls.map(c => ({
            id: c.id,
            name: c.name,
            arguments: c.arguments || {},
            result: null,
            error: null,
            pending: true
        }))
        copy[copy.length - 1] = Object.assign({}, last, { toolCalls: existing.concat(added) })
        messages = copy
    }

    function attachToolResult(id, name, result, error) {
        if (messages.length === 0) return
        let copy = messages.slice()
        let last = copy[copy.length - 1]
        if (!last.toolCalls || last.toolCalls.length === 0) return
        let updated = last.toolCalls.map(tc => {
            if (tc.id !== id) return tc
            return {
                id: tc.id,
                name: tc.name,
                arguments: tc.arguments,
                result: result,
                error: error || "",
                pending: false
            }
        })
        copy[copy.length - 1] = Object.assign({}, last, { toolCalls: updated })
        messages = copy
    }

    function resolveConfirm(approved) {
        if (!pendingConfirm) return
        confirmProcess.payload = JSON.stringify({
            confirm_id: pendingConfirm.confirm_id,
            approved: approved
        })
        confirmProcess.running = true
        pendingConfirm = null
    }

    function chatPayload(text, files) {
        return JSON.stringify({
            message: text,
            attachments: files,
            conversation_id: currentConvId,
            model: currentModel,
            thinking: currentThinking
        })
    }

    function refuseOversized(text, files) {
        if (Theme.ChatText.utf8Length(chatPayload(text, files || [])) <= maxRequestBytes) return false
        turnFailure = "Couldn't send: message too long"
        return true
    }

    // Returns false when nothing was sent and the caller still holds the text.
    function sendMessage(text, attachments) {
        const files = attachments || []
        if ((!text && files.length === 0) || streaming || chatProcess.running) return false
        stopRequested = false
        turnFailure = ""
        if (refuseOversized(text, files)) {
            root.pendingRewindId = 0
            return false
        }
        if (root.pendingRewindId !== 0) {
            truncateProcess.messageId = root.pendingRewindId
            truncateProcess.queuedText = text
            truncateProcess.queuedFiles = files
            root.pendingRewindId = 0
            truncateProcess.running = true
            return true
        }
        sentText = text
        sentFiles = files
        sentToNewConv = currentConvId === 0
        turnConvId = 0
        turnOpened = false
        replyStarted = false
        turnError = ""
        rejectBody = ""
        turnSeq += 1
        appendMessage("user", text, files)
        appendMessage("assistant", "")
        streaming = true
        userScrolled = false
        chatProcess.payload = chatPayload(text, files)
        chatProcess.running = true
        return true
    }

    // Retry and edit are one server-side move: drop this message and everything after, then resend.
    property int pendingRewindId: 0
    property int editingIndex: -1
    // Lives here, not in the bubble: a change in the message count rebuilds every delegate.
    readonly property var editDraft: QtObject {
        property string text: ""
        property int cursor: 0
    }

    function retryFrom(index) {
        if (busy || index < 0 || index >= messages.length) return
        for (let i = index; i >= 0; i--) {
            if (messages[i].role === "user" && messages[i].id) {
                root.pendingRewindId = messages[i].id
                root.sendMessage(messages[i].content, messages[i].attachments)
                return
            }
        }
    }

    function beginEdit(index) {
        if (busy || index < 0 || index >= messages.length) return
        const msg = messages[index]
        if (!msg.id || msg.role !== "user") return
        editDraft.text = msg.content
        editDraft.cursor = msg.content.length
        root.editingIndex = index
    }

    // Another process can drop or shift the rows under an open editor, and its index must not land on a different message.
    function followEditedMessage(rows) {
        const edited = messages[editingIndex]
        if (!edited) return
        const index = rows.findIndex(m => m.id === edited.id)
        if (index < 0 && editDraft.text.trim() !== "" && editDraft.text !== edited.content) root.draftReturned(editDraft.text, edited.attachments || [])
        editingIndex = index
    }

    function cancelEdit() {
        root.editingIndex = -1
    }

    function submitEdit(text) {
        const index = root.editingIndex
        if (busy) return
        // Closing the editor resets its text, so an oversized edit has to be refused while it is open.
        if (index >= 0 && index < messages.length && refuseOversized(text, messages[index].attachments)) return
        root.editingIndex = -1
        if (index < 0 || index >= messages.length) return
        const msg = messages[index]
        if (!text || text === msg.content || !msg.id) return
        root.pendingRewindId = msg.id
        root.sendMessage(text, msg.attachments)
    }

    function stopStreaming() {
        if (!streaming) return
        stopRequested = true
        chatProcess.signal(15)
        streaming = false
        // The backend reads the disconnect as a denial, so the card must go.
        pendingConfirm = null
    }

    function finishStream(exitCode) {
        streaming = false
        freezeThinking()
        // A timeout or error can end the stream with a card still up for an abandoned prompt.
        pendingConfirm = null
        // A refusal before the stream is a plain HTTP body, which curl without -f exits 0 on.
        const refused = exitCode === 0 && !turnOpened
        // A stop is a SIGTERM, so curl's non-zero exit says nothing about the connection.
        const connectionLost = exitCode !== 0 && !stopRequested
        // The server saves the message just before flushing the conversation id, so a drop before the id almost always kept nothing.
        const unreachable = connectionLost && !turnOpened
        // The server keeps a turn only once text streamed or a tool ran, and rolls back anything less.
        const unsent = !replyStarted && (stopRequested || refused || unreachable || (exitCode === 0 && turnError !== ""))
        if (connectionLost && !unreachable) {
            updateLastMessage("\n[connection failed]")
        }
        stopRequested = false
        refreshConversations()
        // A failed first message would otherwise leave an empty conversation in the list.
        if (unsent && sentToNewConv && turnConvId !== 0) {
            abandonConvProcess.payload = String(turnConvId)
            abandonConvProcess.running = true
        }
        if (discardStreamTail) {
            discardStreamTail = false
            if (unsent) root.draftReturned(sentText, sentFiles)
            return
        }
        if (turnError !== "") {
            turnFailure = (replyStarted ? "Interrupted: " : "Couldn't send: ") + turnError
        } else if (refused) {
            turnFailure = "Couldn't send: " + (rejectBody !== "" ? rejectBody : "the backend refused it")
        } else if (unreachable) {
            turnFailure = "Couldn't send: connection failed"
        }
        if (unsent) {
            handBackUnsent()
            if (sentToNewConv) {
                currentConvId = 0
                return
            }
        }
        // Message ids only exist server-side, so the turn that just landed must be read back.
        loadCurrentConversation()
    }

    function handBackUnsent() {
        const n = messages.length
        if (n >= 2 && messages[n - 2].role === "user") messages = messages.slice(0, n - 2)
        root.draftReturned(sentText, sentFiles)
    }

    function newChat() {
        if (streaming) {
            // The dying stream's read-back would restore the conversation this call is leaving.
            discardStreamTail = true
            stopStreaming()
        }
        if (truncateProcess.running) truncateProcess.abandoned = true
        messages = []
        currentConvId = 0
        turnFailure = ""
        userScrolled = false
        // Coming back from an old conversation leaves currentModel stuck on its bound model.
        if (defaultModel !== "") currentModel = defaultModel
        currentThinking = false
        // No backend call: the conversation is auto-created on the first message, leaving no empty row.
    }

    function selectConversation(convId) {
        if (convId === currentConvId) return
        if (streaming) {
            discardStreamTail = true
            stopStreaming()
        }
        if (truncateProcess.running) truncateProcess.abandoned = true
        currentConvId = convId
        messages = []
        turnFailure = ""
        userScrolled = false
        selectConvProcess.payload = String(convId)
        selectConvProcess.running = true
    }

    // Left alone, the emptied view stays marked as that chat and clicking it again is a no-op.
    function failOpening(convId) {
        const sentMeanwhile = messages.length > 0
        if (convId !== currentConvId || sentMeanwhile) return
        newChat()
        turnFailure = "Couldn't open the chat: connection failed"
    }

    function deleteConversation(convId) {
        // The stream would keep writing into whichever conversation becomes current, and its read-back would race the DELETE.
        if (streaming && convId === currentConvId) {
            discardStreamTail = true
            stopStreaming()
        }
        if (truncateProcess.running && convId === currentConvId) truncateProcess.abandoned = true
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

    function showConversation(convId) {
        if (streaming || !convId || convId === currentConvId) return
        selectConvProcess.payload = String(convId)
        selectConvProcess.running = true
    }

    Process {
        id: eventsSubscriber
        running: true
        command: ["curl", ...root._transportArgs, "-sS", "-N", root._baseUrl + "/events"]

        function handleLine(line) {
            let text = line.trim()
            if (!text.startsWith("data:")) return
            let data = text.substring(5).trim()
            if (!data) return
            let evt
            try { evt = JSON.parse(data) } catch (e) { return }
            if (root.streaming) return
            if (evt.type === "conversations") {
                root.refreshConversations()
            } else if (evt.type === "messages") {
                let convId = evt.data && evt.data.conversation_id
                if (root.currentConvId !== 0 && convId === root.currentConvId) {
                    root.loadCurrentConversation()
                }
            }
        }

        // SplitParser carries the frame's second newline to the front of the next read, so trim first.
        stdout: SplitParser {
            onRead: data => eventsSubscriber.handleLine(data)
        }

        onExited: eventsReconnectTimer.restart()
    }

    Timer {
        id: eventsReconnectTimer
        interval: 2000
        repeat: false
        onTriggered: {
            eventsSubscriber.running = true
            // The stream drops when the backend restarts, which can change its default model and model list.
            if (!healthProcess.running) healthProcess.running = true
        }
    }

    function chooseModel(name) {
        if (name !== root.currentModel) {
            root.currentModel = name
            root.defaultModel = name
            switchModelProcess.payload = JSON.stringify({ model: name })
            switchModelProcess.running = true
        }
    }

    Process {
        id: confirmProcess
        property string payload: ""
        running: false
        command: ["curl", ...root._transportArgs, "-sS", "--max-time", "5", "-X", "POST",
                  root._baseUrl + "/chat/confirm",
                  "-H", "Content-Type: application/json",
                  "-d", payload]
    }

    Process {
        id: chatProcess
        property string payload: ""
        running: false
        command: ["curl", ...root._transportArgs, "-sS", "-N", "-X", "POST",
                  root._baseUrl + "/chat",
                  "-H", "Content-Type: application/json",
                  "-d", payload]

        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                let line = data.trim()
                if (!line.startsWith("data:")) {
                    if (!root.turnOpened && line !== "") {
                        root.rejectBody += (root.rejectBody === "" ? "" : " ") + line
                    }
                    return
                }
                let jsonStr = line.substring(5).trim()
                if (!jsonStr) return
                try {
                    let obj = JSON.parse(jsonStr)
                    if (obj.conversation_id !== undefined) {
                        root.turnOpened = true
                        root.turnConvId = obj.conversation_id
                        if (root.streaming) {
                            root.currentConvId = obj.conversation_id
                            if (obj.model) root.currentModel = obj.model
                        }
                        return
                    }
                    if (obj.error) {
                        root.turnError = obj.error
                        return
                    }
                    if (obj.tool_calls) {
                        root.replyStarted = true
                        root.appendToolCalls(obj.tool_calls)
                        return
                    }
                    if (obj.tool_result) {
                        let tr = obj.tool_result
                        root.attachToolResult(tr.id, tr.name, tr.result, tr.error)
                        return
                    }
                    if (obj.tool_confirm) {
                        if (!root.streaming) return
                        root.pendingConfirm = obj.tool_confirm
                        root.userScrolled = false
                        root.scrollToEndRequested()
                        return
                    }
                    if (obj.thinking) {
                        root.appendThinking(obj.thinking)
                        return
                    }
                    if (obj.content) {
                        root.replyStarted = true
                        root.updateLastMessage(obj.content)
                    }
                } catch (e) {
                }
            }
        }

        onExited: (exitCode) => root.finishStream(exitCode)
        // Quickshell reports a launch failure only by dropping running; exited never fires.
        onRunningChanged: { if (!chatProcess.running && root.streaming) root.finishStream(-1) }
    }

    // Deletes without following current_id: the user stays on the fresh chat they sent from.
    Process {
        id: abandonConvProcess
        running: false
        property string payload: ""
        command: ["curl", ...root._transportArgs, "-sS", "--max-time", "2", "-X", "DELETE",
                  root._baseUrl + "/conversations/" + payload]

        onExited: root.refreshConversations()
    }

    Process {
        id: listConvProcess
        running: false
        property string buf: ""
        command: ["curl", ...root._transportArgs, "-sS", "--max-time", "2", root._baseUrl + "/conversations"]

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
        id: truncateProcess
        running: false
        property int messageId: 0
        property string queuedText: ""
        property var queuedFiles: []
        // -f: without it a 404 exits 0 and reads as a successful rewind.
        command: ["curl", ...root._transportArgs, "-sS", "-f", "-X", "DELETE", "--max-time", "3",
            root._baseUrl + "/conversations/" + root.currentConvId
                + "/messages/" + truncateProcess.messageId]

        property bool abandoned: false

        onExited: (exitCode) => {
            // The rewind targets the conversation it started in, so a switch orphans the resend.
            if (truncateProcess.abandoned) {
                truncateProcess.abandoned = false
                truncateProcess.queuedText = ""
                truncateProcess.queuedFiles = []
                return
            }
            const text = truncateProcess.queuedText
            const files = truncateProcess.queuedFiles
            truncateProcess.queuedText = ""
            truncateProcess.queuedFiles = []
            if (exitCode !== 0) {
                const curlHttpError = 22
                root.turnFailure = "Couldn't send: " + (exitCode === curlHttpError ? "the backend refused it" : "connection failed")
                const rewound = root.messages.find(m => m.id === truncateProcess.messageId)
                const textStillShown = rewound !== undefined && rewound.content === text
                if (!textStillShown) root.draftReturned(text, files)
                return
            }
            // Drop the rewound tail locally too, so the resend can't append under forgotten messages.
            let kept = []
            for (const m of root.messages) {
                if (m.id && m.id >= truncateProcess.messageId) break
                kept.push(m)
            }
            root.messages = kept
            root.sendMessage(text, files)
        }
    }

    Process {
        id: loadCurrentProcess
        running: false
        property string buf: ""
        property int startedTurn: 0
        property bool startedMidTurn: false
        command: ["curl", ...root._transportArgs, "-sS", "--max-time", "2", root._baseUrl + "/conversations/current"]

        stdout: SplitParser { onRead: data => { loadCurrentProcess.buf += data } }
        onRunningChanged: { if (running) { buf = ""; startedTurn = root.turnSeq; startedMidTurn = root.streaming } }

        onExited: (exitCode) => {
            if (exitCode !== 0) return
            // Quickshell starts a Process asynchronously and reruns one set running mid-run, so a read can begin after a send.
            if (startedMidTurn || startedTurn !== root.turnSeq) return
            try {
                let obj = JSON.parse(loadCurrentProcess.buf)
                let sameConv = (root.currentConvId === (obj.id || 0))
                if (!sameConv) root.revealActive = false
                root.currentConvId = obj.id || 0
                let msgs = obj.messages || []
                if (sameConv) root.followEditedMessage(msgs)
                let prev = sameConv ? root.messages : []
                const aligned = msgs.length === prev.length && prev.every((o, j) => !o.id || o.id === msgs[j].id)
                root.messages = msgs.map((m, i) => {
                    let msg = {
                        id: m.id,
                        role: m.role,
                        content: m.content,
                        attachments: m.attachments || [],
                        toolCalls: m.tool_calls || [],
                        createdAt: m.created_at || 0
                    }
                    // The backend never stores thinking, so this view's copy is the only one a read-back can keep.
                    let old = prev[i]
                    if (old && old.thinking && old.role === m.role && (old.id ? old.id === m.id : aligned))
                        Object.assign(msg, { thinking: old.thinking, thinkingMs: old.thinkingMs })
                    return msg
                })
                root.contextDropped = obj.context_dropped || 0
                if (root.currentConvId !== 0 && obj.model) {
                    root.currentModel = obj.model
                }
                root.currentThinking = obj.thinking === true
            } catch (e) {}
        }
    }

    Process {
        id: selectConvProcess
        running: false
        property string payload: ""
        property string buf: ""
        property int startedId: 0
        command: ["curl", ...root._transportArgs, "-sS", "--max-time", "2", "-X", "POST",
                  root._baseUrl + "/conversations/" + payload + "/select"]

        stdout: SplitParser { onRead: data => { selectConvProcess.buf += data } }
        // Quickshell reruns a busy Process with the newest payload, so match the id this run sent.
        onRunningChanged: { if (running) { buf = ""; startedId = parseInt(payload) } }

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.failOpening(selectConvProcess.startedId)
                return
            }
            loadCurrentProcess.running = true
        }
    }

    Process {
        id: deleteConvProcess
        running: false
        property string payload: ""
        property string buf: ""
        property int startedId: 0
        command: ["curl", ...root._transportArgs, "-sS", "--max-time", "2", "-X", "DELETE",
                  root._baseUrl + "/conversations/" + payload]

        stdout: SplitParser { onRead: data => { deleteConvProcess.buf += data } }
        // Quickshell reruns a busy Process with the newest payload, so match the id this run sent.
        onRunningChanged: { if (running) { buf = ""; startedId = parseInt(payload) } }

        onExited: (exitCode) => {
            const wasCurrent = deleteConvProcess.startedId === root.currentConvId
            if (exitCode !== 0) {
                // The conversation stayed, and a stop mid-reply skipped the read-back that gives its rows their ids.
                if (wasCurrent) root.loadCurrentConversation()
                return
            }
            let newCurrent = 0
            try {
                let obj = JSON.parse(deleteConvProcess.buf)
                newCurrent = obj.current_id || 0
            } catch (e) {}
            if (wasCurrent) {
                // A read that left before this answer may still carry the deleted conversation.
                root.turnSeq += 1
                root.currentConvId = newCurrent
                root.messages = []
                if (newCurrent !== 0) {
                    loadCurrentProcess.running = true
                } else {
                    if (root.defaultModel !== "") root.currentModel = root.defaultModel
                    root.currentThinking = false
                }
            }
            root.refreshConversations()
        }
    }

    Process {
        id: healthProcess
        running: false
        property string buf: ""
        command: ["curl", ...root._transportArgs, "-sSf", "--max-time", "2", root._baseUrl + "/health"]

        stdout: SplitParser {
            onRead: data => { healthProcess.buf += data }
        }

        onRunningChanged: { if (running) buf = "" }

        onExited: (exitCode) => {
            root.aiAvailable = (exitCode === 0)
            root.healthChecked = true
            root.healthStatus = ""
            if (exitCode === 0) {
                try {
                    let obj = JSON.parse(buf)
                    // An open conversation stays on the model it is bound to.
                    if (root.currentConvId === 0 && !root.streaming) root.currentModel = obj.model || ""
                    root.defaultModel = obj.model || ""
                    root.healthStatus = obj.status || ""
                    root.hasModel = obj.status === "ok"
                } catch (e) {}
                modelsProcess.running = true
                root.refreshConversations()
            }
        }
    }

    // Nothing else re-runs the check when the backend starts late or a model is set afterwards.
    Timer {
        id: healthRetry
        interval: 3000
        repeat: true
        running: root.visible && root.healthChecked && (!root.aiAvailable || !root.hasModel)
        onTriggered: healthProcess.running = true
    }

    Process {
        id: modelsProcess
        running: false
        property string buf: ""
        command: ["curl", ...root._transportArgs, "-sS", "--max-time", "2", root._baseUrl + "/models"]

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
        command: ["curl", ...root._transportArgs, "-sS", "-X", "PUT",
                  root._baseUrl + "/model",
                  "-H", "Content-Type: application/json",
                  "-d", payload]

        // PUT /model only sets the default for the next new conversation; this view keeps its own.
    }

    Component.onCompleted: {
        healthProcess.running = true
    }
}
