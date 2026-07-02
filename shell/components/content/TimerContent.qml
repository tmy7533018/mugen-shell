import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../../lib" as Theme

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
        if (timerManager && timerManager.alerting) return "alerting"
        if (timerManager && timerManager.running) return "running"
        return "idle"
    }

    readonly property bool isUrgent: timerManager
        && timerManager.running
        && !timerManager.paused
        && timerManager.remainingSec > 0
        && timerManager.remainingSec <= 10

    readonly property color urgentColor: Qt.rgba(0.95, 0.40, 0.45, 1)

    property string inputBuffer: ""
    readonly property bool hasInput: parseInputSeconds() > 0

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

        opacity: 0
        visible: opacity > 0.01

        transform: Translate {
            id: focusScopeTranslate
            y: focusScope.opacity > 0.5 ? 0 : modeManager.scale(8)
            Behavior on y { NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic } }
        }

        states: [
            State {
                name: "visible"
                when: modeManager.isMode("timer")
                PropertyChanges { target: focusScope; opacity: 1.0 }
            }
        ]

        transitions: [
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: Theme.Motion.fast }
                    NumberAnimation { property: "opacity"; duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
                }
            },
            Transition {
                from: "visible"
                to: ""
                NumberAnimation { property: "opacity"; duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
            }
        ]

        Keys.onPressed: (event) => {
            if (modeManager.isMode("timer")) modeManager.bump()

            if (root.visualState === "alerting") {
                if (event.key === Qt.Key_Space
                    || event.key === Qt.Key_Escape
                    || event.key === Qt.Key_Return
                    || event.key === Qt.Key_Enter
                    || event.key === Qt.Key_C) {
                    timerManager.dismissAlert()
                    event.accepted = true
                    return
                }
                return
            }

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
            id: idleLayout
            anchors.centerIn: parent
            spacing: modeManager.scale(14)
            opacity: root.visualState === "idle" ? 1.0 : 0.0
            visible: opacity > 0.01

            transform: Translate {
                y: idleLayout.opacity > 0.5 ? 0 : -modeManager.scale(6)
                Behavior on y { NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
            }

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

                    layer.enabled: true
                    layer.effect: Glow {
                        samples: 16
                        radius: modeManager.scale(5)
                        spread: 0.30
                        color: theme
                            ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.25)
                            : Qt.rgba(0.65, 0.55, 0.85, 0.25)
                        transparentBorder: true
                    }
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

                    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                    Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

                    layer.enabled: inputField.isFocused
                    layer.effect: Glow {
                        samples: 20
                        radius: modeManager.scale(7)
                        spread: 0.30
                        color: theme
                            ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.40)
                            : Qt.rgba(0.65, 0.55, 0.85, 0.40)
                        transparentBorder: true
                    }

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
                                NumberAnimation { from: 1.0; to: 0.35; duration: 720; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 0.35; to: 1.0; duration: 720; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    Text {
                        id: enterHint
                        anchors.right: parent.right
                        anchors.rightMargin: modeManager.scale(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↵"
                        color: root.hasInput
                            ? (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                            : (theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.55))
                        font.pixelSize: modeManager.scale(12)
                        font.family: "M PLUS 2"
                        opacity: root.hasInput ? 0.95 : 0.4

                        Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
                        Behavior on opacity { NumberAnimation { duration: Theme.Motion.micro } }

                        layer.enabled: root.hasInput
                        layer.effect: Glow {
                            samples: 16
                            radius: modeManager.scale(6)
                            spread: 0.4
                            color: theme
                                ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.60)
                                : Qt.rgba(0.65, 0.55, 0.85, 0.60)
                            transparentBorder: true
                        }
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

                        Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                        Behavior on border.color { ColorAnimation { duration: Theme.Motion.micro } }

                        layer.enabled: isSelected || presetHover.containsMouse
                        layer.effect: Glow {
                            samples: 20
                            radius: modeManager.scale(8)
                            spread: 0.4
                            color: theme
                                ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, isSelected ? 0.45 : 0.25)
                                : Qt.rgba(0.65, 0.55, 0.85, isSelected ? 0.45 : 0.25)
                            transparentBorder: true

                            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                        }

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

        RowLayout {
            id: runningLayout
            anchors.centerIn: parent
            spacing: modeManager.scale(24)
            opacity: root.visualState === "running" ? 1.0 : 0.0
            visible: opacity > 0.01

            transform: Translate {
                y: runningLayout.opacity > 0.5 ? 0 : modeManager.scale(6)
                Behavior on y { NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
            }

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
                        : (root.isUrgent
                            ? root.urgentColor
                            : (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.95)))
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

                    layer.enabled: true
                    layer.effect: Glow {
                        samples: 24
                        radius: modeManager.scale(10)
                        spread: 0.35
                        color: timerManager && timerManager.paused
                            ? Qt.rgba(0.72, 0.72, 0.82, 0.30)
                            : (root.isUrgent
                                ? Qt.rgba(root.urgentColor.r, root.urgentColor.g, root.urgentColor.b, 0.65)
                                : (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55)))
                        transparentBorder: true

                        Behavior on color { ColorAnimation { duration: Theme.Motion.standard } }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: modeManager.scale(2)

                    Text {
                        id: runningTimeText
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: timerManager ? root.formatSec(timerManager.remainingSec) : "00:00"
                        color: root.isUrgent
                            ? root.urgentColor
                            : (theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95))
                        font.pixelSize: modeManager.scale(22)
                        font.weight: Font.Light
                        font.family: "M PLUS 2"
                        font.letterSpacing: 1

                        Behavior on color { ColorAnimation { duration: Theme.Motion.standard } }

                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            running: root.isUrgent
                            NumberAnimation { from: 1.0; to: 1.07; duration: 180; easing.type: Easing.OutQuad }
                            NumberAnimation { from: 1.07; to: 1.0; duration: 220; easing.type: Easing.InQuad }
                            PauseAnimation { duration: 600 }
                        }

                        layer.enabled: true
                        layer.effect: Glow {
                            samples: 20
                            radius: modeManager.scale(7)
                            spread: 0.35
                            color: root.isUrgent
                                ? Qt.rgba(root.urgentColor.r, root.urgentColor.g, root.urgentColor.b, 0.55)
                                : (theme
                                    ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, timerManager && timerManager.paused ? 0.20 : 0.45)
                                    : Qt.rgba(0.65, 0.55, 0.85, 0.45))
                            transparentBorder: true

                            Behavior on color { ColorAnimation { duration: Theme.Motion.standard } }
                        }
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

                        Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                        layer.enabled: true
                        layer.effect: Glow {
                            samples: 24
                            radius: modeManager.scale(pauseHover.containsMouse ? 12 : 6)
                            spread: 0.35
                            color: theme
                                ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, pauseHover.containsMouse ? 0.55 : 0.30)
                                : Qt.rgba(0.65, 0.55, 0.85, pauseHover.containsMouse ? 0.55 : 0.30)
                            transparentBorder: true

                            Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
                            Behavior on radius { NumberAnimation { duration: Theme.Motion.fast } }
                        }

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

                        Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

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

        RowLayout {
            id: alertingLayout
            anchors.centerIn: parent
            spacing: modeManager.scale(24)
            opacity: root.visualState === "alerting" ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
            }

            Item {
                Layout.preferredWidth: modeManager.scale(116)
                Layout.preferredHeight: modeManager.scale(116)
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    id: alertRing
                    anchors.centerIn: parent
                    width: modeManager.scale(110)
                    height: modeManager.scale(110)
                    radius: width / 2
                    color: "transparent"
                    border.width: modeManager.scale(4)
                    border.color: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.95)

                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: alertingLayout.visible
                        NumberAnimation { from: 1.0; to: 1.06; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.06; to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                    }

                    layer.enabled: true
                    layer.effect: Glow {
                        samples: 28
                        radius: modeManager.scale(14)
                        spread: 0.45
                        color: theme
                            ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.65)
                            : Qt.rgba(0.65, 0.55, 0.85, 0.65)
                        transparentBorder: true
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "0:00"
                    color: theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                    font.pixelSize: modeManager.scale(22)
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    font.letterSpacing: 1

                    layer.enabled: true
                    layer.effect: Glow {
                        samples: 20
                        radius: modeManager.scale(7)
                        spread: 0.35
                        color: theme
                            ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.55)
                            : Qt.rgba(0.65, 0.55, 0.85, 0.55)
                        transparentBorder: true
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: modeManager.scale(12)

                Text {
                    text: "Timer finished"
                    color: theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                    font.pixelSize: modeManager.scale(15)
                    font.weight: Font.Medium
                    font.family: "M PLUS 2"
                    font.letterSpacing: 0.6
                }

                Text {
                    text: "Press Space or Stop to dismiss"
                    color: theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.65)
                    font.pixelSize: modeManager.scale(11)
                    font.family: "M PLUS 2"
                    font.letterSpacing: 0.3
                }

                Rectangle {
                    Layout.preferredWidth: modeManager.scale(110)
                    Layout.preferredHeight: modeManager.scale(36)
                    Layout.topMargin: modeManager.scale(2)
                    radius: modeManager.scale(12)
                    color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, dismissHover.containsMouse ? 0.36 : 0.24) : Qt.rgba(0.65, 0.55, 0.85, 0.24)
                    border.width: 0

                    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                    layer.enabled: true
                    layer.effect: Glow {
                        samples: 24
                        radius: modeManager.scale(dismissHover.containsMouse ? 14 : 8)
                        spread: 0.4
                        color: theme
                            ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, dismissHover.containsMouse ? 0.6 : 0.40)
                            : Qt.rgba(0.65, 0.55, 0.85, dismissHover.containsMouse ? 0.6 : 0.40)
                        transparentBorder: true

                        Behavior on radius { NumberAnimation { duration: Theme.Motion.fast } }
                        Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Stop"
                        color: theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                        font.pixelSize: modeManager.scale(13)
                        font.weight: Font.Medium
                        font.family: "M PLUS 2"
                        font.letterSpacing: 0.5
                    }

                    MouseArea {
                        id: dismissHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: timerManager.dismissAlert()
                    }
                }
            }
        }

    }
}
