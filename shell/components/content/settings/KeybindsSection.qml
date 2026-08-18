import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../ui" as UI
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager

    signal openUrl(string url)

    // The file itself has no registered app for xdg-open to hand it to; the folder always does.
    readonly property string overridesDir: {
        let x = Quickshell.env("XDG_CONFIG_HOME")
        if (!x || x === "") x = Quickshell.env("HOME") + "/.config"
        return x + "/hypr/configs"
    }

    width: parent ? parent.width : 420
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)
    height: layout.implicitHeight + 24

    component ActionButton: Rectangle {
        property string label: ""
        signal clicked()

        implicitWidth: 72
        implicitHeight: 24
        radius: 12
        color: btnMouse.containsMouse ? Qt.rgba(0.55, 0.55, 0.65, 0.32) : Qt.rgba(0.55, 0.55, 0.65, 0.22)
        Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

        Text {
            anchors.centerIn: parent
            text: parent.label
            color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            font.pixelSize: 10
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

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    readonly property var groupOrder: ["shell", "window", "workspace", "apps", "voice", "media", "system"]
    readonly property var groupLabels: ({
        shell: "Shell Panels", window: "Window Management", workspace: "Workspaces",
        apps: "Applications", voice: "Voice", media: "Media Keys", system: "System"
    })

    readonly property var systemGroups: {
        const rows = Theme.Keybinds.rows
        const groups = []
        for (const cat of groupOrder) {
            const catRows = rows.filter(r => r.cat === cat)
            if (catRows.length > 0) groups.push({ name: groupLabels[cat], rows: catRows })
        }
        return groups
    }

    readonly property var referenceCategories: [
        { id: "launcher", label: "App Launcher", sections: [
            { name: "App Launcher", rows: [
                { keys: "Type", desc: "Search apps" },
                { keys: "←→↑↓ / hjkl", desc: "Navigate grid" },
                { keys: "Tab", desc: "Cycle apps" },
                { keys: "Enter", desc: "Launch app" },
                { keys: "Right-click / Menu", desc: "Context menu" }
            ]}
        ]},
        { id: "playback", label: "Playback & Volume", sections: [
            { name: "Music Player", rows: [
                { keys: "Space", desc: "Play / Pause" },
                { keys: "←", desc: "Previous track" },
                { keys: "→", desc: "Next track" }
            ]},
            { name: "Volume", rows: [
                { keys: "↑↓", desc: "Adjust ±2%" },
                { keys: "Shift+↑↓", desc: "Adjust ±10%" },
                { keys: "M", desc: "Mute toggle" },
                { keys: "Tab", desc: "Speaker / Mic mode" }
            ]},
            { name: "Brightness", rows: [
                { keys: "↑↓", desc: "Adjust ±2%" },
                { keys: "Shift+↑↓", desc: "Adjust ±10%" }
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
        { id: "panels", label: "Other Panels", sections: [
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

    property string mode: "system"
    property string referenceCategory: "launcher"

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            UI.SvgIcon {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                source: Quickshell.shellDir + "/assets/icons/keyboard.svg"
                color: section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
            }

            Text {
                Layout.fillWidth: true
                text: "Keyboard Shortcuts"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.letterSpacing: 0.5
            }

            Repeater {
                model: [{ id: "system", label: "System" }, { id: "reference", label: "In-App" }]
                delegate: Rectangle {
                    required property var modelData
                    property bool selected: section.mode === modelData.id
                    width: modeLabel.implicitWidth + 20
                    height: 24
                    radius: 12
                    color: selected
                        ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.22) : Qt.rgba(0.65, 0.55, 0.85, 0.22))
                        : Qt.rgba(1, 1, 1, 0.04)

                    Text {
                        id: modeLabel
                        anchors.centerIn: parent
                        text: modelData.label
                        color: parent.selected
                            ? (section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95))
                            : (section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85))
                        font.pixelSize: 11
                        font.family: "M PLUS 2"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            section.mode = modelData.id
                            section.bump()
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: section.mode === "reference"

            Repeater {
                model: section.referenceCategories
                delegate: Rectangle {
                    required property var modelData
                    property bool selected: section.referenceCategory === modelData.id
                    width: refLabel.implicitWidth + 16
                    height: 22
                    radius: 11
                    color: selected
                        ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.18) : Qt.rgba(0.65, 0.55, 0.85, 0.18))
                        : "transparent"
                    border.width: 1
                    border.color: section.theme ? Qt.rgba(section.theme.surfaceBorder.r, section.theme.surfaceBorder.g, section.theme.surfaceBorder.b, 0.4) : Qt.rgba(1, 1, 1, 0.12)

                    Text {
                        id: refLabel
                        anchors.centerIn: parent
                        text: modelData.label
                        color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85)
                        font.pixelSize: 10
                        font.family: "M PLUS 2"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            section.referenceCategory = modelData.id
                            section.bump()
                        }
                    }
                }
            }
        }

        // Read-only: source of truth is keybinds.lua + keybind-overrides.lua, not this panel.
        Column {
            Layout.fillWidth: true
            spacing: 10
            visible: section.mode === "system"

            Repeater {
                model: section.systemGroups
                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: 2

                    Text {
                        text: modelData.name
                        color: section.theme ? section.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.family: "M PLUS 2"
                        font.letterSpacing: 0.5
                        bottomPadding: 4
                    }

                    Repeater {
                        model: modelData.rows
                        delegate: RowLayout {
                            required property var modelData
                            width: parent.width
                            height: 26
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: Math.max(keyText.implicitWidth + 14, 40)
                                Layout.preferredHeight: 20
                                radius: 5
                                color: section.theme ? Qt.rgba(section.theme.glowPrimary.r, section.theme.glowPrimary.g, section.theme.glowPrimary.b, 0.12) : Qt.rgba(0.65, 0.55, 0.85, 0.12)
                                border.width: 1
                                border.color: section.theme ? Qt.rgba(section.theme.glowPrimary.r, section.theme.glowPrimary.g, section.theme.glowPrimary.b, 0.3) : Qt.rgba(0.65, 0.55, 0.85, 0.3)

                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: modelData.keys
                                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.9)
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    font.family: "M PLUS 2"
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.desc
                                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85)
                                font.pixelSize: 12
                                font.family: "M PLUS 2"
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: modelData.overridden === true
                                text: "custom"
                                color: section.theme ? section.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                                font.pixelSize: 10
                                font.family: "M PLUS 2"
                                font.italic: true
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: "Rebind by editing keybind-overrides.lua, e.g. [\"panel.launcher\"] = \"SUPER + K\", then reload Hyprland."
                    color: section.theme ? section.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                    font.pixelSize: 10
                    font.family: "M PLUS 2"
                    wrapMode: Text.WordWrap
                }

                ActionButton {
                    label: "Open folder"
                    onClicked: { section.openUrl(section.overridesDir); section.bump() }
                }
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 10
            visible: section.mode === "reference"

            Repeater {
                model: {
                    for (const c of section.referenceCategories)
                        if (c.id === section.referenceCategory) return c.sections
                    return []
                }
                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: 2

                    Text {
                        text: modelData.name
                        color: section.theme ? section.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.family: "M PLUS 2"
                        font.letterSpacing: 0.5
                        bottomPadding: 4
                    }

                    Repeater {
                        model: modelData.rows
                        delegate: RowLayout {
                            required property var modelData
                            width: parent.width
                            height: 24
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: refKeyText.implicitWidth + 14
                                Layout.preferredHeight: 20
                                radius: 5
                                color: section.theme ? Qt.rgba(section.theme.glowPrimary.r, section.theme.glowPrimary.g, section.theme.glowPrimary.b, 0.12) : Qt.rgba(0.65, 0.55, 0.85, 0.12)
                                border.width: 1
                                border.color: section.theme ? Qt.rgba(section.theme.glowPrimary.r, section.theme.glowPrimary.g, section.theme.glowPrimary.b, 0.3) : Qt.rgba(0.65, 0.55, 0.85, 0.3)

                                Text {
                                    id: refKeyText
                                    anchors.centerIn: parent
                                    text: modelData.keys
                                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.9)
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    font.family: "M PLUS 2"
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.desc
                                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85)
                                font.pixelSize: 12
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
