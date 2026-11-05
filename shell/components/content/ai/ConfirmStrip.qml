import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

Rectangle {
    id: confirmStrip

    required property var modeManager
    required property var theme
    property var pendingConfirm: null

    signal resolved(bool approved)

    visible: confirmStrip.pendingConfirm !== null
    color: confirmStrip.theme ? confirmStrip.theme.popupFace : Qt.rgba(0.06, 0.05, 0.11, 0.93)
    border.width: 1
    border.color: Qt.rgba(0.95, 0.74, 0.42, 0.60)

    readonly property var pc: confirmStrip.pendingConfirm || ({})
    readonly property string fullName: pc.name || ""
    readonly property int sep: fullName.indexOf("__")
    readonly property string serverName: sep > 0 ? fullName.substring(0, sep) : ""
    readonly property string toolName: sep > 0 ? fullName.substring(sep + 2) : fullName
    readonly property string argSummary: {
        if (typeof pc.target === "string" && pc.target !== "") return pc.target
        let a = pc.arguments
        if (!a) return ""
        let parts = []
        for (let k of Object.keys(a)) parts.push(k + ": " + Theme.ChatText.toolArgumentText(a[k]))
        return parts.join("   ·   ")
    }

    // Eats stray clicks so they can't fall through to the input or stop button beneath.
    MouseArea { anchors.fill: parent }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: confirmStrip.modeManager.scale(16)
        anchors.rightMargin: confirmStrip.modeManager.scale(6)
        spacing: confirmStrip.modeManager.scale(8)

        Text {
            text: "⚠"
            color: Qt.rgba(0.96, 0.78, 0.46, 0.95)
            font.pixelSize: confirmStrip.modeManager.scale(14)
        }

        Text {
            textFormat: Text.PlainText
            text: confirmStrip.serverName !== ""
                ? (confirmStrip.serverName + " → " + confirmStrip.toolName)
                : confirmStrip.toolName
            color: confirmStrip.theme ? confirmStrip.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
            font.pixelSize: confirmStrip.modeManager.scale(13)
            font.family: "M PLUS 2"
            font.weight: Font.Medium
        }

        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            textFormat: Text.PlainText
            text: confirmStrip.argSummary
            color: confirmStrip.theme ? confirmStrip.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.70)
            font.pixelSize: confirmStrip.modeManager.scale(11)
            font.family: "M PLUS 2"
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.preferredWidth: confirmStrip.modeManager.scale(62)
            Layout.preferredHeight: confirmStrip.modeManager.scale(28)
            Layout.alignment: Qt.AlignVCenter
            radius: height / 2
            color: denyMouse.containsMouse ? Qt.rgba(0.85, 0.42, 0.42, 0.32) : Qt.rgba(0.85, 0.42, 0.42, 0.16)
            border.width: 1
            border.color: Qt.rgba(0.88, 0.50, 0.50, 0.45)
            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

            Text {
                anchors.centerIn: parent
                text: "Deny"
                color: Qt.rgba(0.96, 0.79, 0.79, 0.95)
                font.pixelSize: confirmStrip.modeManager.scale(11)
                font.family: "M PLUS 2"
            }

            MouseArea {
                id: denyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: confirmStrip.resolved(false)
            }
        }

        Rectangle {
            Layout.preferredWidth: confirmStrip.modeManager.scale(78)
            Layout.preferredHeight: confirmStrip.modeManager.scale(28)
            Layout.alignment: Qt.AlignVCenter
            radius: height / 2
            color: approveMouse.containsMouse
                ? (confirmStrip.theme ? Qt.rgba(confirmStrip.theme.glowPrimary.r, confirmStrip.theme.glowPrimary.g, confirmStrip.theme.glowPrimary.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                : (confirmStrip.theme ? Qt.rgba(confirmStrip.theme.glowPrimary.r, confirmStrip.theme.glowPrimary.g, confirmStrip.theme.glowPrimary.b, 0.32) : Qt.rgba(0.65, 0.55, 0.85, 0.32))
            border.width: 1
            border.color: confirmStrip.theme ? confirmStrip.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.9)
            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

            Text {
                anchors.centerIn: parent
                text: "Approve"
                color: confirmStrip.theme ? confirmStrip.theme.textPrimary : Qt.rgba(0.96, 0.95, 1.0, 0.98)
                font.pixelSize: confirmStrip.modeManager.scale(11)
                font.family: "M PLUS 2"
                font.weight: Font.Medium
            }

            MouseArea {
                id: approveMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: confirmStrip.resolved(true)
            }
        }
    }
}
