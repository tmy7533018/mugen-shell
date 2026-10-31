import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

Rectangle {
    id: serverRow
    required property var modelData
    required property var theme
    required property var st

    readonly property bool pending: (st === null || st.disabled) && !modelData.disabled

    signal disableRequested(bool off)
    signal trustRequested(bool on)
    signal removeRequested()

    Layout.fillWidth: true
    Layout.preferredHeight: serverBody.implicitHeight + 16
    radius: 10
    color: serverRow.theme ? serverRow.theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.3)
    border.width: 1
    border.color: serverRow.theme ? serverRow.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.12)

    ColumnLayout {
        id: serverBody
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 8
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                radius: 4
                color: serverRow.modelData.disabled
                    ? Qt.rgba(0.6, 0.6, 0.65, 0.7)
                    : serverRow.pending
                        ? Qt.rgba(0.85, 0.7, 0.4, 0.9)
                        : (serverRow.st && serverRow.st.connected)
                            ? Qt.rgba(0.45, 0.85, 0.55, 0.95)
                            : Qt.rgba(0.85, 0.45, 0.45, 0.85)
            }

            Text {
                text: serverRow.modelData.name
                color: serverRow.theme ? serverRow.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Medium
            }

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: serverRow.modelData.disabled
                    ? "disabled"
                    : serverRow.pending
                        ? "not applied"
                        : (serverRow.st && serverRow.st.connected)
                            ? "running"
                            : "failed"
                color: serverRow.theme ? serverRow.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
                font.pixelSize: 10
                font.family: "M PLUS 2"
                opacity: 0.7
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }

            YuraPill {
                id: pill
                theme: serverRow.theme
                on: !serverRow.modelData.disabled
                onClicked: serverRow.disableRequested(pill.on)
            }

            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                radius: 11
                color: removeMouse.containsMouse
                    ? Qt.rgba(0.85, 0.4, 0.4, 0.35)
                    : Qt.rgba(0.85, 0.4, 0.4, 0.16)
                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: Qt.rgba(0.95, 0.7, 0.7, 0.95)
                    font.pixelSize: 14
                    font.family: "M PLUS 2"
                }

                MouseArea {
                    id: removeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: serverRow.removeRequested()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            readonly property bool failed: !serverRow.modelData.disabled && !serverRow.pending
                && !(serverRow.st && serverRow.st.connected)
            text: serverRow.modelData.disabled
                ? "Skipped — toggle on and Save & Apply to start."
                : serverRow.pending
                    ? "Not running yet — Save & Apply to start it."
                    : (serverRow.st && serverRow.st.connected)
                        ? (serverRow.st.tool_count + " tool" + (serverRow.st.tool_count === 1 ? "" : "s")
                           + "  ·  " + (serverRow.modelData.url || serverRow.modelData.command))
                        : ((serverRow.st && serverRow.st.error) || "Handshake failed.")
            textFormat: Text.PlainText
            color: failed
                ? Qt.rgba(0.9, 0.55, 0.55, 0.9)
                : (serverRow.theme ? serverRow.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85))
            font.pixelSize: 10
            font.family: "M PLUS 2"
            opacity: failed ? 0.95 : 0.7
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8

            YuraPill {
                id: trustPill
                theme: serverRow.theme
                on: !!serverRow.modelData.trusted
                onFill: Qt.rgba(0.95, 0.74, 0.42, 0.45)
                onBorder: Qt.rgba(0.95, 0.74, 0.42, 0.95)
                pillWidth: 32
                pillHeight: 18
                knobSize: 12
                onClicked: serverRow.trustRequested(!trustPill.on)
            }

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Trusted — run this server's tools without an approval prompt"
                color: serverRow.theme ? serverRow.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
                font.pixelSize: 10
                font.family: "M PLUS 2"
                opacity: trustPill.on ? 0.85 : 0.6
                wrapMode: Text.WordWrap
            }
        }
    }
}
