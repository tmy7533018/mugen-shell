import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    required property var modeManager
    property var theme

    readonly property alias panelItem: panel

    readonly property var shortcutSections: [
        {
            name: "Global",
            rows: [
                { keys: "Super+R", desc: "App launcher" },
                { keys: "Super+W", desc: "Wallpaper picker" },
                { keys: "Super+M", desc: "Music player" },
                { keys: "Super+U", desc: "Volume panel" },
                { keys: "Super+V", desc: "Clipboard history" },
                { keys: "Super+T", desc: "Notification center" },
                { keys: "Super+A", desc: "AI assistant" },
                { keys: "Super+C", desc: "Calendar" },
                { keys: "Super+S", desc: "Screenshot gallery" },
                { keys: "Super+H", desc: "WiFi panel" },
                { keys: "Super+J", desc: "Bluetooth panel" },
                { keys: "Super+L", desc: "Power menu" },
                { keys: "Super+,", desc: "Settings" },
                { keys: "Super+Shift+T", desc: "Timer" },
                { keys: "Super+Shift+A", desc: "AI assistant (floating window)" },
                { keys: "Super+/", desc: "This shortcuts panel" },
                { keys: "Super+Return", desc: "Terminal" },
                { keys: "Super+B", desc: "Browser" },
                { keys: "Super+N", desc: "File manager" },
                { keys: "Super+F12", desc: "Take screenshot" },
                { keys: "Esc", desc: "Close any panel" },
            ]
        },
        {
            name: "App Launcher",
            rows: [
                { keys: "Type", desc: "Search apps" },
                { keys: "←→↑↓", desc: "Navigate grid" },
                { keys: "Tab", desc: "Cycle apps" },
                { keys: "Enter", desc: "Launch app" },
                { keys: "Right-click", desc: "Toggle favorite" },
            ]
        },
        {
            name: "Timer",
            rows: [
                { keys: "0–9", desc: "Type minutes (or M:SS)" },
                { keys: ":", desc: "Switch to M:SS form" },
                { keys: "Backspace / Delete", desc: "Erase one / all" },
                { keys: "Enter", desc: "Start countdown" },
                { keys: "Click preset", desc: "Start preset duration" },
                { keys: "Space", desc: "Pause / Resume while running" },
                { keys: "C", desc: "Cancel running timer" },
                { keys: "Space / Esc / Enter", desc: "Dismiss alarm when finished" },
            ]
        },
        {
            name: "Notifications",
            rows: [
                { keys: "↑↓", desc: "Navigate notifications" },
                { keys: "Home / End", desc: "First / Last" },
                { keys: "Enter", desc: "Open notification's app + dismiss" },
                { keys: "Delete / Backspace", desc: "Dismiss notification" },
                { keys: "D", desc: "Toggle DnD" },
                { keys: "Ctrl+L", desc: "Clear all" },
            ]
        },
        {
            name: "Volume",
            rows: [
                { keys: "↑↓", desc: "Adjust ±2%" },
                { keys: "Shift+↑↓", desc: "Adjust ±10%" },
                { keys: "M", desc: "Mute toggle" },
                { keys: "Tab", desc: "Speaker / Mic mode" },
            ]
        },
        {
            name: "WiFi",
            rows: [
                { keys: "↑↓", desc: "Navigate networks" },
                { keys: "Home / End", desc: "First / Last" },
                { keys: "Enter", desc: "Connect (open) or expand (secured)" },
                { keys: "P", desc: "Power toggle" },
                { keys: "R", desc: "Refresh" },
            ]
        },
        {
            name: "Bluetooth",
            rows: [
                { keys: "↑↓", desc: "Navigate devices" },
                { keys: "Home / End", desc: "First / Last" },
                { keys: "Enter", desc: "Connect / Pair" },
                { keys: "Tab", desc: "Switch My Devices / Nearby" },
                { keys: "P", desc: "Power toggle" },
                { keys: "R", desc: "Scan" },
            ]
        },
        {
            name: "AI Assistant",
            rows: [
                { keys: "Enter", desc: "Send message" },
                { keys: "Shift+Enter", desc: "Newline" },
                { keys: "PgUp / PgDn", desc: "Scroll message history" },
                { keys: "Ctrl+↑↓", desc: "Scroll by smaller step" },
                { keys: "Ctrl+End", desc: "Jump to latest message" },
                { keys: "Ctrl+L", desc: "Clear conversation" },
            ]
        },
        {
            name: "Music Player",
            rows: [
                { keys: "Space", desc: "Play / Pause" },
                { keys: "←", desc: "Previous track" },
                { keys: "→", desc: "Next track" },
            ]
        },
        {
            name: "Power Menu",
            rows: [
                { keys: "←→ / Tab", desc: "Navigate buttons" },
                { keys: "Enter", desc: "Execute selected" },
            ]
        },
        {
            name: "Settings",
            rows: [
                { keys: "↑↓", desc: "Navigate sections" },
                { keys: "Home / End", desc: "First / Last" },
                { keys: "PgUp / PgDn", desc: "Jump 3 sections" },
                { keys: "Enter / Space", desc: "Toggle switch or expand selection" },
                { keys: "←→", desc: "Adjust slider" },
                { keys: "↑↓ (expanded)", desc: "Select option in expanded section" },
            ]
        },
        {
            name: "Wallpaper / Screenshot / Clipboard",
            rows: [
                { keys: "←→↑↓", desc: "Navigate grid / list" },
                { keys: "Tab / Shift+Tab", desc: "Cycle items" },
                { keys: "Home / End", desc: "First / Last" },
                { keys: "Enter", desc: "Apply / Open / Paste" },
            ]
        },
    ]

    Item {
        id: shortcutsLayer
        anchors.fill: parent
        z: 2

        focus: modeManager.shortcutsVisible
        Keys.onPressed: (event) => {
            if (modeManager.shortcutsVisible) modeManager.bump()
            if (event.key === Qt.Key_Escape) {
                modeManager.closeShortcuts()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_PageUp) {
                shortcutsFlick.contentY = Math.max(0, shortcutsFlick.contentY - shortcutsFlick.height * 0.8)
                event.accepted = true
            } else if (event.key === Qt.Key_PageDown) {
                let maxY = Math.max(0, shortcutsFlick.contentHeight - shortcutsFlick.height)
                shortcutsFlick.contentY = Math.min(maxY, shortcutsFlick.contentY + shortcutsFlick.height * 0.8)
                event.accepted = true
            } else if ((event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                let maxY = Math.max(0, shortcutsFlick.contentHeight - shortcutsFlick.height)
                let dir = event.key === Qt.Key_Up ? -1 : 1
                shortcutsFlick.contentY = Math.max(0, Math.min(maxY, shortcutsFlick.contentY + dir * 60))
                event.accepted = true
            } else if (event.key === Qt.Key_Home) {
                shortcutsFlick.contentY = 0
                event.accepted = true
            } else if (event.key === Qt.Key_End) {
                shortcutsFlick.contentY = Math.max(0, shortcutsFlick.contentHeight - shortcutsFlick.height)
                event.accepted = true
            }
        }

        opacity: 0
        visible: opacity > 0.01

        states: [
            State {
                name: "visible"
                when: modeManager.shortcutsVisible
                PropertyChanges { target: shortcutsLayer; opacity: 1.0 }
            }
        ]

        transitions: [
            Transition {
                from: "visible"
                to: ""
                NumberAnimation { property: "opacity"; duration: 300; easing.type: Easing.OutCubic }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: 300 }
                    NumberAnimation { property: "opacity"; duration: 400; easing.type: Easing.InOutCubic }
                }
            }
        ]

        Rectangle {
            id: panel
            anchors.fill: parent
            color: Qt.rgba(0.04, 0.03, 0.08, 0.92)
            radius: 0
            border.width: 0

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: modeManager.scale(28)
                spacing: modeManager.scale(16)

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Keyboard Shortcuts"
                    color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                    font.pixelSize: modeManager.scale(20)
                    font.weight: Font.Medium
                    font.family: "M PLUS 2"
                    font.letterSpacing: 1
                }

                Flickable {
                    id: shortcutsFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: shortcutsColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 4

                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: theme
                                ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.4)
                                : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                        }
                    }

                    Column {
                        id: shortcutsColumn
                        width: shortcutsFlick.width
                        spacing: modeManager.scale(14)

                        Repeater {
                            model: root.shortcutSections

                            delegate: Column {
                                width: parent.width
                                spacing: 0
                                property var sectionData: modelData

                                Item {
                                    width: parent.width
                                    height: modeManager.scale(24)

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: sectionData.name
                                        color: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
                                        font.pixelSize: modeManager.scale(12)
                                        font.weight: Font.Medium
                                        font.family: "M PLUS 2"
                                        font.letterSpacing: 0.5
                                    }

                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 100
                                        height: 1
                                        color: theme
                                            ? Qt.rgba(theme.surfaceBorder.r, theme.surfaceBorder.g, theme.surfaceBorder.b, theme.surfaceBorder.a * 0.4)
                                            : Qt.rgba(1, 1, 1, 0.06)
                                    }
                                }

                                Repeater {
                                    model: sectionData.rows

                                    delegate: RowLayout {
                                        width: parent.width
                                        height: modeManager.scale(24)
                                        spacing: modeManager.scale(12)

                                        Rectangle {
                                            Layout.preferredWidth: keyText.implicitWidth + modeManager.scale(14)
                                            Layout.preferredHeight: modeManager.scale(20)
                                            color: theme
                                                ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.12)
                                                : Qt.rgba(0.65, 0.55, 0.85, 0.12)
                                            border.width: 1
                                            border.color: theme
                                                ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.3)
                                                : Qt.rgba(0.65, 0.55, 0.85, 0.3)
                                            radius: 5

                                            Text {
                                                id: keyText
                                                anchors.centerIn: parent
                                                text: modelData.keys
                                                color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.9)
                                                font.pixelSize: modeManager.scale(11)
                                                font.weight: Font.Medium
                                                font.family: "M PLUS 2"
                                                font.letterSpacing: 0.3
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.desc
                                            color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85)
                                            font.pixelSize: modeManager.scale(12)
                                            font.family: "M PLUS 2"
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
