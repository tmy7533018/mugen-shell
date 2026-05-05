import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell

Item {
    id: root

    required property var modeManager
    property var theme
    required property var timerManager

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(380),
        "leftMargin": modeManager.scale(700),
        "rightMargin": modeManager.scale(700),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })

    property string inputBuffer: ""

    function parseInputSeconds() {
        let s = inputBuffer.trim()
        if (s === "") return 0
        if (s.indexOf(":") >= 0) {
            let parts = s.split(":")
            let mm = parseInt(parts[0]) || 0
            let ss = parseInt(parts[1]) || 0
            return mm * 60 + ss
        }
        return (parseInt(s) || 0) * 60
    }

    function formatSec(total) {
        if (total < 0) total = 0
        const h = Math.floor(total / 3600)
        const m = Math.floor((total % 3600) / 60)
        const s = total % 60
        const pad = n => n < 10 ? "0" + n : "" + n
        if (h > 0) return h + ":" + pad(m) + ":" + pad(s)
        return pad(m) + ":" + pad(s)
    }

    function startFromInput() {
        const sec = parseInputSeconds()
        if (sec > 0 && timerManager) timerManager.start(sec)
    }

    function startPreset(seconds) {
        inputBuffer = ""
        if (timerManager) timerManager.start(seconds)
    }

    readonly property string displayText: {
        if (!timerManager) return "00:00"
        if (timerManager.running) return formatSec(timerManager.remainingSec)
        const sec = parseInputSeconds()
        return formatSec(sec)
    }

    readonly property bool hasInput: parseInputSeconds() > 0

    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("timer", root)
            if (modeManager.isMode("timer")) focusScope.forceActiveFocus()
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("timer")) focusScope.forceActiveFocus()
        }
    }

    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: modeManager.isMode("timer")

        Keys.onPressed: (event) => {
            if (modeManager.isMode("timer")) modeManager.bump()

            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
                return
            }

            if (timerManager && timerManager.running) {
                if (event.key === Qt.Key_Space) {
                    if (timerManager.paused) timerManager.resume()
                    else timerManager.pause()
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_C || event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
                    timerManager.cancel()
                    event.accepted = true
                    return
                }
                return
            }

            // Not running — input mode
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.startFromInput()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Backspace) {
                if (root.inputBuffer.length > 0) {
                    root.inputBuffer = root.inputBuffer.substring(0, root.inputBuffer.length - 1)
                }
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Delete) {
                root.inputBuffer = ""
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Colon || (event.key === Qt.Key_Semicolon && (event.modifiers & Qt.ShiftModifier))) {
                if (root.inputBuffer.indexOf(":") < 0 && root.inputBuffer.length > 0) {
                    root.inputBuffer += ":"
                }
                event.accepted = true
                return
            }
            if (event.text && event.text.length === 1 && event.text >= "0" && event.text <= "9") {
                if (root.inputBuffer.length < 6) root.inputBuffer += event.text
                event.accepted = true
                return
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: modeManager.scale(20)

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.displayText
                color: {
                    if (timerManager && timerManager.running && !timerManager.paused) {
                        return theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                    }
                    if (timerManager && timerManager.paused) {
                        return theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85)
                    }
                    if (root.hasInput) {
                        return theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                    }
                    return theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.55)
                }
                font.pixelSize: modeManager.scale(78)
                font.weight: Font.Light
                font.family: "M PLUS 2"
                font.letterSpacing: 2

                Behavior on color { ColorAnimation { duration: 200 } }

                layer.enabled: true
                layer.effect: Glow {
                    samples: 24
                    radius: modeManager.scale(10)
                    spread: 0.4
                    color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                    transparentBorder: true
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: !timerManager || !timerManager.running
                text: root.hasInput ? "Enter to start" : "Type minutes (or M:SS), or pick a preset"
                color: theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.55)
                font.pixelSize: modeManager.scale(11)
                font.family: "M PLUS 2"
                font.letterSpacing: 0.4
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: modeManager.scale(10)
                visible: timerManager && timerManager.running

                Component.onCompleted: {}

                Repeater {
                    model: timerManager && timerManager.running
                        ? (timerManager.paused
                            ? [{ label: "Resume", action: "resume" }, { label: "Cancel", action: "cancel" }]
                            : [{ label: "Pause", action: "pause" }, { label: "Cancel", action: "cancel" }])
                        : []

                    delegate: Rectangle {
                        Layout.preferredWidth: modeManager.scale(96)
                        Layout.preferredHeight: modeManager.scale(32)
                        color: actionHover.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        border.width: 1
                        border.color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.35) : Qt.rgba(0.65, 0.55, 0.85, 0.35)
                        radius: modeManager.scale(16)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.92)
                            font.pixelSize: modeManager.scale(12)
                            font.weight: Font.Medium
                            font.family: "M PLUS 2"
                            font.letterSpacing: 0.5
                        }

                        MouseArea {
                            id: actionHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.action === "pause") timerManager.pause()
                                else if (modelData.action === "resume") timerManager.resume()
                                else if (modelData.action === "cancel") timerManager.cancel()
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: modeManager.scale(8)
                visible: !timerManager || !timerManager.running

                Repeater {
                    model: [
                        { label: "1m", seconds: 60 },
                        { label: "5m", seconds: 300 },
                        { label: "10m", seconds: 600 },
                        { label: "25m", seconds: 1500 },
                        { label: "60m", seconds: 3600 }
                    ]

                    delegate: Rectangle {
                        Layout.preferredWidth: modeManager.scale(56)
                        Layout.preferredHeight: modeManager.scale(28)
                        color: presetHover.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        border.width: 1
                        border.color: theme ? Qt.rgba(theme.textFaint.r, theme.textFaint.g, theme.textFaint.b, 0.30) : Qt.rgba(0.62, 0.62, 0.72, 0.30)
                        radius: modeManager.scale(14)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85)
                            font.pixelSize: modeManager.scale(11)
                            font.weight: Font.Medium
                            font.family: "M PLUS 2"
                            font.letterSpacing: 0.5
                        }

                        MouseArea {
                            id: presetHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.startPreset(modelData.seconds)
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: modeManager.isMode("timer")
        onClicked: focusScope.forceActiveFocus()
        onPositionChanged: if (modeManager.isMode("timer")) modeManager.bump()
    }
}
