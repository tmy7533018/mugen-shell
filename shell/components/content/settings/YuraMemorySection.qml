import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager

    Theme.AiBackend { id: aiBackend }

    width: parent ? parent.width : 420
    height: section.isExpanded ? expandedHeight : 64
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)
    clip: true

    property bool isExpanded: false
    property bool loaded: false
    property string statusText: ""
    property var memories: []

    // Clear all is destructive — the button arms a confirm step first.
    property bool confirmingClear: false

    readonly property int expandedHeight: 64 + contentColumn.implicitHeight + 16

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function summary() {
        if (!loaded) return "loading…"
        if (memories.length === 0) return "empty"
        return memories.length + (memories.length === 1 ? " memory" : " memories")
    }

    function refresh() {
        if (listProcess.running) return
        listProcess.running = true
    }

    function deleteMemory(id) {
        if (deleteProcess.running) return
        deleteProcess.memoryId = id
        section.statusText = "deleting…"
        deleteProcess.running = true
    }

    function doClear() {
        if (clearProcess.running) return
        section.confirmingClear = false
        section.statusText = "clearing…"
        clearProcess.running = true
    }

    Behavior on height {
        NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: refresh()
    onIsExpandedChanged: if (isExpanded) refresh()

    Process {
        id: listProcess
        running: false
        property string buf: ""
        command: ["curl", "-fsS", "--max-time", "3", aiBackend.baseUrl + "/memories"]
        stdout: SplitParser { onRead: data => listProcess.buf += data }
        onRunningChanged: { if (running) buf = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) { section.statusText = "load failed"; return }
            try {
                section.memories = JSON.parse(listProcess.buf).memories || []
                section.loaded = true
                section.statusText = ""
                section.bump()
            } catch (e) {
                section.statusText = "parse failed"
            }
        }
    }

    Process {
        id: deleteProcess
        running: false
        property int memoryId: 0
        command: ["curl", "-fsS", "--max-time", "3",
                  "-X", "DELETE", aiBackend.baseUrl + "/memories/" + memoryId]
        onExited: (exitCode) => {
            section.statusText = exitCode === 0 ? "" : "delete failed"
            section.refresh()
        }
    }

    Process {
        id: clearProcess
        running: false
        command: ["curl", "-fsS", "--max-time", "3",
                  "-X", "DELETE", aiBackend.baseUrl + "/memories"]
        onExited: (exitCode) => {
            section.statusText = exitCode === 0 ? "" : "clear failed"
            section.refresh()
        }
    }

    MouseArea {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 64
        cursorShape: Qt.PointingHandCursor

        TapHandler {
            onTapped: {
                section.isExpanded = !section.isExpanded
                section.bump()
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: "Long-term memory"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.letterSpacing: 0.5
                elide: Text.ElideRight
            }

            Text {
                text: section.statusText !== "" ? section.statusText : section.summary()
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: 11
                font.family: "M PLUS 2"
                font.italic: !section.loaded || section.statusText !== ""
                opacity: 0.85
            }

            Text {
                text: section.isExpanded ? "▴" : "▾"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                opacity: 0.7
            }
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 4
        spacing: 8
        visible: section.isExpanded

        Text {
            Layout.fillWidth: true
            text: "Facts Yura saved about you; every entry is shown to her each turn. Ask her to remember or forget things in chat, or prune here."
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            opacity: 0.65
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: section.loaded && section.memories.length === 0
            text: "Nothing saved yet."
            color: section.theme ? section.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.65)
            font.pixelSize: 11
            font.family: "M PLUS 2"
            font.italic: true
        }

        Repeater {
            model: section.memories

            Rectangle {
                id: memRow
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: memRowLayout.implicitHeight + 12
                radius: 10
                color: section.theme ? section.theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.3)
                border.width: 1
                border.color: section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.12)

                RowLayout {
                    id: memRowLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: memRow.modelData.content
                            color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.92)
                            font.pixelSize: 11
                            font.family: "M PLUS 2"
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            text: "#" + memRow.modelData.id + " · "
                                + Qt.formatDateTime(new Date(memRow.modelData.created_at * 1000), "yyyy-MM-dd")
                            color: section.theme ? section.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                            font.pixelSize: 9
                            font.family: "M PLUS 2"
                        }
                    }

                    Text {
                        text: "✕"
                        color: memDeleteArea.containsMouse
                            ? Qt.rgba(0.95, 0.45, 0.45, 0.95)
                            : (section.theme ? section.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60))
                        font.pixelSize: 12
                        font.family: "M PLUS 2"

                        MouseArea {
                            id: memDeleteArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: section.deleteMemory(memRow.modelData.id)
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            spacing: 8
            visible: section.memories.length > 0

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: clearLabel.implicitWidth + 24
                Layout.preferredHeight: 26
                radius: 13
                color: section.confirmingClear
                    ? Qt.rgba(0.85, 0.3, 0.3, 0.35)
                    : Qt.rgba(0.85, 0.3, 0.3, clearArea.containsMouse ? 0.22 : 0.12)
                border.width: 1
                border.color: Qt.rgba(0.95, 0.45, 0.45, section.confirmingClear ? 0.8 : 0.4)

                Behavior on color { ColorAnimation { duration: 160 } }

                Text {
                    id: clearLabel
                    anchors.centerIn: parent
                    text: section.confirmingClear ? "Really delete all?" : "Clear all"
                    color: Qt.rgba(0.98, 0.75, 0.75, 0.95)
                    font.pixelSize: 10
                    font.family: "M PLUS 2"
                }

                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (section.confirmingClear) section.doClear()
                        else {
                            section.confirmingClear = true
                            confirmResetTimer.restart()
                        }
                        section.bump()
                    }
                }
            }
        }
    }

    Timer {
        id: confirmResetTimer
        interval: 4000
        onTriggered: section.confirmingClear = false
    }
}
