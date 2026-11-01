pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

Item {
    id: delegateRoot

    property var modeManager: null
    property var theme: null
    property var icons: null
    property int msgIndex: 0
    property var message: ({ content: "" })
    property int messageCount: 0
    property int editingIndex: -1
    property bool streaming: false
    property bool busy: false
    property var openDetails: ({})
    property int contextDropped: 0
    property bool revealActive: false
    property int streamRevealed: 0

    signal userActivity()
    signal cancelEditRequested()
    signal submitEditRequested(string text)
    signal detailToggled(string key)
    signal retryRequested()
    signal editRequested()
    signal copyRequested(string text)

    implicitHeight: msgCol.implicitHeight + delegateRoot.modeManager.scale(8)

    readonly property bool isAssistant: delegateRoot.message.role === "assistant"
    readonly property bool hasServerId: !!delegateRoot.message.id
    readonly property bool isEditing: delegateRoot.editingIndex === delegateRoot.msgIndex
    readonly property bool isLatest: delegateRoot.msgIndex === delegateRoot.messageCount - 1
    readonly property bool isThinking: delegateRoot.streaming
        && isLatest
        && isAssistant
        && delegateRoot.message.content === ""
    readonly property bool showInlineOrb: isAssistant && isLatest
    readonly property int createdAt: delegateRoot.message.createdAt || 0
    readonly property string stamp: {
        if (delegateRoot.createdAt <= 0) return ""
        let d = new Date(delegateRoot.createdAt * 1000)
        let sameDay = d.toDateString() === new Date().toDateString()
        return Qt.formatDateTime(d, sameDay ? "HH:mm" : "MMM d HH:mm")
    }
    readonly property string reasoning: delegateRoot.message.thinking || ""
    readonly property real reasoningMs: delegateRoot.message.thinkingMs || 0
    readonly property string detailKey: String(delegateRoot.msgIndex)
    readonly property bool reasoningOpen: !!openDetails[detailKey]
    readonly property string reasoningLabel: reasoningMs > 0
        ? "Thought for " + (reasoningMs / 1000).toFixed(1) + "s"
        : "Thinking\u2026"
    readonly property bool startsContext: delegateRoot.contextDropped > 0
        && delegateRoot.msgIndex === delegateRoot.contextDropped
    readonly property var toolCalls: delegateRoot.message.toolCalls || []
    readonly property var attachments: delegateRoot.message.attachments || []
    readonly property string displayContent: (isAssistant && isLatest && delegateRoot.revealActive)
        ? delegateRoot.message.content.substring(0, delegateRoot.streamRevealed)
        : delegateRoot.message.content
    readonly property var assistantBlocks: isAssistant && !isThinking
        ? Theme.ChatText.parseBlocks(displayContent)
        : []

    HoverHandler { id: msgHover }

    Column {
        id: msgCol
        width: parent.width
        spacing: delegateRoot.modeManager.scale(6)

        Item {
            id: contextBoundary
            visible: delegateRoot.startsContext
            width: parent.width
            height: visible ? boundaryRow.implicitHeight + delegateRoot.modeManager.scale(12) : 0

            RowLayout {
                id: boundaryRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: delegateRoot.modeManager.scale(10)

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.rgba(0.55, 0.55, 0.75, 0.16)
                }

                Text {
                    text: "older messages are outside the context window"
                    color: delegateRoot.theme ? delegateRoot.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.6)
                    font.pixelSize: delegateRoot.modeManager.scale(10)
                    font.family: "M PLUS 2"
                    font.letterSpacing: 0.5
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.rgba(0.55, 0.55, 0.75, 0.16)
                }
            }
        }

        Item {
            id: bubbleAttachments
            visible: delegateRoot.attachments.length > 0
            width: parent.width
            height: visible ? attachedThumbs.height : 0

            AttachmentThumbs {
                id: attachedThumbs
                anchors.right: parent.right
                modeManager: delegateRoot.modeManager
                theme: delegateRoot.theme
                paths: delegateRoot.attachments
            }
        }

        Item {
            visible: !delegateRoot.isAssistant && delegateRoot.message.content !== ""
            width: parent.width
            height: visible ? userBubble.height : 0

            Rectangle {
                id: userBubble
                anchors.right: parent.right
                readonly property real hPad: delegateRoot.modeManager.scale(12)
                readonly property real vPad: delegateRoot.modeManager.scale(8)
                readonly property real trailingLeading: (userText.lineHeight - 1) * userMetrics.lineSpacing
                // Editing takes the full allowance so the text grows instead of reflowing.
                width: delegateRoot.isEditing
                    ? parent.width * 0.85
                    : Math.min(userText.implicitWidth + hPad * 2, parent.width * 0.85)
                height: (delegateRoot.isEditing
                    ? userEdit.implicitHeight
                    : userText.height - trailingLeading) + vPad * 2
                radius: delegateRoot.modeManager.scale(14)
                color: delegateRoot.theme ? delegateRoot.theme.chipActiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.20)
                border.color: delegateRoot.isEditing
                    ? (delegateRoot.theme ? delegateRoot.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
                    : (delegateRoot.theme ? delegateRoot.theme.chipInactiveBorder : Qt.rgba(0.55, 0.55, 0.68, 0.15))
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

                FontMetrics {
                    id: userMetrics
                    font: userText.font
                }

                Text {
                    id: userText
                    visible: !delegateRoot.isEditing
                    anchors.top: parent.top
                    anchors.topMargin: userBubble.vPad
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: userBubble.width - userBubble.hPad * 2
                    text: delegateRoot.message.content
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    color: delegateRoot.theme ? delegateRoot.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: delegateRoot.modeManager.scale(14)
                    font.family: "M PLUS 2"
                    font.letterSpacing: 0.3
                    lineHeight: 1.4
                }

                TextEdit {
                    id: userEdit
                    visible: delegateRoot.isEditing
                    anchors.top: parent.top
                    anchors.topMargin: userBubble.vPad
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: userBubble.width - userBubble.hPad * 2
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    color: delegateRoot.theme ? delegateRoot.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    selectionColor: delegateRoot.theme
                        ? Qt.rgba(delegateRoot.theme.glowPrimary.r, delegateRoot.theme.glowPrimary.g, delegateRoot.theme.glowPrimary.b, 0.35)
                        : Qt.rgba(0.65, 0.55, 0.85, 0.35)
                    font.pixelSize: delegateRoot.modeManager.scale(14)
                    font.family: "M PLUS 2"
                    font.letterSpacing: 0.3

                    onVisibleChanged: {
                        if (!visible) return
                        userEdit.text = delegateRoot.message.content
                        userEdit.cursorPosition = userEdit.text.length
                        userEdit.forceActiveFocus()
                    }

                    Keys.onPressed: (event) => {
                        delegateRoot.userActivity()
                        if (event.key === Qt.Key_Escape) {
                            delegateRoot.cancelEditRequested()
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            // Unaccepted, so TextEdit inserts the newline itself.
                            if (event.modifiers & Qt.ShiftModifier) return
                            delegateRoot.submitEditRequested(userEdit.text.trim())
                            event.accepted = true
                        }
                    }
                }
            }
        }

        Item {
            id: reasoningBlock
            width: parent.width
            visible: delegateRoot.reasoning !== ""
            height: visible ? reasoningCol.implicitHeight : 0

            Column {
                id: reasoningCol
                width: parent.width
                spacing: delegateRoot.modeManager.scale(4)

                Item {
                    width: reasoningHeader.implicitWidth
                    height: reasoningHeader.implicitHeight

                    Row {
                        id: reasoningHeader
                        spacing: delegateRoot.modeManager.scale(6)

                        Text {
                            text: delegateRoot.reasoningOpen ? "\u25be" : "\u25b8"
                            color: delegateRoot.theme ? delegateRoot.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.6)
                            font.pixelSize: delegateRoot.modeManager.scale(10)
                        }

                        Text {
                            text: delegateRoot.reasoningLabel
                            color: delegateRoot.theme ? delegateRoot.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.6)
                            font.pixelSize: delegateRoot.modeManager.scale(10)
                            font.family: "M PLUS 2"
                            font.italic: true
                            font.letterSpacing: 0.4
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: delegateRoot.detailToggled(delegateRoot.detailKey)
                    }
                }

                Text {
                    width: parent.width
                    visible: delegateRoot.reasoningOpen
                    text: delegateRoot.reasoning
                    textFormat: Text.PlainText
                    color: delegateRoot.theme ? delegateRoot.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.6)
                    font.pixelSize: delegateRoot.modeManager.scale(11)
                    font.family: "M PLUS 2"
                    wrapMode: Text.Wrap
                }
            }
        }

        ToolChips {
            width: parent.width
            visible: delegateRoot.isAssistant && delegateRoot.toolCalls.length > 0
            modeManager: delegateRoot.modeManager
            theme: delegateRoot.theme
            icons: delegateRoot.icons
            toolCalls: delegateRoot.toolCalls
            openKeys: delegateRoot.openDetails
            keyPrefix: delegateRoot.detailKey
            onToggleRequested: key => delegateRoot.detailToggled(key)
        }

        Repeater {
            model: delegateRoot.assistantBlocks.length

            delegate: Item {
                id: blockItem
                required property int index
                width: msgCol.width
                readonly property var block: delegateRoot.assistantBlocks[index] || ({ type: "", lang: "", content: "" })
                implicitHeight: blockText.visible ? blockText.implicitHeight : codeBlock.implicitHeight

                Text {
                    id: blockText
                    visible: blockItem.block.type === "text"
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: visible ? blockItem.block.content : ""
                    textFormat: Text.MarkdownText
                    wrapMode: Text.WordWrap
                    color: delegateRoot.theme ? delegateRoot.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                    font.pixelSize: delegateRoot.modeManager.scale(14)
                    font.family: "M PLUS 2"
                    font.letterSpacing: 0.3
                    lineHeight: 1.5
                    linkColor: delegateRoot.theme ? delegateRoot.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1.0)
                    onLinkActivated: link => { if (/^https?:\/\//i.test(link)) Qt.openUrlExternally(link) }
                }

                CodeBlock {
                    id: codeBlock
                    visible: blockItem.block.type === "code"
                    anchors.left: parent.left
                    anchors.right: parent.right
                    modeManager: delegateRoot.modeManager
                    theme: delegateRoot.theme
                    icons: delegateRoot.icons
                    lang: visible ? blockItem.block.lang : ""
                    code: visible ? blockItem.block.content : ""
                    onCopyRequested: text => delegateRoot.copyRequested(text)
                }
            }
        }

        Item {
            width: parent.width
            height: msgActions.height
            visible: delegateRoot.message.content !== ""

            MessageActions {
                id: msgActions
                x: delegateRoot.isAssistant ? 0 : parent.width - width
                modeManager: delegateRoot.modeManager
                theme: delegateRoot.theme
                icons: delegateRoot.icons
                canRetry: delegateRoot.isAssistant && !delegateRoot.busy
                    && delegateRoot.hasServerId
                canEdit: !delegateRoot.isAssistant && !delegateRoot.busy
                    && delegateRoot.hasServerId && !delegateRoot.isEditing
                timestamp: delegateRoot.stamp
                opacity: msgHover.hovered ? 1.0 : 0.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }

                onCopyRequested: delegateRoot.copyRequested(delegateRoot.message.content)
                onRetryRequested: delegateRoot.retryRequested()
                onEditRequested: delegateRoot.editRequested()
            }
        }

        // Reserves space for the global orb that lands here.
        Item {
            visible: delegateRoot.isAssistant && delegateRoot.isLatest
            width: 1
            height: delegateRoot.modeManager.scale(40)
        }

    }
}
