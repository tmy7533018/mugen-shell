import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../../lib" as Theme
import "../common" as Common

Item {
    id: root

    required property var modeManager
    property var theme
    required property var timerManager

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(188),
        "leftMargin": modeManager.scale(860),
        "rightMargin": modeManager.scale(860),
        "topMargin": modeManager.normalBarSize.topMargin,
        "bottomMargin": modeManager.normalBarSize.bottomMargin
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
        return buf + ":00"
    }

    function startFromInput() {
        const sec = parseInputSeconds()
        if (sec > 0 && timerManager) {
            timerManager.start(sec)
            inputBuffer = ""
        }
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
                if (root.hasInput) root.startFromInput()
                else if (timerManager) timerManager.start(dial.minutes * 60)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                root.inputBuffer = ""
                const step = (event.modifiers & Qt.ShiftModifier) ? 5 : 1
                dial.minutes = Math.max(1, Math.min(60,
                    dial.minutes + (event.key === Qt.Key_Up ? step : -step)))
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
            spacing: modeManager.scale(10)
            opacity: root.visualState === "idle" ? 1.0 : 0.0
            visible: opacity > 0.01

            transform: Translate {
                y: idleLayout.opacity > 0.5 ? 0 : -modeManager.scale(6)
                Behavior on y { NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
            }


                // Size must match the running progress ring so the dial you set
                // visually becomes the ring that counts down.
                Item {
                    id: dial
                    Layout.preferredWidth: modeManager.scale(116)
                    Layout.preferredHeight: modeManager.scale(116)
                    Layout.alignment: Qt.AlignHCenter

                    property int minutes: 10
                    readonly property bool typing: root.inputBuffer.length > 0
                    readonly property real fraction: typing
                        ? Math.min(1, root.parseInputSeconds() / 3600)
                        : minutes / 60

                    function setFromAngle(mx, my) {
                        let rel = Math.atan2(my - height / 2, mx - width / 2) + Math.PI / 2
                        if (rel < 0) rel += Math.PI * 2
                        root.inputBuffer = ""
                        minutes = Math.max(1, Math.min(60, Math.round(rel / (Math.PI * 2) * 60)))
                    }

                    onFractionChanged: dialCanvas.requestPaint()

                    Canvas {
                        id: dialCanvas
                        anchors.fill: parent
                        antialiasing: true

                        property color trackColor: theme
                            ? Qt.rgba(theme.textFaint.r, theme.textFaint.g, theme.textFaint.b, 0.18)
                            : Qt.rgba(0.62, 0.62, 0.72, 0.18)
                        property color arcColor: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.95)

                        onTrackColorChanged: requestPaint()
                        onArcColorChanged: requestPaint()

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const cx = width / 2
                            const cy = height / 2
                            const r = Math.min(cx, cy) - modeManager.scale(6)

                            ctx.beginPath()
                            ctx.lineWidth = modeManager.scale(4)
                            ctx.strokeStyle = trackColor
                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.stroke()

                            if (dial.fraction > 0) {
                                const end = -Math.PI / 2 + Math.PI * 2 * dial.fraction
                                ctx.beginPath()
                                ctx.lineWidth = modeManager.scale(4)
                                ctx.lineCap = "round"
                                ctx.strokeStyle = arcColor
                                ctx.arc(cx, cy, r, -Math.PI / 2, end)
                                ctx.stroke()

                                ctx.fillStyle = theme ? theme.textPrimary : Qt.rgba(0.95, 0.93, 1, 1)
                                ctx.beginPath()
                                ctx.arc(cx + Math.cos(end) * r, cy + Math.sin(end) * r, modeManager.scale(5), 0, Math.PI * 2)
                                ctx.fill()
                            }
                        }

                        layer.enabled: true
                        layer.effect: Glow {
                            samples: 24
                            radius: modeManager.scale(dialMouse.containsMouse ? 12 : 8)
                            spread: 0.35
                            color: theme
                                ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.45)
                                : Qt.rgba(0.65, 0.55, 0.85, 0.45)
                            transparentBorder: true

                            Behavior on radius { NumberAnimation { duration: Theme.Motion.fast } }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dial.typing ? root.formatInputDisplay() : dial.minutes
                            color: theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                            font.pixelSize: modeManager.scale(dial.typing ? 24 : 32)
                            font.weight: Font.Light
                            font.family: "M PLUS 2"

                            layer.enabled: true
                            layer.effect: Glow {
                                samples: 20
                                radius: modeManager.scale(7)
                                spread: 0.3
                                color: theme
                                    ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.40)
                                    : Qt.rgba(0.65, 0.55, 0.85, 0.40)
                                transparentBorder: true
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "MIN"
                            opacity: dial.typing ? 0.0 : 1.0

                            Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }
                            color: theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.65)
                            font.pixelSize: modeManager.scale(8)
                            font.weight: Font.Medium
                            font.family: "M PLUS 2"
                            font.letterSpacing: 1.8
                        }
                    }

                    MouseArea {
                        id: dialMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        property bool dragged: false

                        onWheel: (wheel) => {
                            root.inputBuffer = ""
                            const step = (wheel.modifiers & Qt.ShiftModifier) ? 5 : 1
                            const dir = wheel.angleDelta.y > 0 ? 1 : -1
                            dial.minutes = Math.max(1, Math.min(60, dial.minutes + dir * step))
                        }
                        onPressed: dragged = false
                        onPositionChanged: (mouse) => {
                            if (pressed) {
                                dragged = true
                                dial.setFromAngle(mouse.x, mouse.y)
                            }
                        }
                        onClicked: {
                            if (dialMouse.dragged) return
                            if (root.hasInput) root.startFromInput()
                            else if (timerManager) timerManager.start(dial.minutes * 60)
                        }
                    }
                }

                // Displays the key handler's buffer rather than taking input
                // itself; focus stays on the mode's FocusScope.
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: modeManager.scale(152)
                    Layout.preferredHeight: modeManager.scale(30)
                    radius: height / 2
                    color: root.hasInput
                        ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.12) : Qt.rgba(0.65, 0.55, 0.85, 0.12))
                        : "transparent"
                    border.width: 1
                    border.color: root.hasInput
                        ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                        : (theme ? Qt.rgba(theme.textFaint.r, theme.textFaint.g, theme.textFaint.b, 0.25) : Qt.rgba(0.62, 0.62, 0.72, 0.25))

                    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                    Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

                    Row {
                        anchors.centerIn: parent
                        spacing: modeManager.scale(3)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.inputBuffer.length > 0 ? root.formatInputDisplay() : "M:SS"
                            color: root.inputBuffer.length > 0
                                ? (theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95))
                                : (theme ? Qt.rgba(theme.textFaint.r, theme.textFaint.g, theme.textFaint.b, 0.5) : Qt.rgba(0.62, 0.62, 0.72, 0.5))
                            font.pixelSize: modeManager.scale(12)
                            font.family: "M PLUS 2"
                            font.letterSpacing: 0.5
                        }

                        Rectangle {
                            id: inputCaret
                            anchors.verticalCenter: parent.verticalCenter
                            width: modeManager.scale(1.5)
                            height: modeManager.scale(13)
                            color: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
                            visible: focusScope.activeFocus && root.visualState === "idle"

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: inputCaret.visible
                                NumberAnimation { from: 1.0; to: 0.35; duration: 720; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 0.35; to: 1.0; duration: 720; easing.type: Easing.InOutSine }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "↵"
                            color: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
                            font.pixelSize: modeManager.scale(11)
                            font.family: "M PLUS 2"
                            opacity: root.hasInput ? 0.95 : 0.0
                            visible: opacity > 0.01

                            Behavior on opacity { NumberAnimation { duration: Theme.Motion.micro } }
                        }
                    }
                }

        }

        ColumnLayout {
            id: runningLayout
            anchors.centerIn: parent
            spacing: modeManager.scale(10)
            opacity: root.visualState === "running" ? 1.0 : 0.0
            visible: opacity > 0.01
            onVisibleChanged: if (visible) ignitePop.restart()

            transform: Translate {
                y: runningLayout.opacity > 0.5 ? 0 : modeManager.scale(6)
                Behavior on y { NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
            }

            Item {
                id: ringWrap
                Layout.preferredWidth: modeManager.scale(116)
                Layout.preferredHeight: modeManager.scale(116)
                Layout.alignment: Qt.AlignHCenter

                NumberAnimation {
                    id: ignitePop
                    target: ringWrap
                    property: "scale"
                    from: 0.72
                    to: 1.0
                    duration: Theme.Motion.slow
                    easing.type: Theme.Motion.easeSpring
                }

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

                Common.BlobEffect {
                    anchors.centerIn: parent
                    width: modeManager.scale(72)
                    height: modeManager.scale(72)
                    blobColor: ring.progressColor
                    layers: 2
                    waveAmplitude: 2.5
                    baseOpacity: 0.4
                    animationSpeed: root.isUrgent ? 0.22 : 0.04 + 0.10 * (1 - ring.progress)
                    running: runningLayout.visible && !(timerManager && timerManager.paused)
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

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: modeManager.scale(8)

                    Rectangle {
                        Layout.preferredWidth: modeManager.scale(80)
                        Layout.preferredHeight: modeManager.scale(30)
                        radius: height / 2
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
                        Layout.preferredWidth: modeManager.scale(64)
                        Layout.preferredHeight: modeManager.scale(30)
                        radius: height / 2
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

        ColumnLayout {
            id: alertingLayout
            anchors.centerIn: parent
            spacing: modeManager.scale(10)
            opacity: root.visualState === "alerting" ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
            }

            Item {
                Layout.preferredWidth: modeManager.scale(116)
                Layout.preferredHeight: modeManager.scale(116)
                Layout.alignment: Qt.AlignHCenter

                // The leading and trailing pauses must sum to the same total
                // per ripple, or the two drift apart over time.
                Repeater {
                    model: 2

                    Rectangle {
                        id: ripple
                        required property int index
                        anchors.centerIn: parent
                        width: modeManager.scale(86)
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: modeManager.scale(2)
                        border.color: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.95)
                        opacity: 0
                        scale: 0.8

                        SequentialAnimation {
                            running: alertingLayout.visible
                            loops: Animation.Infinite
                            PauseAnimation { duration: ripple.index * 700 }
                            ParallelAnimation {
                                NumberAnimation { target: ripple; property: "scale"; from: 0.8; to: 1.5; duration: 1400; easing.type: Easing.OutCubic }
                                SequentialAnimation {
                                    NumberAnimation { target: ripple; property: "opacity"; from: 0; to: 0.55; duration: 200 }
                                    NumberAnimation { target: ripple; property: "opacity"; to: 0; duration: 1200; easing.type: Easing.OutCubic }
                                }
                            }
                            PauseAnimation { duration: (1 - ripple.index) * 700 }
                        }
                    }
                }

                Common.BlobEffect {
                    anchors.centerIn: parent
                    width: modeManager.scale(84)
                    height: modeManager.scale(84)
                    blobColor: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                    layers: 2
                    waveAmplitude: 3.5
                    baseOpacity: 0.75
                    animationSpeed: 0.16
                    running: alertingLayout.visible
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

            Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: modeManager.scale(84)
                    Layout.preferredHeight: modeManager.scale(30)
                    radius: height / 2
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
