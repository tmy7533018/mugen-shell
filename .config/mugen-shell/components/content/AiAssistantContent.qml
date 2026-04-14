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
    property bool healthChecked: false

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
        chatProcess.payload = JSON.stringify({ message: text })
        chatProcess.running = true
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
        onClicked: modeManager.closeAllModes()
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

                Common.GlowText {
                    text: "Assistant"
                    font.pixelSize: modeManager.scale(20)
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    font.letterSpacing: 1.5
                    color: Qt.rgba(0.95, 0.93, 0.98, 0.95)

                    enableGlow: true
                    glowColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6)
                    glowSamples: 20
                    glowRadius: 12
                    glowSpread: 0.5
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 12

                    Rectangle {
                        width: 32
                        height: 32
                        radius: width / 2
                        visible: root.aiAvailable
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
                        text: "Install mugen-ai and start the service:\ngithub.com/tmy7533018/mugen-ai"
                        color: root.theme ? root.theme.textFaint : Qt.rgba(0.72, 0.72, 0.82, 0.70)
                        font.pixelSize: modeManager.scale(12)
                        font.family: "M PLUS 2"
                        lineHeight: 1.4
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: "systemctl --user enable --now mugen-ai.service"
                        color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                        font.pixelSize: modeManager.scale(11)
                        font.family: "monospace"
                    }
                }
            }

            ListView {
                id: messageList
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: modeManager.scale(600)
                Layout.preferredHeight: modeManager.scale(260)
                visible: root.aiAvailable
                clip: true
                spacing: modeManager.scale(8)
                model: root.messages
                boundsBehavior: Flickable.StopAtBounds

                onCountChanged: positionViewAtEnd()
                Connections {
                    target: root
                    function onMessagesChanged() { messageList.positionViewAtEnd() }
                }

                delegate: Item {
                    width: messageList.width
                    height: bubble.height + modeManager.scale(4)

                    Rectangle {
                        id: bubble
                        anchors.right: modelData.role === "user" ? parent.right : undefined
                        anchors.left: modelData.role === "user" ? undefined : parent.left
                        width: bubbleText.width + modeManager.scale(20)
                        height: bubbleText.height + modeManager.scale(14)
                        radius: modeManager.scale(12)
                        color: modelData.role === "user"
                            ? (root.theme ? root.theme.chipActiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.20))
                            : (root.theme ? root.theme.chipInactiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.10))
                        border.color: root.theme ? root.theme.chipInactiveBorder : Qt.rgba(0.55, 0.55, 0.68, 0.15)
                        border.width: 1

                        Text {
                            id: bubbleText
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, messageList.width * 0.8)
                            text: modelData.content
                            wrapMode: Text.WordWrap
                            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                            font.pixelSize: modeManager.scale(13)
                            font.family: "M PLUS 2"
                            font.letterSpacing: 0.3
                            lineHeight: 1.3
                        }
                    }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: modeManager.scale(600)
                Layout.preferredHeight: modeManager.scale(40)
                visible: root.aiAvailable
                color: "transparent"
                border.color: root.theme ? root.theme.surfaceBorder : Qt.rgba(0.70, 0.65, 0.90, 0.3)
                border.width: 2
                radius: height / 2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: modeManager.scale(20)
                    anchors.rightMargin: modeManager.scale(8)
                    spacing: modeManager.scale(12)

                    TextInput {
                        id: inputField
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                        font.pixelSize: modeManager.scale(13)
                        font.family: "M PLUS 2"
                        selectByMouse: true
                        selectionColor: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                        focus: modeManager.isMode("ai")
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Ask anything..."
                            color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                            font: inputField.font
                            visible: inputField.text.length === 0 && !inputField.activeFocus
                            opacity: 0.5
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                let txt = inputField.text.trim()
                                if (txt.length > 0 && !root.streaming) {
                                    root.sendMessage(txt)
                                    inputField.text = ""
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                modeManager.closeAllModes()
                                event.accepted = true
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: modeManager.scale(30)
                        Layout.preferredHeight: modeManager.scale(30)
                        Layout.alignment: Qt.AlignVCenter
                        radius: width / 2
                        color: root.streaming
                            ? Qt.rgba(0.45, 0.45, 0.60, 0.15)
                            : Qt.rgba(0.45, 0.65, 0.90, sendMouse.containsMouse ? 0.45 : 0.30)
                        opacity: root.streaming ? 0.6 : 1.0

                        Behavior on color {
                            ColorAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.streaming ? "···" : "→"
                            color: Qt.rgba(0.65, 0.85, 1.0, sendMouse.containsMouse ? 1.0 : 0.9)
                            font.pixelSize: modeManager.scale(15)
                            font.family: "M PLUS 2"
                            font.weight: Font.Medium
                            scale: sendMouse.containsMouse && !root.streaming ? 1.2 : 1.0

                            Behavior on scale {
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
                        }

                        MouseArea {
                            id: sendMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.streaming
                            onClicked: {
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
        command: ["curl", "-sSf", "--max-time", "2", "http://127.0.0.1:11435/health"]

        onExited: (exitCode) => {
            root.aiAvailable = (exitCode === 0)
            root.healthChecked = true
        }
    }

    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("ai", root)
        }
    }
}
