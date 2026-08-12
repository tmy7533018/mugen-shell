import QtQuick
import QtQuick.Layouts
import "../../lib" as Theme

Item {
    id: root

    required property var modeManager
    property var theme
    required property var timerManager

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(140),
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

    function stepMinutes(delta) {
        root.inputBuffer = ""
        pending.minutes = Math.max(1, Math.min(60, pending.minutes + delta))
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

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: root.requiredBarSize.topMargin
        anchors.bottomMargin: root.requiredBarSize.bottomMargin
        anchors.leftMargin: root.requiredBarSize.leftMargin
        anchors.rightMargin: root.requiredBarSize.rightMargin
        z: 1.8
        enabled: modeManager.isMode("timer")
        visible: enabled
        hoverEnabled: true
        onClicked: modeManager.bump()
        onPositionChanged: modeManager.bump()
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
                else if (timerManager && pending.minutes > 0) timerManager.start(pending.minutes * 60)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                const step = (event.modifiers & Qt.ShiftModifier) ? 5 : 1
                root.stepMinutes(event.key === Qt.Key_Up ? step : -step)
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
            spacing: modeManager.scale(12)
            opacity: root.visualState === "idle" ? 1.0 : 0.0
            visible: opacity > 0.01

            transform: Translate {
                y: idleLayout.opacity > 0.5 ? 0 : -modeManager.scale(6)
                Behavior on y { NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
            }

            Item {
                id: pending
                Layout.preferredWidth: 1
                Layout.preferredHeight: 1
                property int minutes: 0
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: modeManager.scale(10)

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: modeManager.scale(26)
                    Layout.preferredHeight: modeManager.scale(26)
                    radius: width / 2
                    color: minusHover.containsMouse
                        ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.22) : Qt.rgba(0.65, 0.55, 0.85, 0.22))
                        : (theme ? theme.chipInactiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.10))
                    border.width: 1
                    border.color: theme ? theme.chipInactiveBorder : Qt.rgba(0.55, 0.55, 0.68, 0.15)

                    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: modeManager.scale(9)
                        height: modeManager.scale(1.6)
                        radius: height / 2
                        color: theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                    }

                    MouseArea {
                        id: minusHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stepMinutes(-1)
                    }
                }

                Item {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: modeManager.scale(100)
                    Layout.preferredHeight: modeManager.scale(38)

                    Text {
                        anchors.centerIn: parent
                        text: root.inputBuffer.length > 0 ? root.formatInputDisplay() : root.formatSec(pending.minutes * 60)
                        color: root.inputBuffer.length > 0
                            ? (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                            : (theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95))
                        font.pixelSize: modeManager.scale(26)
                        font.weight: Font.Light
                        font.family: "M PLUS 2"
                        font.letterSpacing: 1

                        Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onWheel: (wheel) => {
                            const step = (wheel.modifiers & Qt.ShiftModifier) ? 5 : 1
                            root.stepMinutes(wheel.angleDelta.y > 0 ? step : -step)
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: modeManager.scale(26)
                    Layout.preferredHeight: modeManager.scale(26)
                    radius: width / 2
                    color: plusHover.containsMouse
                        ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.22) : Qt.rgba(0.65, 0.55, 0.85, 0.22))
                        : (theme ? theme.chipInactiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.10))
                    border.width: 1
                    border.color: theme ? theme.chipInactiveBorder : Qt.rgba(0.55, 0.55, 0.68, 0.15)

                    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: modeManager.scale(9)
                        height: modeManager.scale(1.6)
                        radius: height / 2
                        color: theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: modeManager.scale(1.6)
                        height: modeManager.scale(9)
                        radius: width / 2
                        color: theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                    }

                    MouseArea {
                        id: plusHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stepMinutes(1)
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: modeManager.scale(150)
                Layout.preferredHeight: 1
                Layout.alignment: Qt.AlignHCenter
                color: theme ? Qt.rgba(theme.textFaint.r, theme.textFaint.g, theme.textFaint.b, 0.18) : Qt.rgba(0.62, 0.62, 0.72, 0.18)
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: modeManager.scale(130)
                Layout.preferredHeight: modeManager.scale(30)
                radius: height / 2
                color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, startHover.containsMouse ? 0.32 : 0.22) : Qt.rgba(0.65, 0.55, 0.85, 0.22)

                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                Text {
                    anchors.centerIn: parent
                    text: "Start"
                    color: theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                    font.pixelSize: modeManager.scale(13)
                    font.weight: Font.Medium
                    font.family: "M PLUS 2"
                    font.letterSpacing: 0.5
                }

                MouseArea {
                    id: startHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.hasInput) root.startFromInput()
                        else if (timerManager && pending.minutes > 0) timerManager.start(pending.minutes * 60)
                    }
                }
            }
        }

        ColumnLayout {
            id: runningLayout
            anchors.centerIn: parent
            spacing: modeManager.scale(12)
            opacity: root.visualState === "running" ? 1.0 : 0.0
            visible: opacity > 0.01

            transform: Translate {
                y: runningLayout.opacity > 0.5 ? 0 : modeManager.scale(6)
                Behavior on y { NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
            }

            Text {
                id: runningTimeText
                Layout.alignment: Qt.AlignHCenter
                text: timerManager ? root.formatSec(timerManager.remainingSec) : "00:00"
                color: root.isUrgent
                    ? root.urgentColor
                    : (theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95))
                font.pixelSize: modeManager.scale(26)
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
            }

            Rectangle {
                Layout.preferredWidth: modeManager.scale(150)
                Layout.preferredHeight: 1
                Layout.alignment: Qt.AlignHCenter
                color: theme ? Qt.rgba(theme.textFaint.r, theme.textFaint.g, theme.textFaint.b, 0.18) : Qt.rgba(0.62, 0.62, 0.72, 0.18)
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: modeManager.scale(8)

                Rectangle {
                    Layout.preferredWidth: modeManager.scale(80)
                    Layout.preferredHeight: modeManager.scale(30)
                    radius: height / 2
                    color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, pauseHover.containsMouse ? 0.32 : 0.22) : Qt.rgba(0.65, 0.55, 0.85, 0.22)

                    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                    Text {
                        anchors.centerIn: parent
                        text: timerManager && timerManager.paused ? "Resume" : "Pause"
                        color: theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                        font.pixelSize: modeManager.scale(13)
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
                    Layout.preferredWidth: modeManager.scale(60)
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
                        font.pixelSize: modeManager.scale(13)
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
            spacing: modeManager.scale(12)
            opacity: root.visualState === "alerting" ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "0:00"
                color: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.95)
                font.pixelSize: modeManager.scale(26)
                font.weight: Font.Light
                font.family: "M PLUS 2"
                font.letterSpacing: 1

                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: alertingLayout.visible
                    NumberAnimation { from: 1.0; to: 1.08; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.08; to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                }
            }

            Rectangle {
                Layout.preferredWidth: modeManager.scale(150)
                Layout.preferredHeight: 1
                Layout.alignment: Qt.AlignHCenter
                color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.3) : Qt.rgba(0.65, 0.55, 0.85, 0.3)
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: modeManager.scale(130)
                Layout.preferredHeight: modeManager.scale(30)
                radius: height / 2
                color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, dismissHover.containsMouse ? 0.42 : 0.30) : Qt.rgba(0.65, 0.55, 0.85, 0.30)

                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

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
