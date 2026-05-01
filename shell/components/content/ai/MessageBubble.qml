import QtQuick
import "../../common" as Common

Item {
    id: bubbleRoot

    required property var modelData
    required property int index
    required property var theme
    required property var modeManager
    required property int messagesLength
    required property bool streaming

    signal copyRequested(string content)

    readonly property bool isAssistant: modelData.role === "assistant"
    readonly property bool isLastAssistant: isAssistant && index === messagesLength - 1
    readonly property bool isThinking: streaming && isLastAssistant && modelData.content === ""
    readonly property bool hasContent: modelData.content !== ""

    height: delegateCol.height + (modeManager ? modeManager.scale(4) : 4)

    Column {
        id: delegateCol
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: bubbleRoot.modeManager ? bubbleRoot.modeManager.scale(4) : 4

        Item {
            visible: bubbleRoot.hasContent
            anchors.right: !bubbleRoot.isAssistant ? parent.right : undefined
            anchors.left: !bubbleRoot.isAssistant ? undefined : parent.left
            width: bubble.width + (bubbleRoot.isAssistant ? copyBtn.width + (bubbleRoot.modeManager ? bubbleRoot.modeManager.scale(6) : 6) : 0)
            height: bubble.height

            Rectangle {
                id: bubble
                anchors.left: !bubbleRoot.isAssistant ? undefined : parent.left
                anchors.right: !bubbleRoot.isAssistant ? parent.right : undefined

                readonly property real hPad: bubbleRoot.modeManager ? bubbleRoot.modeManager.scale(10) : 10
                readonly property real vPad: bubbleRoot.modeManager ? bubbleRoot.modeManager.scale(7) : 7
                readonly property real maxWidth: (bubbleRoot.parent ? bubbleRoot.parent.width : bubbleRoot.width) * 0.85

                width: Math.min(bubbleText.implicitWidth + hPad * 2, maxWidth)
                height: bubbleText.height + vPad * 2
                radius: bubbleRoot.modeManager ? bubbleRoot.modeManager.scale(12) : 12
                color: !bubbleRoot.isAssistant
                    ? (bubbleRoot.theme ? bubbleRoot.theme.chipActiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.20))
                    : (bubbleRoot.theme ? bubbleRoot.theme.chipInactiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.10))
                border.color: bubbleRoot.theme ? bubbleRoot.theme.chipInactiveBorder : Qt.rgba(0.55, 0.55, 0.68, 0.15)
                border.width: 1

                Text {
                    id: bubbleText
                    anchors.centerIn: parent
                    width: bubble.width - bubble.hPad * 2
                    text: bubbleRoot.modelData.content
                    wrapMode: Text.WordWrap
                    color: bubbleRoot.theme ? bubbleRoot.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: bubbleRoot.modeManager ? bubbleRoot.modeManager.scale(13) : 13
                    font.family: "M PLUS 2"
                    font.letterSpacing: 0.3
                }
            }

            Rectangle {
                id: copyBtn
                visible: bubbleRoot.isAssistant && bubbleHover.containsMouse
                anchors.left: bubble.right
                anchors.leftMargin: bubbleRoot.modeManager ? bubbleRoot.modeManager.scale(6) : 6
                anchors.verticalCenter: bubble.verticalCenter
                width: bubbleRoot.modeManager ? bubbleRoot.modeManager.scale(24) : 24
                height: bubbleRoot.modeManager ? bubbleRoot.modeManager.scale(24) : 24
                radius: bubbleRoot.modeManager ? bubbleRoot.modeManager.scale(6) : 6
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
                    color: bubbleRoot.theme ? bubbleRoot.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: bubbleRoot.modeManager ? bubbleRoot.modeManager.scale(12) : 12
                }

                MouseArea {
                    id: copyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bubbleRoot.copyRequested(bubbleRoot.modelData.content)
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

        Item {
            id: assistantBlob
            visible: bubbleRoot.isLastAssistant
            width: bubbleRoot.modeManager ? bubbleRoot.modeManager.scale(36) : 36
            height: bubbleRoot.modeManager ? bubbleRoot.modeManager.scale(36) : 36

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

            onVisibleChanged: {
                if (visible) switchPulse(bubbleRoot.isThinking)
            }

            Connections {
                target: bubbleRoot
                function onStreamingChanged() {
                    if (bubbleRoot.isLastAssistant) assistantBlob.switchPulse(bubbleRoot.streaming)
                }
            }

            Component.onCompleted: {
                switchPulse(bubbleRoot.isThinking)
            }

            transform: Scale {
                origin.x: assistantBlob.width / 2
                origin.y: assistantBlob.height / 2
                xScale: assistantBlob.pulseScale
                yScale: assistantBlob.pulseScale
            }

            Common.BlobEffect {
                anchors.fill: parent
                blobColor: bubbleRoot.theme ? bubbleRoot.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                layers: 3
                waveAmplitude: 3.0
                baseOpacity: 0.7
                animationSpeed: bubbleRoot.isThinking ? 0.1 : 0.03
                pointCount: 12
                running: bubbleRoot.isLastAssistant
            }
        }
    }
}
