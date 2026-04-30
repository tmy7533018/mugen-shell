import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../ui" as UI
import "../common" as Common

FocusScope {
    id: root

    required property var modeManager
    property var theme
    property var icons

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(440),
        "leftMargin": modeManager.scale(620),
        "rightMargin": modeManager.scale(620),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })

    property var messages: []
    property bool streaming: false
    property bool aiAvailable: false
    property bool hasModel: false
    property bool healthChecked: false
    property bool userScrolled: false
    property string currentModel: ""
    property var availableModels: []
    property bool modelDropdownOpen: false

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
        chatProcess.payload = JSON.stringify({ message: text })
        chatProcess.running = true
    }

    function stopStreaming() {
        if (!streaming) return
        chatProcess.signal(15) // SIGTERM
        streaming = false
    }

    function clearHistory() {
        messages = []
        clearProcess.running = true
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("ai")) {
                healthProcess.running = true
                focusTimer.restart()
            } else {
                if (streaming) stopStreaming()
                modelDropdownOpen = false
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

    MouseArea {
        anchors.fill: parent
        z: 1.5
        enabled: modeManager.isMode("ai")
        visible: enabled
        hoverEnabled: true
        onClicked: {
            if (root.modelDropdownOpen) root.modelDropdownOpen = false
            else modeManager.closeAllModes()
        }
        onPositionChanged: {
            if (modeManager.isMode("ai")) modeManager.bump()
        }
    }

    Item {
        id: panel
        anchors.fill: parent
        anchors.leftMargin: modeManager.scale(32)
        anchors.rightMargin: modeManager.scale(32)
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
                    PauseAnimation { duration: 300 }
                    NumberAnimation { property: "opacity"; duration: 400; easing.type: Easing.InOutCubic }
                }
            },
            Transition {
                from: "visible"
                to: ""
                NumberAnimation { property: "opacity"; duration: 300; easing.type: Easing.OutCubic }
            }
        ]

        ColumnLayout {
            anchors.centerIn: parent
            spacing: modeManager.scale(16)

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: modeManager.scale(600)
                spacing: modeManager.scale(12)
                z: 100

                Common.GlowText {
                    text: "Assistant"
                    font.pixelSize: modeManager.scale(20)
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    font.letterSpacing: 1.5
                    color: (theme ? theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))

                    enableGlow: true
                    glowColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6)
                    glowSamples: 20
                    glowRadius: 12
                    glowSpread: 0.5
                }

                // Model selector
                Item {
                    visible: root.aiAvailable && root.currentModel !== ""
                    Layout.preferredWidth: modelLabel.width + modeManager.scale(20)
                    Layout.preferredHeight: modeManager.scale(26)
                    z: 100

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: modelSelectorMouse.containsMouse
                            ? (root.theme ? root.theme.chipActiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.25))
                            : (root.theme ? root.theme.chipInactiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.12))
                        border.color: root.theme ? root.theme.chipInactiveBorder : Qt.rgba(0.55, 0.55, 0.68, 0.15)
                        border.width: 1

                        Behavior on color {
                            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        Text {
                            id: modelLabel
                            anchors.centerIn: parent
                            text: root.currentModel + (root.modelDropdownOpen ? "  ▴" : "  ▾")
                            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                            font.pixelSize: modeManager.scale(11)
                            font.family: "M PLUS 2"
                            opacity: modelSelectorMouse.containsMouse ? 1.0 : 0.7

                            Behavior on opacity {
                                NumberAnimation { duration: 200 }
                            }
                        }

                        MouseArea {
                            id: modelSelectorMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.modelDropdownOpen = !root.modelDropdownOpen
                        }
                    }

                    // Dropdown
                    Column {
                        visible: root.modelDropdownOpen
                        anchors.top: parent.bottom
                        anchors.topMargin: modeManager.scale(4)
                        anchors.horizontalCenter: parent.horizontalCenter
                        z: 10

                        Rectangle {
                            width: modelDropdownCol.width + modeManager.scale(12)
                            height: modelDropdownCol.height + modeManager.scale(12)
                            radius: modeManager.scale(10)
                            color: root.theme
                                ? Qt.rgba(root.theme.surfaceGlass.r, root.theme.surfaceGlass.g, root.theme.surfaceGlass.b, 0.9)
                                : Qt.rgba(0.08, 0.05, 0.15, 0.9)
                            border.color: root.theme ? root.theme.surfaceBorder : Qt.rgba(0.55, 0.55, 0.68, 0.2)
                            border.width: 1

                            Column {
                                id: modelDropdownCol
                                anchors.centerIn: parent
                                spacing: modeManager.scale(2)

                                Repeater {
                                    model: root.availableModels

                                    Rectangle {
                                        required property string modelData
                                        required property int index
                                        width: dropdownItemText.implicitWidth + modeManager.scale(24)
                                        height: dropdownItemText.implicitHeight + modeManager.scale(10)
                                        radius: modeManager.scale(6)
                                        color: dropdownItemMouse.containsMouse
                                            ? (root.theme ? root.theme.chipActiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.3))
                                            : "transparent"

                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }

                                        Text {
                                            id: dropdownItemText
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: modelData === root.currentModel
                                                ? (root.theme ? root.theme.accent : Qt.rgba(0.65, 0.85, 1.0, 1.0))
                                                : (root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))
                                            font.pixelSize: modeManager.scale(11)
                                            font.family: "M PLUS 2"
                                            font.weight: modelData === root.currentModel ? Font.Medium : Font.Normal
                                        }

                                        MouseArea {
                                            id: dropdownItemMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modelData !== root.currentModel) {
                                                    if (root.streaming) root.stopStreaming()
                                                    root.currentModel = modelData
                                                    switchModelProcess.payload = JSON.stringify({ model: modelData })
                                                    switchModelProcess.running = true
                                                }
                                                root.modelDropdownOpen = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 12

                    Rectangle {
                        width: 32
                        height: 32
                        radius: width / 2
                        visible: root.aiAvailable && root.hasModel
                        color: Qt.rgba(0.75, 0.45, 0.45, clearMouse.containsMouse ? 0.4 : 0.3)

                        Behavior on color {
                            ColorAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }

                        UI.SvgIcon {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: icons ? icons.trashSvg : ""
                            color: Qt.rgba(0.95, 0.55, 0.65, clearMouse.containsMouse ? 1.0 : 0.9)
                            opacity: clearMouse.containsMouse ? 1.0 : 0.9
                            scale: clearMouse.containsMouse ? 1.2 : 1.0

                            Behavior on opacity {
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }

                            Behavior on scale {
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearHistory()
                        }
                    }
                }
            }

            // Service unavailable state
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: modeManager.scale(600)
                Layout.preferredHeight: modeManager.scale(260)
                visible: !root.aiAvailable && root.healthChecked

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: modeManager.scale(10)

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "mugen-ai is not running"
                        color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                        font.pixelSize: modeManager.scale(15)
                        font.weight: Font.Medium
                        font.family: "M PLUS 2"
                        font.letterSpacing: 0.5
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: "Install mugen-ai from this repo:"
                        color: root.theme ? root.theme.textFaint : Qt.rgba(0.72, 0.72, 0.82, 0.70)
                        font.pixelSize: modeManager.scale(12)
                        font.family: "M PLUS 2"
                        lineHeight: 1.4
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: "cd dotfiles-mugen && make install-ai"
                        color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                        font.pixelSize: modeManager.scale(11)
                        font.family: "monospace"
                    }
                }
            }

            // No models configured state
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: modeManager.scale(600)
                Layout.preferredHeight: modeManager.scale(260)
                visible: root.aiAvailable && !root.hasModel

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: modeManager.scale(10)

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No models available"
                        color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                        font.pixelSize: modeManager.scale(15)
                        font.weight: Font.Medium
                        font.family: "M PLUS 2"
                        font.letterSpacing: 0.5
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: "Pull an Ollama model (e.g. `ollama pull gemma3:4b`)\nor configure Gemini in ~/.config/mugen-ai/config.toml"
                        color: root.theme ? root.theme.textFaint : Qt.rgba(0.72, 0.72, 0.82, 0.70)
                        font.pixelSize: modeManager.scale(12)
                        font.family: "M PLUS 2"
                        lineHeight: 1.4
                    }
                }
            }

            // Welcome state
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: modeManager.scale(600)
                Layout.preferredHeight: modeManager.scale(260)
                visible: root.aiAvailable && root.hasModel && root.messages.length === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: modeManager.scale(18)

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "What can I help you with?"
                        color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                        font.pixelSize: modeManager.scale(16)
                        font.weight: Font.Light
                        font.family: "M PLUS 2"
                        font.letterSpacing: 0.5
                        opacity: 0.8
                    }

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: modeManager.scale(600)
                        implicitHeight: chipRow.height

                        Row {
                            id: chipRow
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: modeManager.scale(10)

                        Repeater {
                            model: ["What's the weather?", "Summarize a topic", "Help me write"]

                            Rectangle {
                                required property string modelData
                                required property int index
                                width: chipText.implicitWidth + modeManager.scale(24)
                                height: chipText.implicitHeight + modeManager.scale(14)
                                radius: height / 2
                                color: chipMouse.containsMouse
                                    ? (root.theme ? root.theme.chipActiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.25))
                                    : (root.theme ? root.theme.chipInactiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.12))
                                border.color: root.theme ? root.theme.chipInactiveBorder : Qt.rgba(0.55, 0.55, 0.68, 0.15)
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }

                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                                    font.pixelSize: modeManager.scale(12)
                                    font.family: "M PLUS 2"
                                    opacity: chipMouse.containsMouse ? 1.0 : 0.7
                                    Behavior on opacity {
                                        NumberAnimation { duration: 200 }
                                    }
                                }

                                MouseArea {
                                    id: chipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.sendMessage(modelData)
                                    }
                                }
                            }
                        }
                        } // Row
                    } // Item
                }
            }

            // Message list
            ListView {
                id: messageList
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: modeManager.scale(600)
                Layout.preferredHeight: modeManager.scale(260)
                visible: root.aiAvailable && root.hasModel && root.messages.length > 0
                clip: true
                spacing: modeManager.scale(8)
                model: root.messages
                boundsBehavior: Flickable.StopAtBounds

                onMovingChanged: {
                    if (moving && !atYEnd) root.userScrolled = true
                }

                onAtYEndChanged: {
                    if (atYEnd) root.userScrolled = false
                }

                onCountChanged: {
                    if (!root.userScrolled) positionViewAtEnd()
                }

                Connections {
                    target: root
                    function onMessagesChanged() {
                        if (!root.userScrolled) messageList.positionViewAtEnd()
                    }
                }

                delegate: Item {
                    readonly property bool isAssistant: modelData.role === "assistant"
                    readonly property bool isLastAssistant: isAssistant && index === root.messages.length - 1
                    readonly property bool isThinking: root.streaming && isLastAssistant && modelData.content === ""
                    readonly property bool hasContent: modelData.content !== ""

                    width: messageList.width
                    height: delegateCol.height + modeManager.scale(4)

                    Column {
                        id: delegateCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: modeManager.scale(4)

                        // Message bubble + copy button row
                        Item {
                            visible: hasContent
                            anchors.right: !isAssistant ? parent.right : undefined
                            anchors.left: !isAssistant ? undefined : parent.left
                            width: bubble.width + (isAssistant ? copyBtn.width + modeManager.scale(6) : 0)
                            height: bubble.height

                            Rectangle {
                                id: bubble
                                anchors.left: !isAssistant ? undefined : parent.left
                                anchors.right: !isAssistant ? parent.right : undefined

                                readonly property real hPad: modeManager.scale(10)
                                readonly property real vPad: modeManager.scale(7)
                                readonly property real maxWidth: messageList.width * 0.85

                                width: Math.min(bubbleText.implicitWidth + hPad * 2, maxWidth)
                                height: bubbleText.height + vPad * 2
                                radius: modeManager.scale(12)
                                color: !isAssistant
                                    ? (root.theme ? root.theme.chipActiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.20))
                                    : (root.theme ? root.theme.chipInactiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.10))
                                border.color: root.theme ? root.theme.chipInactiveBorder : Qt.rgba(0.55, 0.55, 0.68, 0.15)
                                border.width: 1

                                Text {
                                    id: bubbleText
                                    anchors.centerIn: parent
                                    width: bubble.width - bubble.hPad * 2
                                    text: modelData.content
                                    wrapMode: Text.WordWrap
                                    color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                                    font.pixelSize: modeManager.scale(13)
                                    font.family: "M PLUS 2"
                                    font.letterSpacing: 0.3
                                }
                            }

                            // Copy button — right of bubble
                            Rectangle {
                                id: copyBtn
                                visible: isAssistant && bubbleHover.containsMouse
                                anchors.left: bubble.right
                                anchors.leftMargin: modeManager.scale(6)
                                anchors.verticalCenter: bubble.verticalCenter
                                width: modeManager.scale(24)
                                height: modeManager.scale(24)
                                radius: modeManager.scale(6)
                                color: copyMouse.containsMouse ? Qt.rgba(0.55, 0.55, 0.68, 0.4) : Qt.rgba(0.55, 0.55, 0.68, 0.25)
                                opacity: bubbleHover.containsMouse ? 1.0 : 0.0

                                Behavior on opacity {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "⧉"
                                    color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                                    font.pixelSize: modeManager.scale(12)
                                }

                                MouseArea {
                                    id: copyMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        copyProcess.text = modelData.content
                                        copyProcess.running = true
                                    }
                                }
                            }

                            MouseArea {
                                id: bubbleHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                propagateComposedEvents: true
                            }
                        }

                        // Blob — only on last assistant message, breathes while thinking
                        Item {
                            id: assistantBlob
                            visible: isLastAssistant
                            width: modeManager.scale(36)
                            height: modeManager.scale(36)

                            property real pulseScale: 1.0

                            SequentialAnimation {
                                id: idlePulse
                                loops: Animation.Infinite
                                NumberAnimation { target: assistantBlob; property: "pulseScale"; to: 1.15; duration: 1200; easing.type: Easing.InOutSine }
                                NumberAnimation { target: assistantBlob; property: "pulseScale"; to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
                            }

                            SequentialAnimation {
                                id: thinkingPulse
                                loops: Animation.Infinite
                                NumberAnimation { target: assistantBlob; property: "pulseScale"; to: 1.6; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { target: assistantBlob; property: "pulseScale"; to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }

                            function switchPulse(thinking) {
                                idlePulse.stop()
                                thinkingPulse.stop()
                                if (thinking) thinkingPulse.start()
                                else idlePulse.start()
                            }

                            Connections {
                                target: root
                                function onStreamingChanged() {
                                    if (isLastAssistant) assistantBlob.switchPulse(root.streaming)
                                }
                            }

                            Component.onCompleted: {
                                switchPulse(isThinking)
                            }

                            transform: Scale {
                                origin.x: assistantBlob.width / 2
                                origin.y: assistantBlob.height / 2
                                xScale: assistantBlob.pulseScale
                                yScale: assistantBlob.pulseScale
                            }

                            Common.BlobEffect {
                                anchors.fill: parent
                                blobColor: root.theme ? root.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                                layers: 3
                                waveAmplitude: 3.0
                                baseOpacity: 0.7
                                animationSpeed: isThinking ? 0.1 : 0.03
                                pointCount: 12
                                running: isLastAssistant
                            }
                        }
                    } // Column
                }
            }

            // Input area
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: modeManager.scale(600)
                Layout.preferredHeight: Math.min(Math.max(inputField.contentHeight + modeManager.scale(16), modeManager.scale(40)), modeManager.scale(120))
                visible: root.aiAvailable && root.hasModel
                color: "transparent"
                border.color: root.theme ? root.theme.surfaceBorder : Qt.rgba(0.70, 0.65, 0.90, 0.3)
                border.width: 2
                radius: height > modeManager.scale(50) ? modeManager.scale(16) : height / 2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: modeManager.scale(20)
                    anchors.rightMargin: modeManager.scale(8)
                    anchors.topMargin: modeManager.scale(4)
                    anchors.bottomMargin: modeManager.scale(4)
                    spacing: modeManager.scale(12)

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Ask anything..."
                            color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                            font.pixelSize: modeManager.scale(13)
                            font.family: "M PLUS 2"
                            visible: inputField.text.length === 0 && !inputField.activeFocus
                            opacity: 0.5
                        }

                        Flickable {
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: inputField.contentHeight
                            topMargin: Math.max(0, (height - contentHeight) / 2)
                            clip: true
                            flickableDirection: Flickable.VerticalFlick
                            boundsBehavior: Flickable.StopAtBounds

                            TextEdit {
                                id: inputField
                                width: parent.width
                                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                                font.pixelSize: modeManager.scale(13)
                                font.family: "M PLUS 2"
                                selectByMouse: true
                                selectionColor: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                                focus: modeManager.isMode("ai")
                                wrapMode: TextEdit.Wrap

                                onTextChanged: {
                                    if (modeManager.isMode("ai")) modeManager.bump()
                                }

                                Keys.onPressed: (event) => {
                                    if (modeManager.isMode("ai")) modeManager.bump()
                                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                        let txt = inputField.text.trim()
                                        if (txt.length > 0 && !root.streaming) {
                                            root.sendMessage(txt)
                                            inputField.text = ""
                                        }
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Escape) {
                                        modeManager.closeAllModes()
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_L && (event.modifiers & Qt.ControlModifier)) {
                                        root.clearHistory()
                                        event.accepted = true
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: modeManager.scale(30)
                        Layout.preferredHeight: modeManager.scale(30)
                        Layout.alignment: Qt.AlignVCenter
                        radius: width / 2
                        color: root.streaming
                            ? Qt.rgba(0.75, 0.45, 0.45, sendMouse.containsMouse ? 0.5 : 0.35)
                            : Qt.rgba(0.45, 0.65, 0.90, sendMouse.containsMouse ? 0.45 : 0.30)

                        Behavior on color {
                            ColorAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.streaming ? "■" : "→"
                            color: root.streaming
                                ? Qt.rgba(0.95, 0.55, 0.65, sendMouse.containsMouse ? 1.0 : 0.9)
                                : Qt.rgba(0.65, 0.85, 1.0, sendMouse.containsMouse ? 1.0 : 0.9)
                            font.pixelSize: root.streaming ? modeManager.scale(12) : modeManager.scale(15)
                            font.family: "M PLUS 2"
                            font.weight: Font.Medium
                            scale: sendMouse.containsMouse ? 1.2 : 1.0

                            Behavior on scale {
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
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
    }

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
        }
    }

    Process {
        id: clearProcess
        running: false
        command: ["curl", "-sS", "-X", "DELETE", "http://127.0.0.1:11435/history"]
    }

    Process {
        id: healthProcess
        running: false
        property string buf: ""
        command: ["curl", "-sSf", "--max-time", "2", "http://127.0.0.1:11435/health"]

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
                    root.hasModel = obj.status === "ok"
                } catch (e) {}
                modelsProcess.running = true
            }
        }
    }

    Process {
        id: modelsProcess
        running: false
        property string buf: ""
        command: ["curl", "-sS", "--max-time", "2", "http://127.0.0.1:11435/models"]

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
                  "http://127.0.0.1:11435/model",
                  "-H", "Content-Type: application/json",
                  "-d", payload]

        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.messages = []
            }
        }
    }

    Process {
        id: copyProcess
        property string text: ""
        running: false
        command: ["wl-copy", text]
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
