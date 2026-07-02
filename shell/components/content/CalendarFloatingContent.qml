import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../common" as Common
import "../../lib" as Theme

Item {
    id: root

    required property var modeManager
    property var theme

    property int currentYear: new Date().getFullYear()
    property int currentMonth: new Date().getMonth() + 1

    readonly property int todayDay: new Date().getDate()
    readonly property int todayMonth: new Date().getMonth() + 1
    readonly property int todayYear: new Date().getFullYear()

    property string selectedDate: dateKey(currentYear, currentMonth, todayDay)

    property var events: []
    property var eventsByDate: ({})

    property string formTitle: ""
    property string formTime: ""
    property bool formAllDay: false

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
                                       "July", "August", "September", "October", "November", "December"]

    readonly property var modalEvents: (selectedDate && eventsByDate[selectedDate]) ? eventsByDate[selectedDate] : []

    readonly property bool isTimeFieldInvalid: {
        if (!formTime) return false
        if (formTime.length < 5) return false
        return !isValidTime(formTime)
    }

    function dateKey(year, month, day) {
        let m = month < 10 ? "0" + month : "" + month
        let d = day < 10 ? "0" + day : "" + day
        return year + "-" + m + "-" + d
    }

    function eventsForDate(key) {
        return eventsByDate[key] || []
    }

    function rebuildIndex() {
        let idx = {}
        for (let i = 0; i < events.length; i++) {
            let e = events[i]
            if (!e || !e.date) continue
            if (!idx[e.date]) idx[e.date] = []
            idx[e.date].push(e)
        }
        eventsByDate = idx
    }

    function rangeForMonth(year, month) {
        let pad = n => n < 10 ? "0" + n : "" + n
        let prevYear = month === 1 ? year - 1 : year
        let prevMonth = month === 1 ? 12 : month - 1
        let nextYear = month === 12 ? year + 1 : year
        let nextMonth = month === 12 ? 1 : month + 1
        let start = prevYear + "-" + pad(prevMonth) + "-01"
        let lastDay = new Date(nextYear, nextMonth, 0).getDate()
        let end = nextYear + "-" + pad(nextMonth) + "-" + pad(lastDay)
        return [start, end]
    }

    function reloadEvents() {
        let r = rangeForMonth(currentYear, currentMonth)
        loadEventsProcess.command = [
            "python3", Quickshell.shellDir + "/scripts/calendar-cli.py",
            "list-range", "--start", r[0], "--end", r[1]
        ]
        loadEventsProcess.running = true
    }

    function addEvent(date, title, time) {
        if (!date || !title) return
        addEventProcess.command = [
            "python3", Quickshell.shellDir + "/scripts/calendar-cli.py",
            "add", "--date", date, "--title", title, "--time", time || ""
        ]
        addEventProcess.running = true
    }

    function deleteEvent(id) {
        if (!id) return
        deleteEventProcess.command = [
            "python3", Quickshell.shellDir + "/scripts/calendar-cli.py",
            "delete", "--id", id
        ]
        deleteEventProcess.running = true
    }

    function isValidTime(t) {
        return /^([01]?\d|2[0-3]):[0-5]\d$/.test(t)
    }

    function formatTimeInput(text) {
        if (text.indexOf(":") >= 0) return text.substring(0, 5)
        let digits = text.replace(/[^\d]/g, "").substring(0, 4)
        if (digits.length === 0) return ""
        if (digits.length <= 2) return digits
        return digits.substring(0, 2) + ":" + digits.substring(2)
    }

    function submitEvent() {
        let title = formTitle.trim()
        if (!title) return
        let t = ""
        if (!formAllDay) {
            let raw = formTime.trim()
            if (isValidTime(raw)) t = raw
        }
        addEvent(selectedDate, title, t)
        formTitle = ""
        formTime = ""
        if (timeInput) timeInput.text = ""
    }

    property real gridOpacity: 1.0
    property real gridShift: 0

    property real selectedHeaderOpacity: 1.0
    property real selectedHeaderShift: 0

    SequentialAnimation {
        id: selectedFlip
        NumberAnimation { target: root; property: "selectedHeaderOpacity"; to: 0.0; duration: 120; easing.type: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: root; property: "selectedHeaderShift"; from: -6; to: 0; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "selectedHeaderOpacity"; to: 1.0; duration: 260; easing.type: Easing.OutCubic }
        }
    }

    onSelectedDateChanged: selectedFlip.restart()

    SequentialAnimation {
        id: monthFlip
        property int targetMonth: 0
        property int targetYear: 0
        property real shiftDir: 0

        ParallelAnimation {
            NumberAnimation { target: root; property: "gridOpacity"; to: 0.0; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "gridShift"; to: monthFlip.shiftDir * -18; duration: 160; easing.type: Easing.OutCubic }
        }
        ScriptAction {
            script: {
                root.currentMonth = monthFlip.targetMonth
                root.currentYear = monthFlip.targetYear
                root.gridShift = monthFlip.shiftDir * 18
            }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "gridOpacity"; to: 1.0; duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "gridShift"; to: 0; duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
        }
    }

    function changeMonth(delta) {
        let m = currentMonth + delta
        let y = currentYear
        while (m < 1) { m += 12; y-- }
        while (m > 12) { m -= 12; y++ }
        if (monthFlip.running) monthFlip.stop()
        monthFlip.targetMonth = m
        monthFlip.targetYear = y
        monthFlip.shiftDir = delta >= 0 ? 1 : -1
        monthFlip.start()
    }

    function jumpToToday() {
        let delta = (todayYear - currentYear) * 12 + (todayMonth - currentMonth)
        if (delta === 0) return
        if (monthFlip.running) monthFlip.stop()
        monthFlip.targetMonth = todayMonth
        monthFlip.targetYear = todayYear
        monthFlip.shiftDir = delta >= 0 ? 1 : -1
        monthFlip.start()
        selectedDate = dateKey(todayYear, todayMonth, todayDay)
    }

    function formatSelectedDate(key) {
        if (!key) return ""
        let parts = key.split("-")
        if (parts.length !== 3) return key
        let monthName = monthNames[parseInt(parts[1]) - 1] || parts[1]
        return monthName + " " + parseInt(parts[2]) + ", " + parts[0]
    }

    onCurrentYearChanged: reloadEvents()
    onCurrentMonthChanged: reloadEvents()

    Process {
        id: loadEventsProcess
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => { loadEventsProcess.output += data }
        }

        onExited: () => {
            try {
                let parsed = JSON.parse(loadEventsProcess.output || "{}")
                root.events = Array.isArray(parsed.events) ? parsed.events : []
                root.rebuildIndex()
            } catch (e) {
            }
            loadEventsProcess.output = ""
        }
    }

    Process {
        id: addEventProcess
        running: false
        onExited: () => root.reloadEvents()
    }

    Process {
        id: deleteEventProcess
        running: false
        onExited: () => root.reloadEvents()
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        color: Qt.rgba(0.04, 0.03, 0.08, 0.92)
        radius: 0
        border.width: 0

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                Qt.quit()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Left || event.key === Qt.Key_PageUp) {
                root.changeMonth(-1)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Right || event.key === Qt.Key_PageDown) {
                root.changeMonth(1)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Home) {
                root.jumpToToday()
                event.accepted = true
                return
            }
        }

        focus: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.30, 0.15, 0.45, 0.40) }
                GradientStop { position: 0.55; color: Qt.rgba(0.15, 0.08, 0.30, 0.20) }
                GradientStop { position: 1.0; color: Qt.rgba(0.05, 0.03, 0.12, 0.0) }
            }
        }

        Canvas {
            id: starField
            anchors.fill: parent
            antialiasing: true

            property var stars: []
            property real twinkleTime: 0

            function regenerate() {
                const list = []
                const count = 70
                const ceiling = height * 0.35
                for (let i = 0; i < count; i++) {
                    list.push({
                        x: Math.random() * width,
                        y: Math.random() * ceiling,
                        r: 0.4 + Math.random() * 1.4,
                        a: 0.18 + Math.random() * 0.55,
                        // ~35% of stars breathe at varied speeds
                        twinkle: Math.random() < 0.35,
                        phase: Math.random() * Math.PI * 2,
                        speed: 0.7 + Math.random() * 0.9
                    })
                }
                stars = list
                requestPaint()
            }

            Timer {
                interval: 80
                repeat: true
                running: true
                onTriggered: {
                    starField.twinkleTime += 0.18
                    starField.requestPaint()
                }
            }

            onWidthChanged: regenerate()
            onHeightChanged: regenerate()
            Component.onCompleted: regenerate()

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                for (let i = 0; i < stars.length; i++) {
                    const s = stars[i]
                    let alpha = s.a
                    let radius = s.r
                    if (s.twinkle) {
                        const phase = Math.sin(twinkleTime * s.speed + s.phase)
                        // Alpha breathes 0.4 → 1.0 of base for a subtle shimmer
                        const m = 0.7 + 0.3 * phase
                        alpha = s.a * m
                        // Tiny size pulse only on bright peaks
                        radius = s.r * (1 + 0.2 * Math.max(0, phase))
                    }
                    ctx.beginPath()
                    ctx.arc(s.x, s.y, radius, 0, Math.PI * 2)
                    ctx.fillStyle = "rgba(245, 240, 255, " + alpha + ")"
                    ctx.fill()
                }
            }
        }

        Item {
            id: moonContainer
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 32
            anchors.topMargin: 28
            width: 36
            height: 36
            transformOrigin: Item.Center

            property real bobY: 0

            SequentialAnimation on rotation {
                loops: Animation.Infinite
                running: true
                NumberAnimation { from: -55; to: 5; duration: 2800; easing.type: Easing.InOutSine }
                NumberAnimation { from: 5; to: -55; duration: 2800; easing.type: Easing.InOutSine }
            }

            SequentialAnimation on bobY {
                loops: Animation.Infinite
                running: true
                NumberAnimation { from: -6; to: 6; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { from: 6; to: -6; duration: 1800; easing.type: Easing.InOutSine }
            }

            transform: Translate { y: moonContainer.bobY }

            Common.GlowSvgIcon {
                id: moonIcon
                anchors.fill: parent
                source: Quickshell.shellDir + "/assets/icons/moon.svg"
                color: theme
                    ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.85)
                    : Qt.rgba(0.95, 0.93, 0.98, 0.85)

                enableGlow: true
                glowColor: theme
                    ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.45)
                    : Qt.rgba(0.65, 0.55, 0.85, 0.45)
                glowSamples: 24
                glowRadius: 12
                glowSpread: 0.4
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 20

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 480
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Item {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26

                        Common.GlowSvgIcon {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: Quickshell.shellDir + "/assets/icons/chevron-left.svg"
                            color: prevHover.containsMouse
                                ? (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                                : (theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85))
                            opacity: prevHover.containsMouse ? 1.0 : 0.65

                            enableGlow: prevHover.containsMouse
                            glowColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5)
                            glowSamples: 16
                            glowRadius: 8
                            glowSpread: 0.4

                            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                            Behavior on opacity { NumberAnimation { duration: Theme.Motion.micro } }
                        }

                        MouseArea {
                            id: prevHover
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.changeMonth(-1)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.monthNames[root.currentMonth - 1] + " " + root.currentYear
                        color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                        font.pixelSize: 30
                        font.weight: Font.Light
                        font.italic: true
                        font.family: "M PLUS 2"
                        font.letterSpacing: 1
                        opacity: root.gridOpacity
                        transform: Translate { x: root.gridShift }
                    }

                    Item {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26

                        Common.GlowSvgIcon {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: Quickshell.shellDir + "/assets/icons/chevron-right.svg"
                            color: nextHover.containsMouse
                                ? (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                                : (theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85))
                            opacity: nextHover.containsMouse ? 1.0 : 0.65

                            enableGlow: nextHover.containsMouse
                            glowColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5)
                            glowSamples: 16
                            glowRadius: 8
                            glowSpread: 0.4

                            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                            Behavior on opacity { NumberAnimation { duration: Theme.Motion.micro } }
                        }

                        MouseArea {
                            id: nextHover
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.changeMonth(1)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                        delegate: Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: {
                                    if (index === 0) return Qt.hsla(0.0, 0.20, 0.72, 1.0)
                                    if (index === 6) return Qt.hsla(0.6, 0.20, 0.72, 1.0)
                                    return theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.9)
                                }
                                font.pixelSize: 11
                                font.family: "M PLUS 2"
                                font.weight: Font.Light
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: theme ? theme.textPrimary : Qt.rgba(1, 1, 1, 1)
                    opacity: 0.08
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    opacity: root.gridOpacity
                    transform: Translate { x: root.gridShift }
                    columns: 7
                    rowSpacing: 4
                    columnSpacing: 0

                    Repeater {
                        model: 42

                        delegate: Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46

                            property int dayNumber: {
                                const firstDay = new Date(root.currentYear, root.currentMonth - 1, 1)
                                const startOffset = firstDay.getDay()
                                const dayIndex = index - startOffset + 1
                                const lastDay = new Date(root.currentYear, root.currentMonth, 0).getDate()
                                if (dayIndex > 0 && dayIndex <= lastDay) return dayIndex
                                if (dayIndex <= 0) {
                                    const prevMonthLastDay = new Date(root.currentYear, root.currentMonth - 1, 0).getDate()
                                    return prevMonthLastDay + dayIndex
                                }
                                return dayIndex - lastDay
                            }

                            property bool isCurrentMonth: {
                                const firstDay = new Date(root.currentYear, root.currentMonth - 1, 1)
                                const startOffset = firstDay.getDay()
                                const dayIndex = index - startOffset + 1
                                const lastDay = new Date(root.currentYear, root.currentMonth, 0).getDate()
                                return dayIndex > 0 && dayIndex <= lastDay
                            }

                            property bool isToday: isCurrentMonth
                                && dayNumber === root.todayDay
                                && root.currentMonth === root.todayMonth
                                && root.currentYear === root.todayYear

                            property string cellDateKey: isCurrentMonth ? root.dateKey(root.currentYear, root.currentMonth, dayNumber) : ""
                            property bool isSelected: cellDateKey === root.selectedDate
                            property bool hasEvents: cellDateKey ? root.eventsForDate(cellDateKey).length > 0 : false

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                width: 28
                                height: 28
                                radius: 14
                                color: cellHover.containsMouse && !isToday && !isSelected
                                    ? Qt.rgba(1, 1, 1, 0.06)
                                    : "transparent"
                                border.width: isToday ? 1.4 : (isSelected ? 1 : 0)
                                border.color: isToday
                                    ? (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                                    : Qt.rgba(0.75, 0.75, 0.8, 0.5)

                                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                                Behavior on border.color { ColorAnimation { duration: Theme.Motion.micro } }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 4 + 14 - implicitHeight / 2
                                text: dayNumber > 0 ? dayNumber : ""
                                color: {
                                    if (isToday) return Qt.rgba(0.98, 0.98, 1.0, 1.0)
                                    return theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.85)
                                }
                                opacity: isCurrentMonth ? 1.0 : 0.45
                                font.pixelSize: 13
                                font.weight: isToday || isSelected ? Font.Medium : Font.Light
                                font.family: "M PLUS 2"
                            }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.topMargin: 38
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 4
                                height: 4
                                radius: 2
                                color: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
                                visible: hasEvents && isCurrentMonth
                                opacity: 0.8
                            }

                            MouseArea {
                                id: cellHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: dayNumber > 0 && isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: dayNumber > 0 && isCurrentMonth
                                onClicked: {
                                    root.selectedDate = cellDateKey
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 8
                    color: theme ? theme.textPrimary : Qt.rgba(1, 1, 1, 1)
                    opacity: 0.08
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const y = root.currentYear
                            const m = root.currentMonth
                            const prefix = y + "-" + (m < 10 ? "0" : "") + m + "-"
                            let count = 0
                            for (let key in root.eventsByDate) {
                                if (key.indexOf(prefix) === 0) count += root.eventsByDate[key].length
                            }
                            return count + " event" + (count === 1 ? "" : "s") + " this month"
                        }
                        color: theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.55)
                        font.pixelSize: 11
                        font.family: "M PLUS 2"
                        font.letterSpacing: 0.3
                    }

                    Text {
                        id: floatingTodayLabel
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(new Date(), "ddd, MMM d, yyyy")
                        color: floatingTodayHover.containsMouse
                            ? (theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95))
                            : (theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.55))
                        font.pixelSize: 11
                        font.family: "M PLUS 2"
                        font.letterSpacing: 0.3

                        Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                    }

                    MouseArea {
                        id: floatingTodayHover
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: floatingTodayLabel.implicitWidth + 8
                        height: floatingTodayLabel.implicitHeight + 8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.jumpToToday()
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme ? theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.1)
                opacity: 0.3
            }

            ColumnLayout {
                Layout.preferredWidth: 280
                Layout.fillHeight: true
                spacing: 12

                Text {
                    text: root.formatSelectedDate(root.selectedDate)
                    color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    font.family: "M PLUS 2"
                    Layout.alignment: Qt.AlignHCenter
                    opacity: root.selectedHeaderOpacity
                    transform: Translate { y: root.selectedHeaderShift }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: eventsColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 4
                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                        }
                    }

                    Column {
                        id: eventsColumn
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: root.modalEvents

                            delegate: Rectangle {
                                id: eventRow
                                width: parent.width
                                height: 40
                                radius: 10
                                color: rowHover.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.025)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, rowHover.containsMouse ? 0.10 : 0.05)

                                opacity: 0
                                property real entryShift: -8
                                transform: Translate { y: eventRow.entryShift }

                                Component.onCompleted: entryAnim.start()

                                ParallelAnimation {
                                    id: entryAnim
                                    NumberAnimation { target: eventRow; property: "opacity"; from: 0; to: 1; duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: eventRow; property: "entryShift"; from: -8; to: 0; duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
                                }

                                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                                Behavior on border.color { ColorAnimation { duration: Theme.Motion.micro } }

                                MouseArea {
                                    id: rowHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 6
                                    spacing: 10

                                    Text {
                                        text: modelData.time || "All day"
                                        Layout.preferredWidth: 56
                                        color: modelData.time
                                            ? (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                                            : (theme ? theme.textFaint : Qt.rgba(0.55, 0.55, 0.6, 1))
                                        font.pixelSize: 12
                                        font.weight: modelData.time ? Font.Medium : Font.Light
                                        font.italic: !modelData.time
                                        font.family: "M PLUS 2"
                                        font.letterSpacing: 0.4
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 1
                                        Layout.preferredHeight: 18
                                        color: Qt.rgba(1, 1, 1, 0.10)
                                    }

                                    Text {
                                        text: modelData.title
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 2
                                        color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                                        font.pixelSize: 13
                                        font.family: "M PLUS 2"
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Item {
                                        Layout.preferredWidth: 28
                                        Layout.fillHeight: true

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            color: deleteHover.containsMouse
                                                ? Qt.rgba(1, 0.5, 0.55, 1)
                                                : (theme ? theme.textFaint : Qt.rgba(0.55, 0.55, 0.6, 1))
                                            opacity: deleteHover.containsMouse ? 1 : 0.55
                                            font.pixelSize: 12

                                            Behavior on opacity { NumberAnimation { duration: Theme.Motion.micro } }
                                        }

                                        MouseArea {
                                            id: deleteHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.deleteEvent(modelData.id)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.modalEvents.length === 0
                            text: "Nothing scheduled"
                            color: theme ? theme.textFaint : Qt.rgba(0.55, 0.55, 0.6, 1)
                            font.pixelSize: 12
                            font.family: "M PLUS 2"
                            font.italic: true
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: theme ? theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.1)
                    opacity: 0.3
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    color: titleInput.activeFocus
                        ? Qt.rgba(1, 1, 1, 0.04)
                        : Qt.rgba(1, 1, 1, 0.02)
                    border.width: 1
                    border.color: titleInput.activeFocus
                        ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                        : Qt.rgba(1, 1, 1, 0.10)
                    radius: 10

                    Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

                    TextInput {
                        id: titleInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        text: root.formTitle
                        onTextChanged: root.formTitle = text
                        color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                        selectionColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                        font.pixelSize: 13
                        font.family: "M PLUS 2"
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Title"
                            visible: !titleInput.text
                            color: theme ? theme.textFaint : Qt.rgba(0.5, 0.5, 0.55, 1)
                            font.pixelSize: 13
                            font.italic: true
                            font.family: "M PLUS 2"
                        }

                        Keys.onReturnPressed: root.submitEvent()
                        Keys.onEnterPressed: root.submitEvent()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 78
                        Layout.preferredHeight: 38
                        color: timeInput.activeFocus
                            ? Qt.rgba(1, 1, 1, 0.04)
                            : Qt.rgba(1, 1, 1, 0.02)
                        border.width: 1
                        border.color: root.isTimeFieldInvalid
                            ? Qt.rgba(1, 0.5, 0.55, 1)
                            : timeInput.activeFocus
                                ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                                : Qt.rgba(1, 1, 1, 0.10)
                        radius: 10
                        opacity: root.formAllDay ? 0.4 : 1

                        Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }
                        Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }

                        TextInput {
                            id: timeInput
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            enabled: !root.formAllDay
                            text: root.formTime
                            color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                            selectionColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                            font.pixelSize: 13
                            font.family: "M PLUS 2"
                            verticalAlignment: TextInput.AlignVCenter
                            maximumLength: 5

                            property bool _formatting: false

                            onTextChanged: {
                                if (_formatting) return
                                let formatted = root.formatTimeInput(text)
                                if (formatted !== text) {
                                    _formatting = true
                                    text = formatted
                                    cursorPosition = text.length
                                    _formatting = false
                                }
                                root.formTime = text
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "HH:MM"
                                visible: !timeInput.text
                                color: theme ? theme.textFaint : Qt.rgba(0.5, 0.5, 0.55, 1)
                                font.pixelSize: 13
                                font.italic: true
                                font.family: "M PLUS 2"
                            }

                            Keys.onReturnPressed: root.submitEvent()
                            Keys.onEnterPressed: root.submitEvent()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 38
                        color: root.formAllDay
                            ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.22) : Qt.rgba(0.65, 0.55, 0.85, 0.22))
                            : (allDayHover.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.02))
                        border.width: 1
                        border.color: root.formAllDay
                            ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55))
                            : Qt.rgba(1, 1, 1, 0.10)
                        radius: 10

                        Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

                        Text {
                            anchors.centerIn: parent
                            text: "All day"
                            color: root.formAllDay
                                ? (theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.95))
                                : (theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85))
                            font.pixelSize: 11
                            font.weight: root.formAllDay ? Font.Medium : Font.Light
                            font.family: "M PLUS 2"
                            font.letterSpacing: 0.5

                            Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }
                        }

                        MouseArea {
                            id: allDayHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.formAllDay = !root.formAllDay
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 38
                        radius: 10
                        color: theme
                            ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, addHover.containsMouse ? 0.42 : 0.30)
                            : Qt.rgba(0.65, 0.55, 0.85, addHover.containsMouse ? 0.42 : 0.30)
                        border.width: 0

                        Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                        Text {
                            anchors.centerIn: parent
                            text: "Add"
                            color: theme ? theme.textPrimary : Qt.rgba(0.95, 0.95, 1.0, 0.95)
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            font.family: "M PLUS 2"
                            font.letterSpacing: 0.5
                        }

                        MouseArea {
                            id: addHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.submitEvent()
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        reloadEvents()
    }
}
