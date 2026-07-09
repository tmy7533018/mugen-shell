import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager

    // Reuse the escape-hatch actions already plumbed to settings-shell.
    signal editConfig()
    signal restartService()

    width: parent ? parent.width : 420
    height: contentColumn.implicitHeight + 24
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    Theme.AiBackend { id: aiBackend }

    readonly property string configPath: {
        let x = Quickshell.env("XDG_CONFIG_HOME")
        if (!x || x === "") x = Quickshell.env("HOME") + "/.config"
        return x + "/mugen-ai/config.toml"
    }
    readonly property string auditPath: {
        let x = Quickshell.env("XDG_STATE_HOME")
        if (!x || x === "") x = Quickshell.env("HOME") + "/.local/state"
        return x + "/mugen-ai/audit.log"
    }

    property string qsConfig: ""

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    Component.onCompleted: configProc.running = true

    Process {
        id: configProc
        running: false
        property string buf: ""
        command: ["curl", "-fsS", "--max-time", "3", aiBackend.baseUrl + "/config"]
        stdout: SplitParser { onRead: data => configProc.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) return
            try {
                let c = JSON.parse(configProc.buf)
                section.qsConfig = (c.config && c.config.shell && c.config.shell.qs_config) || ""
            } catch (e) {}
        }
    }

    Process { id: openProc; running: false }

    function openPath(path) {
        openProc.running = false
        openProc.command = ["xdg-open", path]
        openProc.running = true
    }

    component InfoRow: RowLayout {
        property string title: ""
        property string value: ""
        Layout.fillWidth: true
        spacing: 12

        Text {
            Layout.preferredWidth: 128
            text: parent.title
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.letterSpacing: 0.5
        }

        Text {
            Layout.fillWidth: true
            text: parent.value
            color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            font.pixelSize: 11
            font.family: "M PLUS 2"
            elide: Text.ElideMiddle
            horizontalAlignment: Text.AlignRight
        }
    }

    component ActionButton: Rectangle {
        property string label: ""
        property color tint: Qt.rgba(0.55, 0.55, 0.65, 0.22)
        property color tintHover: Qt.rgba(0.55, 0.55, 0.65, 0.32)
        signal clicked()

        implicitWidth: 84
        implicitHeight: 28
        radius: 14
        color: btnMouse.containsMouse ? tintHover : tint
        Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

        Text {
            anchors.centerIn: parent
            text: parent.label
            color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            font.pixelSize: 11
            font.family: "M PLUS 2"
            font.weight: Font.Medium
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 12

        Text {
            text: "Advanced"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.letterSpacing: 0.5
        }

        InfoRow { title: "Backend address"; value: aiBackend.baseUrl }
        InfoRow { title: "Quickshell config"; value: section.qsConfig || "—" }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.preferredWidth: 128
                text: "Config file"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.letterSpacing: 0.5
            }

            Text {
                Layout.fillWidth: true
                text: section.configPath
                color: section.theme ? section.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.65)
                font.pixelSize: 10
                font.family: "M PLUS 2"
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignRight
            }

            ActionButton {
                label: "Edit toml"
                onClicked: { section.editConfig(); section.bump() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.preferredWidth: 128
                text: "Audit log"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.letterSpacing: 0.5
            }

            Text {
                Layout.fillWidth: true
                text: section.auditPath
                color: section.theme ? section.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.65)
                font.pixelSize: 10
                font.family: "M PLUS 2"
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignRight
            }

            ActionButton {
                label: "View log"
                onClicked: { section.openPath(section.auditPath); section.bump() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Restart the mugen-ai service to apply config changes"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
                font.pixelSize: 10
                font.family: "M PLUS 2"
                opacity: 0.6
                wrapMode: Text.WordWrap
            }

            ActionButton {
                label: "Restart AI"
                tint: Qt.rgba(0.90, 0.45, 0.55, 0.30)
                tintHover: Qt.rgba(0.90, 0.45, 0.55, 0.45)
                onClicked: { section.restartService(); section.bump() }
            }
        }
    }
}
