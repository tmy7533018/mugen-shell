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
        "height": modeManager.scale(190),
        "leftMargin": modeManager.scale(740),
        "rightMargin": modeManager.scale(740),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })

    readonly property string visualState: {
        if (timerManager && timerManager.running) return "running"
        return "idle"
    }

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

    function durationLabel(sec) {
        if (sec >= 3600) {
            const h = Math.floor(sec / 3600)
            const m = Math.floor((sec % 3600) / 60)
            return m === 0 ? h + "h" : h + "h" + m + "m"
        }
        if (sec >= 60) {
            const m = Math.floor(sec / 60)
            const s = sec % 60
            return s === 0 ? m + "m" : m + "m" + s + "s"
        }
        return sec + "s"
    }

    function formatInputDisplay() {
        const buf = inputBuffer
        if (buf === "") return ""
        if (buf.indexOf(":") >= 0) return buf
        // Plain minutes; show as M:00 once at least one digit typed
        return buf + ":00"
    }

    function startFromInput() {
        const sec = parseInputSeconds()
        if (sec > 0 && timerManager) {
            timerManager.start(sec)
            inputBuffer = ""
        }
    }

    function startPreset(seconds) {
        inputBuffer = ""
        if (timerManager) timerManager.start(seconds)
    }

    Timer {
        id: focusTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: {
            if (modeManager && modeManager.isMode("timer")) focusScope.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("timer", root)
            if (modeManager.isMode("timer")) focusTimer.restart()
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("timer")) focusTimer.restart()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 1
        enabled: modeManager.isMode("timer")
        hoverEnabled: true
        onClicked: modeManager.closeAllModes()
        onPositionChanged: if (modeManager.isMode("timer")) modeManager.bump()
    }

    FocusScope {
        id: focusScope
        anchors.fill: parent
        z: 2
        focus: modeManager.isMode("timer")

        Keys.onPressed: (event) => {
            if (modeManager.isMode("timer")) modeManager.bump()

            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
                return
            }

            if (root.visualState === "running") {
                if (event.key === Qt.Key_Space) {
                    if (timerManager.paused) timerManager.resume()
                    else timerManager.pause()
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_C) {
                    timerManager.cancel()
                    event.accepted = true
                    return
                }
                return
            }

            // Idle
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

        // ────────────────────────── Idle layout ──────────────────────────
        ColumnLayout {
            anchors.centerIn: parent
            spacing: modeManager.scale(14)
            visible: root.visualState === "idle"

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: modeManager.scale(322)
                spacing: modeManager.scale(10)

                Text {
                    text: "TIMER"
                    color: theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.75)
                    font.pixelSize: modeManager.scale(12)
                    font.weight: Font.Medium
                    font.family: "M PLUS 2"
                    font.letterSpacing: 1.5
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: inputField
                    Layout.preferredWidth: modeManager.scale(150)
                    Layout.preferredHeight: modeManager.scale(34)

                    readonly property bool isFocused: focusScope.activeFocus && root.visualState === "idle"

                    color: inputHover.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                    border.width: 1
                    border.color: inputField.isFocused
                        ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6))
                        : (theme ? Qt.rgba(theme.textFaint.r, theme.textFaint.g, theme.textFaint.b, 0.30) : Qt.rgba(0.62, 0.62, 0.72, 0.30))
                    radius: modeManager.scale(10)

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: modeManager.scale(12)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: modeManager.scale(2)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.inputBuffer.length > 0 ? root.formatInputDisplay() : "M:SS"
                            color: root.inputBuffer.length > 0
                                ? (theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95))
                                : (theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.55))
                            font.pixelSize: modeManager.scale(13)
                            font.family: "M PLUS 2"
                            font.letterSpacing: 0.5
                        }

                        Rectangle {
                            id: caret
                            anchors.verticalCenter: parent.verticalCenter
                            width: modeManager.scale(1.5)
                            height: modeManager.scale(15)
                            color: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
                            visible: inputField.isFocused

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: caret.visible
                                NumberAnimation { from: 1.0; to: 0.0; duration: 500; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: 0.0; to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: modeManager.scale(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↵"
                        color: theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.55)
                        font.pixelSize: modeManager.scale(12)
                        font.family: "M PLUS 2"
                        opacity: root.inputBuffer.length > 0 ? 0.85 : 0.4

                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: inputHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.IBeamCursor
                        onClicked: focusScope.forceActiveFocus()
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: modeManager.scale(8)

                Repeater {
                    model: [
                        { label: "1m", seconds: 60 },
                        { label: "5m", seconds: 300 },
                        { label: "10m", seconds: 600 },
                        { label: "25m", seconds: 1500 },
                        { label: "60m", seconds: 3600 }
                    ]

                    delegate: Rectangle {
                        Layout.preferredWidth: modeManager.scale(58)
                        Layout.preferredHeight: modeManager.scale(32)
                        radius: modeManager.scale(10)
                        property bool isSelected: root.parseInputSeconds() === modelData.seconds
                        color: isSelected
                            ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.20) : Qt.rgba(0.65, 0.55, 0.85, 0.20))
                            : (presetHover.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                        border.width: 1
                        border.color: isSelected
                            ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                            : (theme ? Qt.rgba(theme.textFaint.r, theme.textFaint.g, theme.textFaint.b, 0.30) : Qt.rgba(0.62, 0.62, 0.72, 0.30))

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: isSelected
                                ? (theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95))
                                : (theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85))
                            font.pixelSize: modeManager.scale(12)
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

        // ────────────────────────── Running layout ──────────────────────────
        RowLayout {
            anchors.centerIn: parent
            spacing: modeManager.scale(24)
            visible: root.visualState === "running"

            Item {
                Layout.preferredWidth: modeManager.scale(116)
                Layout.preferredHeight: modeManager.scale(116)
                Layout.alignment: Qt.AlignVCenter

                Canvas {
                    id: ring
                    anchors.fill: parent
                    antialiasing: true

                    property real progress: {
                        if (!timerManager || timerManager.durationSec <= 0) return 0
                        return Math.max(0, Math.min(1, timerManager.remainingSec / timerManager.durationSec))
                    }
                    property color trackColor: theme
                        ? Qt.rgba(theme.textFaint.r, theme.textFaint.g, theme.textFaint.b, 0.18)
                        : Qt.rgba(0.62, 0.62, 0.72, 0.18)
                    property color progressColor: timerManager && timerManager.paused
                        ? (theme ? Qt.rgba(theme.textSecondary.r, theme.textSecondary.g, theme.textSecondary.b, 0.85) : Qt.rgba(0.72, 0.72, 0.82, 0.85))
                        : (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.95))
                    property real strokeWidth: modeManager.scale(4)

                    onProgressChanged: requestPaint()
                    onTrackColorChanged: requestPaint()
                    onProgressColorChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const cx = width / 2
                        const cy = height / 2
                        const r = Math.min(cx, cy) - strokeWidth

                        ctx.beginPath()
                        ctx.lineWidth = strokeWidth
                        ctx.strokeStyle = trackColor
                        ctx.arc(cx, cy, r, 0, Math.PI * 2)
                        ctx.stroke()

                        if (progress > 0) {
                            ctx.beginPath()
                            ctx.lineWidth = strokeWidth
                            ctx.lineCap = "round"
                            ctx.strokeStyle = progressColor
                            const start = -Math.PI / 2
                            const end = start - Math.PI * 2 * progress
                            ctx.arc(cx, cy, r, start, end, true)
                            ctx.stroke()
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: modeManager.scale(2)

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: timerManager ? root.formatSec(timerManager.remainingSec) : "00:00"
                        color: theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                        font.pixelSize: modeManager.scale(22)
                        font.weight: Font.Light
                        font.family: "M PLUS 2"
                        font.letterSpacing: 1
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: timerManager && timerManager.paused ? "PAUSED" : "REMAINING"
                        color: theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.65)
                        font.pixelSize: modeManager.scale(8)
                        font.weight: Font.Medium
                        font.family: "M PLUS 2"
                        font.letterSpacing: 1.8
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: modeManager.scale(14)

                Text {
                    text: (timerManager && timerManager.paused ? "PAUSED" : "RUNNING") + " · " + (timerManager ? root.durationLabel(timerManager.durationSec) : "")
                    color: theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.85)
                    font.pixelSize: modeManager.scale(11)
                    font.weight: Font.Medium
                    font.family: "M PLUS 2"
                    font.letterSpacing: 1.5
                }

                RowLayout {
                    spacing: modeManager.scale(8)

                    Rectangle {
                        Layout.preferredWidth: modeManager.scale(96)
                        Layout.preferredHeight: modeManager.scale(34)
                        radius: modeManager.scale(11)
                        color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, pauseHover.containsMouse ? 0.32 : 0.22) : Qt.rgba(0.65, 0.55, 0.85, 0.22)
                        border.width: 0

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: timerManager && timerManager.paused ? "Resume" : "Pause"
                            color: theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                            font.pixelSize: modeManager.scale(12)
                            font.weight: Font.Medium
                            font.family: "M PLUS 2"
                            font.letterSpacing: 0.5
                        }

                        MouseArea {
                            id: pauseHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (timerManager.paused) timerManager.resume()
                                else timerManager.pause()
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: modeManager.scale(76)
                        Layout.preferredHeight: modeManager.scale(34)
                        radius: modeManager.scale(11)
                        color: stopHover.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        border.width: 1
                        border.color: theme ? Qt.rgba(theme.textFaint.r, theme.textFaint.g, theme.textFaint.b, 0.35) : Qt.rgba(0.62, 0.62, 0.72, 0.35)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Stop"
                            color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                            font.pixelSize: modeManager.scale(12)
                            font.weight: Font.Medium
                            font.family: "M PLUS 2"
                            font.letterSpacing: 0.5
                        }

                        MouseArea {
                            id: stopHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: timerManager.cancel()
                        }
                    }
                }
            }
        }

    }
}
