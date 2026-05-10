import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../ui" as UI

Item {
    id: root

    required property var modeManager
    property var theme

    readonly property alias panelItem: panel

    readonly property var globalRows: [
        { keys: "Super+R", desc: "App launcher" },
        { keys: "Super+W", desc: "Wallpaper picker" },
        { keys: "Super+M", desc: "Music player" },
        { keys: "Super+U", desc: "Volume panel" },
        { keys: "Super+V", desc: "Clipboard history" },
        { keys: "Super+T", desc: "Notification center" },
        { keys: "Super+Y", desc: "Yura (bar)" },
        { keys: "Super+C", desc: "Calendar" },
        { keys: "Super+S", desc: "Screenshot gallery" },
        { keys: "Super+I", desc: "WiFi panel" },
        { keys: "Super+E", desc: "Bluetooth panel" },
        { keys: "Super+P", desc: "Power menu" },
        { keys: "Super+,", desc: "Settings" },
        { keys: "Super+Shift+T", desc: "Timer" },
        { keys: "Super+Shift+Y", desc: "Yura (corner pop-up)" },
        { keys: "Super+Shift+I", desc: "Toggle idle inhibitor" },
        { keys: "Super+/", desc: "This shortcuts panel" },
        { keys: "Super+Return", desc: "Terminal" },
        { keys: "Super+B", desc: "Browser" },
        { keys: "Super+N", desc: "File manager" },
        { keys: "Super+F12 / Print", desc: "Take screenshot" },
        { keys: "Super+hjkl", desc: "Move focus between windows" },
        { keys: "Super+Shift+hjkl", desc: "Move window in tile" },
        { keys: "Super+Tab", desc: "Cycle to next window" },
        { keys: "Super+Shift+Tab", desc: "Cycle to previous window" },
        { keys: "Super+1–5", desc: "Switch workspace" },
        { keys: "Super+Shift+1–5", desc: "Move window to workspace (silent)" },
        { keys: "Super+Shift+S", desc: "Toggle special workspace (magic)" },
        { keys: "Super+Shift+Space", desc: "Toggle floating" },
        { keys: "Super+F", desc: "Fullscreen" },
        { keys: "Super+Backspace", desc: "Close active window" },
        { keys: "Super+Shift+R", desc: "Reload Hyprland config" },
        { keys: "Esc", desc: "Close any panel" }
    ]

    readonly property var categories: [
        { id: "global", label: "Global", sections: [
            { name: "Global", rows: globalRows }
        ]},
        { id: "launcher", label: "App Launcher", sections: [
            { name: "App Launcher", rows: [
                { keys: "Type", desc: "Search apps" },
                { keys: "←→↑↓ / hjkl", desc: "Navigate grid" },
                { keys: "Tab", desc: "Cycle apps" },
                { keys: "Enter", desc: "Launch app" },
                { keys: "Right-click", desc: "Toggle favorite" }
            ]}
        ]},
        { id: "media", label: "Media", sections: [
            { name: "Music Player", rows: [
                { keys: "Space", desc: "Play / Pause" },
                { keys: "←", desc: "Previous track" },
                { keys: "→", desc: "Next track" },
                { keys: "Media keys", desc: "Play/pause, next, prev (system-wide)" }
            ]},
            { name: "Volume", rows: [
                { keys: "↑↓", desc: "Adjust ±2%" },
                { keys: "Shift+↑↓", desc: "Adjust ±10%" },
                { keys: "M", desc: "Mute toggle" },
                { keys: "Tab", desc: "Speaker / Mic mode" },
                { keys: "Volume keys", desc: "Adjust ±2%, mute (system-wide)" }
            ]},
            { name: "Brightness", rows: [
                { keys: "↑↓", desc: "Adjust ±2%" },
                { keys: "Shift+↑↓", desc: "Adjust ±10%" },
                { keys: "Brightness keys", desc: "Adjust ±5% (laptop)" }
            ]}
        ]},
        { id: "network", label: "Network", sections: [
            { name: "WiFi", rows: [
                { keys: "↑↓ / jk", desc: "Navigate networks" },
                { keys: "Home / End", desc: "First / Last" },
                { keys: "Enter", desc: "Connect (open) or expand (secured)" },
                { keys: "P", desc: "Power toggle" },
                { keys: "R", desc: "Refresh" }
            ]},
            { name: "Bluetooth", rows: [
                { keys: "↑↓ / jk", desc: "Navigate devices" },
                { keys: "Home / End", desc: "First / Last" },
                { keys: "Enter", desc: "Connect / Pair" },
                { keys: "Tab", desc: "Switch My Devices / Nearby" },
                { keys: "P", desc: "Power toggle" },
                { keys: "R", desc: "Scan" }
            ]}
        ]},
        { id: "system", label: "System", sections: [
            { name: "Notifications", rows: [
                { keys: "↑↓ / jk", desc: "Navigate notifications" },
                { keys: "Home / End", desc: "First / Last" },
                { keys: "Enter", desc: "Open notification's app + dismiss" },
                { keys: "Delete / Backspace", desc: "Dismiss notification" },
                { keys: "D", desc: "Toggle DnD" },
                { keys: "Ctrl+L", desc: "Clear all" }
            ]},
            { name: "Timer", rows: [
                { keys: "0–9", desc: "Type minutes (or M:SS)" },
                { keys: ":", desc: "Switch to M:SS form" },
                { keys: "Backspace / Delete", desc: "Erase one / all" },
                { keys: "Enter", desc: "Start countdown" },
                { keys: "Click preset", desc: "Start preset duration" },
                { keys: "Space", desc: "Pause / Resume while running" },
                { keys: "C", desc: "Cancel running timer" },
                { keys: "Space / Esc / Enter", desc: "Dismiss alarm when finished" }
            ]},
            { name: "Power Menu", rows: [
                { keys: "←→ / hl / Tab", desc: "Navigate buttons" },
                { keys: "Enter", desc: "Execute selected" }
            ]},
            { name: "Wallpaper / Screenshot / Clipboard", rows: [
                { keys: "←→↑↓", desc: "Navigate grid / list" },
                { keys: "Tab / Shift+Tab", desc: "Cycle items" },
                { keys: "Home / End", desc: "First / Last" },
                { keys: "Enter", desc: "Apply / Open / Paste" }
            ]}
        ]},
        { id: "yura", label: "Yura", sections: [
            { name: "Yura", rows: [
                { keys: "Enter", desc: "Send message" },
                { keys: "←→", desc: "Scroll the response (≈25 chars per press)" },
                { keys: "Home / End", desc: "Jump to start / end of response" },
                { keys: "Ctrl+C / Ctrl+A", desc: "Copy / select all of the response" },
                { keys: "Type a letter", desc: "Discard the response and start a new question" },
                { keys: "Click the icon", desc: "Detach into the corner pop-up" }
            ]}
        ]}
    ]

    property string selectedCategory: "global"

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
                anchors.margins: modeManager.scale(24)
                spacing: modeManager.scale(16)

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: modeManager.scale(36)
                    spacing: 12

                    UI.SvgIcon {
                        Layout.alignment: Qt.AlignVCenter
                        width: modeManager.scale(22)
                        height: modeManager.scale(22)
                        source: Quickshell.shellDir + "/assets/icons/keyboard.svg"
                        color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        text: "Keyboard Shortcuts"
                        color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                        font.pixelSize: modeManager.scale(20)
                        font.weight: Font.Light
                        font.family: "M PLUS 2"
                        font.letterSpacing: 1.5
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Column {
                        id: sidebar
                        width: modeManager.scale(150)
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        spacing: 4

                        Repeater {
                            model: root.categories
                            delegate: Rectangle {
                                width: sidebar.width
                                height: modeManager.scale(36)
                                radius: 10
                                property bool selected: root.selectedCategory === modelData.id
                                color: selected
                                    ? (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20) : Qt.rgba(0.65, 0.55, 0.85, 0.20))
                                    : (categoryArea.containsMouse
                                        ? Qt.rgba(1, 1, 1, 0.04)
                                        : "transparent")

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 14
                                    text: modelData.label
                                    color: parent.selected
                                        ? (theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95))
                                        : (theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85))
                                    font.pixelSize: modeManager.scale(12)
                                    font.weight: parent.selected ? Font.Medium : Font.Normal
                                    font.family: "M PLUS 2"
                                    font.letterSpacing: 0.5
                                }

                                MouseArea {
                                    id: categoryArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedCategory = modelData.id
                                }
                            }
                        }
                    }

                    Flickable {
                        id: shortcutsFlick
                        anchors.left: sidebar.right
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 16
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
                                id: sectionsRepeater
                                model: {
                                    for (let i = 0; i < root.categories.length; i++) {
                                        if (root.categories[i].id === root.selectedCategory) {
                                            return root.categories[i].sections
                                        }
                                    }
                                    return []
                                }

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

                        Connections {
                            target: root
                            function onSelectedCategoryChanged() {
                                shortcutsFlick.contentY = 0
                                sectionsRepeater.model = (function() {
                                    for (let i = 0; i < root.categories.length; i++) {
                                        if (root.categories[i].id === root.selectedCategory) {
                                            return root.categories[i].sections
                                        }
                                    }
                                    return []
                                })()
                            }
                        }
                    }
                }
            }
        }
    }
}
