pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import "../../ui" as UI
import "../../../lib" as Theme

Item {
    id: inputBar

    required property var modeManager
    required property var theme
    required property var icons
    property bool streaming: false
    property bool rewinding: false
    property bool busy: false
    property string turnFailure: ""
    property var pendingAttachments: []
    property int maxAttachments: 0
    property alias field: inputField

    signal userActivity()
    signal newChatRequested()
    signal sendRequested(string text)
    signal stopClicked()
    signal attachRequested()
    signal removeAttachmentRequested(int index)

    readonly property real rowHeight: inputBar.modeManager.scale(46)
    height: failureStrip.height + attachStrip.height
        + Math.max(rowHeight, inputFlick.height + inputBar.modeManager.scale(22))

    Behavior on height { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: inputField.activeFocus
            ? (inputBar.theme ? Qt.rgba(inputBar.theme.glowPrimary.r, inputBar.theme.glowPrimary.g, inputBar.theme.glowPrimary.b, 0.85) : Qt.rgba(0.65, 0.55, 0.85, 0.85))
            : Qt.rgba(0.5, 0.5, 0.65, 0.25)

        Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

        layer.enabled: inputField.activeFocus
        layer.effect: Glow {
            samples: 18
            radius: 8
            spread: 0.3
            color: inputBar.theme ? Qt.rgba(inputBar.theme.glowPrimary.r, inputBar.theme.glowPrimary.g, inputBar.theme.glowPrimary.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6)
            transparentBorder: true
        }
    }

    Item {
        id: failureStrip
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: inputBar.turnFailure !== ""
            ? failureText.implicitHeight + inputBar.modeManager.scale(10)
            : 0
        clip: true

        Behavior on height { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }

        Text {
            id: failureText
            anchors.left: parent.left
            anchors.leftMargin: inputBar.modeManager.scale(42)
            anchors.right: parent.right
            anchors.rightMargin: inputBar.modeManager.scale(12)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: inputBar.modeManager.scale(6)
            text: inputBar.turnFailure
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: inputBar.theme ? inputBar.theme.danger : Qt.rgba(0.95, 0.55, 0.65, 1.0)
            font.pixelSize: inputBar.modeManager.scale(11)
            font.family: "M PLUS 2"
        }
    }

    Item {
        id: attachStrip
        anchors.top: failureStrip.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: inputBar.pendingAttachments.length > 0
            ? composerThumbs.height + inputBar.modeManager.scale(10)
            : 0
        clip: true

        Behavior on height { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }

        AttachmentThumbs {
            id: composerThumbs
            anchors.left: parent.left
            anchors.leftMargin: inputBar.modeManager.scale(42)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: inputBar.modeManager.scale(6)
            modeManager: inputBar.modeManager
            theme: inputBar.theme
            paths: inputBar.pendingAttachments
            thumbSize: inputBar.modeManager.scale(52)
            removable: true
            onRemoveRequested: index => inputBar.removeAttachmentRequested(index)
        }
    }

    Flickable {
        id: inputFlick
        anchors.left: attachIcon.right
        anchors.leftMargin: inputBar.modeManager.scale(8)
        anchors.right: sendIcon.left
        anchors.rightMargin: inputBar.modeManager.scale(12)
        // Grows symmetrically, so a single line sits where it did before Shift+Enter existed.
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: (failureStrip.height + attachStrip.height) / 2
        height: Math.min(inputField.implicitHeight, inputBar.modeManager.scale(110))
        contentWidth: width
        contentHeight: inputField.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        function revealCursor() {
            let r = inputField.cursorRectangle
            if (r.y < contentY) contentY = r.y
            else if (r.y + r.height > contentY + height) contentY = r.y + r.height - height
        }

        TextEdit {
            id: inputField
            width: inputFlick.width
            color: inputBar.theme ? inputBar.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
            font.pixelSize: inputBar.modeManager.scale(15)
            font.family: "M PLUS 2"
            font.letterSpacing: 0.3
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            inputMethodHints: Qt.ImhNone
            selectionColor: inputBar.theme ? Qt.rgba(inputBar.theme.glowPrimary.r, inputBar.theme.glowPrimary.g, inputBar.theme.glowPrimary.b, 0.35) : Qt.rgba(0.65, 0.55, 0.85, 0.35)

            onCursorRectangleChanged: inputFlick.revealCursor()

            Keys.onPressed: (event) => {
                inputBar.userActivity()
                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_N) {
                    inputBar.newChatRequested()
                    inputField.text = ""
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    // Unaccepted, so TextEdit inserts the newline itself.
                    if (event.modifiers & Qt.ShiftModifier) return
                    let txt = inputField.text.trim()
                    if ((txt.length > 0 || inputBar.pendingAttachments.length > 0) && !inputBar.busy) {
                        inputBar.sendRequested(txt)
                    }
                    event.accepted = true
                }
            }

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                width: parent.width
                text: inputBar.streaming ? "Thinking..." : "Ask anything"
                color: inputBar.theme ? inputBar.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.6)
                font.pixelSize: parent.font.pixelSize
                font.family: parent.font.family
                font.letterSpacing: parent.font.letterSpacing
                font.italic: true
                visible: parent.text.length === 0
                    && parent.preeditText.length === 0
                    && !parent.inputMethodComposing
            }
        }
    }

    Item {
        id: attachIcon
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: inputBar.modeManager.scale(6)
        width: inputBar.modeManager.scale(34)
        height: inputBar.modeManager.scale(34)
        enabled: inputBar.pendingAttachments.length < inputBar.maxAttachments
        opacity: !enabled ? 0.25 : (attachHover.hovered ? 1.0 : 0.5)

        Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: attachHover.hovered
                ? (inputBar.theme ? Qt.rgba(inputBar.theme.glowSecondary.r, inputBar.theme.glowSecondary.g, inputBar.theme.glowSecondary.b, 0.32) : Qt.rgba(0.55, 0.75, 0.85, 0.32))
                : "transparent"

            Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
        }

        UI.SvgIcon {
            anchors.centerIn: parent
            width: inputBar.modeManager.scale(17)
            height: inputBar.modeManager.scale(17)
            source: inputBar.icons ? inputBar.icons.plusSvg : ""
            color: inputBar.theme ? inputBar.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
        }

        HoverHandler {
            id: attachHover
            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                inputBar.userActivity()
                inputBar.attachRequested()
            }
        }
    }



    Item {
        id: sendIcon
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: inputBar.modeManager.scale(6)
        width: inputBar.modeManager.scale(34)
        height: inputBar.modeManager.scale(34)
        opacity: (inputBar.streaming || inputField.text.trim().length > 0
            || inputBar.pendingAttachments.length > 0) ? 1.0 : 0.35

        Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: width / 2
            color: sendMouse.containsMouse
                ? (inputBar.theme ? Qt.rgba(inputBar.theme.glowPrimary.r, inputBar.theme.glowPrimary.g, inputBar.theme.glowPrimary.b, 0.32) : Qt.rgba(0.65, 0.55, 0.85, 0.32))
                : (inputBar.theme ? Qt.rgba(inputBar.theme.glowPrimary.r, inputBar.theme.glowPrimary.g, inputBar.theme.glowPrimary.b, 0.18) : Qt.rgba(0.65, 0.55, 0.85, 0.18))

            Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
        }

        Text {
            anchors.centerIn: parent
            text: inputBar.streaming ? "■" : "↑"
            color: inputBar.theme ? inputBar.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
            font.pixelSize: inputBar.modeManager.scale(inputBar.streaming ? 12 : 16)
            font.family: "M PLUS 2"
        }

        MouseArea {
            id: sendMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (inputBar.streaming) {
                    inputBar.stopClicked()
                } else if (!inputBar.rewinding) {
                    let txt = inputField.text.trim()
                    if (txt.length > 0 || inputBar.pendingAttachments.length > 0) {
                        inputBar.sendRequested(txt)
                    }
                }
            }
        }
    }
}
