pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

Rectangle {
    id: confirmCard

    required property var modeManager
    required property var theme
    property var pendingConfirm: null

    signal resolved(bool approved)

    height: confirmCol.implicitHeight + confirmCard.modeManager.scale(28)
    visible: confirmCard.pendingConfirm !== null
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }

    radius: confirmCard.modeManager.scale(16)
    color: confirmCard.theme ? confirmCard.theme.popupFace : Qt.rgba(0.07, 0.06, 0.11, 0.97)
    border.width: 1
    border.color: Qt.rgba(0.95, 0.74, 0.42, 0.55)

    readonly property var pc: confirmCard.pendingConfirm || ({})
    readonly property string fullName: pc.name || ""
    readonly property int sep: fullName.indexOf("__")
    readonly property string serverName: sep > 0 ? fullName.substring(0, sep) : ""
    readonly property string toolName: sep > 0 ? fullName.substring(sep + 2) : fullName
    readonly property string target: pc.target || ""
    readonly property var argKeys: pc.arguments ? Object.keys(pc.arguments) : []

    // The backend denies on timeout, so the card has to show that it is running out.
    readonly property real expiresAt: pc.expires_at || 0
    property real openedAt: 0
    property real nowMs: 0

    readonly property real remainingFraction: {
        let span = expiresAt - openedAt
        if (expiresAt <= 0 || span <= 0) return 0
        return Math.max(0, Math.min(1, (expiresAt - nowMs) / span))
    }

    onVisibleChanged: {
        if (!visible) return
        openedAt = Date.now()
        nowMs = openedAt
    }

    Timer {
        interval: 250
        repeat: true
        running: confirmCard.visible && confirmCard.expiresAt > 0
        onTriggered: confirmCard.nowMs = Date.now()
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: confirmCard.radius
        anchors.bottomMargin: confirmCard.modeManager.scale(2)
        height: confirmCard.modeManager.scale(2)
        radius: height / 2
        visible: confirmCard.expiresAt > 0
        width: confirmCard.remainingFraction * (confirmCard.width - confirmCard.radius * 2)
        color: Qt.rgba(0.95, 0.74, 0.42, 0.75)
    }

    ColumnLayout {
        id: confirmCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: confirmCard.modeManager.scale(14)
        spacing: confirmCard.modeManager.scale(8)

        RowLayout {
            Layout.fillWidth: true
            spacing: confirmCard.modeManager.scale(8)

            Text {
                text: "⚠"
                color: Qt.rgba(0.96, 0.78, 0.46, 0.95)
                font.pixelSize: confirmCard.modeManager.scale(15)
            }

            Text {
                text: "Approval needed"
                color: confirmCard.theme ? confirmCard.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                font.pixelSize: confirmCard.modeManager.scale(13)
                font.family: "M PLUS 2"
                font.weight: Font.Medium
                font.letterSpacing: 0.3
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                visible: confirmCard.serverName !== ""
                Layout.preferredHeight: confirmCard.modeManager.scale(18)
                Layout.preferredWidth: serverTag.implicitWidth + confirmCard.modeManager.scale(14)
                radius: height / 2
                color: confirmCard.theme ? Qt.rgba(confirmCard.theme.accent.r, confirmCard.theme.accent.g, confirmCard.theme.accent.b, 0.22) : Qt.rgba(0.65, 0.55, 0.85, 0.22)

                Text {
                    id: serverTag
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: confirmCard.serverName
                    color: confirmCard.theme ? confirmCard.theme.textSecondary : Qt.rgba(0.82, 0.80, 0.90, 0.9)
                    font.pixelSize: confirmCard.modeManager.scale(10)
                    font.family: "M PLUS 2"
                }
            }
        }

        Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: "Yura wants to run " + confirmCard.toolName
            color: confirmCard.theme ? confirmCard.theme.textSecondary : Qt.rgba(0.80, 0.80, 0.88, 0.88)
            font.pixelSize: confirmCard.modeManager.scale(12)
            font.family: "M PLUS 2"
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            visible: confirmCard.target !== "" || confirmCard.argKeys.length > 0
            Layout.preferredHeight: confirmCard.target !== ""
                ? targetText.implicitHeight + confirmCard.modeManager.scale(16)
                : Math.min(argCol.implicitHeight, confirmCard.modeManager.scale(150)) + confirmCard.modeManager.scale(16)
            radius: confirmCard.modeManager.scale(10)
            color: Qt.rgba(0, 0, 0, 0.22)

            Text {
                id: targetText
                visible: confirmCard.target !== ""
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: confirmCard.modeManager.scale(8)
                textFormat: Text.PlainText
                text: confirmCard.target
                color: confirmCard.theme ? confirmCard.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95)
                font.pixelSize: confirmCard.modeManager.scale(12)
                font.family: "M PLUS 2"
                wrapMode: Text.Wrap
            }

            Flickable {
                id: argFlick
                visible: confirmCard.target === ""
                anchors.fill: parent
                anchors.margins: confirmCard.modeManager.scale(8)
                contentHeight: argCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: argCol
                    width: argFlick.width
                    spacing: confirmCard.modeManager.scale(5)

                    Repeater {
                        model: confirmCard.argKeys

                        ColumnLayout {
                            id: argRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                textFormat: Text.PlainText
                                text: argRow.modelData
                                color: confirmCard.theme ? confirmCard.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.75)
                                font.pixelSize: confirmCard.modeManager.scale(10)
                                font.family: "M PLUS 2"
                                font.letterSpacing: 0.4
                            }

                            Text {
                                Layout.fillWidth: true
                                textFormat: Text.PlainText
                                text: {
                                    let v = confirmCard.pc.arguments[argRow.modelData]
                                    return (typeof v === "string") ? v : JSON.stringify(v)
                                }
                                color: confirmCard.theme ? confirmCard.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95)
                                font.pixelSize: confirmCard.modeManager.scale(12)
                                font.family: "M PLUS 2"
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: confirmCard.modeManager.scale(2)
            spacing: confirmCard.modeManager.scale(8)

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: confirmCard.modeManager.scale(86)
                Layout.preferredHeight: confirmCard.modeManager.scale(32)
                radius: height / 2
                color: denyMouse.containsMouse ? Qt.rgba(0.85, 0.42, 0.42, 0.30) : Qt.rgba(0.85, 0.42, 0.42, 0.15)
                border.width: 1
                border.color: Qt.rgba(0.88, 0.50, 0.50, 0.45)
                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                Text {
                    anchors.centerIn: parent
                    text: "Deny"
                    color: Qt.rgba(0.96, 0.79, 0.79, 0.95)
                    font.pixelSize: confirmCard.modeManager.scale(12)
                    font.family: "M PLUS 2"
                }

                MouseArea {
                    id: denyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: confirmCard.resolved(false)
                }
            }

            Rectangle {
                Layout.preferredWidth: confirmCard.modeManager.scale(100)
                Layout.preferredHeight: confirmCard.modeManager.scale(32)
                radius: height / 2
                color: approveMouse.containsMouse
                    ? (confirmCard.theme ? Qt.rgba(confirmCard.theme.accent.r, confirmCard.theme.accent.g, confirmCard.theme.accent.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                    : (confirmCard.theme ? Qt.rgba(confirmCard.theme.accent.r, confirmCard.theme.accent.g, confirmCard.theme.accent.b, 0.34) : Qt.rgba(0.65, 0.55, 0.85, 0.34))
                border.width: 1
                border.color: confirmCard.theme ? confirmCard.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                Text {
                    anchors.centerIn: parent
                    text: "Approve"
                    color: confirmCard.theme ? confirmCard.theme.textPrimary : Qt.rgba(0.96, 0.95, 1.0, 0.98)
                    font.pixelSize: confirmCard.modeManager.scale(12)
                    font.family: "M PLUS 2"
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: approveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: confirmCard.resolved(true)
                }
            }
        }
    }
}
