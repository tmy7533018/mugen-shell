import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var modeManager
    property var theme

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(520),
        "leftMargin": modeManager.scale(650),
        "rightMargin": modeManager.scale(650),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })

    property var events: []
    property var eventsByDate: ({})

    property bool modalOpen: false
    property string modalDate: ""
    property string formTitle: ""
    property string formTime: ""
    property bool formAllDay: false
    property var modalEvents: (modalDate && eventsByDate[modalDate]) ? eventsByDate[modalDate] : []

    function openEventModal(key) {
        modalDate = key
        formTitle = ""
        formTime = ""
        formAllDay = false
        if (timeInput) timeInput.text = ""
        modalOpen = true
    }

    function closeEventModal() {
        cancelEdit()
        modalOpen = false
    }

    function formatTimeInput(text) {
        if (text.indexOf(":") >= 0) return text.substring(0, 5)
        let digits = text.replace(/[^\d]/g, "").substring(0, 4)
        if (digits.length === 0) return ""
        if (digits.length <= 2) return digits
        return digits.substring(0, 2) + ":" + digits.substring(2)
    }

    function isValidTime(t) {
        return /^([01]?\d|2[0-3]):[0-5]\d$/.test(t)
    }

    readonly property bool isTimeFieldInvalid: {
        let t = formTime
        if (!t) return false
        if (t.length < 5) return false
        return !isValidTime(t)
    }

    function submitEvent() {
        let title = formTitle.trim()
        if (!title) return
        let t = ""
        if (!formAllDay) {
            let raw = formTime.trim()
            if (isValidTime(raw)) t = raw
        }
        addEvent(modalDate, title, t)
        formTitle = ""
        formTime = ""
        if (timeInput) timeInput.text = ""
    }

    function formatModalDate(key) {
        if (!key) return ""
        let parts = key.split("-")
        if (parts.length !== 3) return key
        let names = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        let monthName = names[parseInt(parts[1]) - 1] || parts[1]
        return monthName + " " + parseInt(parts[2]) + ", " + parts[0]
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
        let r = rangeForMonth(monthHeader.currentYear, monthHeader.currentMonth)
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

    property string editingId: ""
    property string editTitle: ""
    property string editTime: ""

    readonly property bool isEditTimeFieldInvalid: {
        let t = editTime
        if (!t) return false
        if (t.length < 5) return false
        return !isValidTime(t)
    }

    function startEdit(event) {
        if (!event || !event.id) return
        editingId = event.id
        editTitle = event.title || ""
        editTime = event.time || ""
    }

    function cancelEdit() {
        editingId = ""
        editTitle = ""
        editTime = ""
    }

    function saveEdit() {
        if (!editingId) return
        let title = editTitle.trim()
        if (!title) return
        let t = editTime.trim()
        if (t && !isValidTime(t)) return
        updateEventProcess.command = [
            "python3", Quickshell.shellDir + "/scripts/calendar-cli.py",
            "update", "--id", editingId, "--title", title, "--time", t
        ]
        updateEventProcess.running = true
        editingId = ""
    }

    Process {
        id: loadEventsProcess
        running: false

        property string output: ""

        stdout: SplitParser {
            onRead: data => {
                loadEventsProcess.output += data
            }
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

    Process {
        id: updateEventProcess
        running: false
        onExited: () => root.reloadEvents()
    }

    MouseArea {
        anchors.fill: parent
        z: 1.5
        enabled: modeManager.isMode("calendar")
        visible: enabled
        hoverEnabled: true

        onClicked: {
            modeManager.closeAllModes()
        }

        onPositionChanged: {
            if (modeManager.isMode("calendar")) modeManager.bump()
        }
    }

    Item {
        id: calendarLayer
        anchors.fill: parent
        anchors.leftMargin: modeManager.scale(32)
        anchors.rightMargin: modeManager.scale(32)
        z: 2

        focus: modeManager.isMode("calendar")
        Keys.onPressed: (event) => {
            if (modeManager.isMode("calendar")) modeManager.bump()
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
            }
        }

        opacity: 0
        visible: opacity > 0.01

        states: [
            State {
                name: "visible"
                when: modeManager.isMode("calendar")
                PropertyChanges { target: calendarLayer; opacity: 1.0 }
            }
        ]

        transitions: [
            Transition {
                from: "visible"
                to: ""
                NumberAnimation {
                    property: "opacity"
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: 300 }
                    NumberAnimation {
                        property: "opacity"
                        duration: 400
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        ]

        ColumnLayout {
            anchors.centerIn: parent
            spacing: modeManager.scale(28)

            Text {
                id: detailedClock
                property string timeString: "--:--:--"

                text: timeString
                color: (theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.85))
                font.pixelSize: modeManager.scale(60)
                font.weight: Font.Light
                font.family: "M PLUS 2"
                Layout.alignment: Qt.AlignHCenter

                layer.enabled: true
                layer.effect: Glow {
                    samples: 20
                    radius: modeManager.scale(8)
                    spread: 0.4
                    color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5)
                    transparentBorder: true
                }

                Timer {
                    interval: 1000
                    repeat: true
                    running: modeManager.isMode("calendar")
                    onTriggered: {
                        const now = new Date();
                        let hh = now.getHours().toString().padStart(2, "0");
                        let mm = now.getMinutes().toString().padStart(2, "0");
                        let ss = now.getSeconds().toString().padStart(2, "0");
                        detailedClock.timeString = hh + ":" + mm + ":" + ss;
                    }
                }

                Component.onCompleted: {
                    const now = new Date();
                    let hh = now.getHours().toString().padStart(2, "0");
                    let mm = now.getMinutes().toString().padStart(2, "0");
                    let ss = now.getSeconds().toString().padStart(2, "0");
                    timeString = hh + ":" + mm + ":" + ss;
                }
            }

            Item {
                id: calendarWrapper
                Layout.preferredWidth: modeManager.scale(480)
                Layout.preferredHeight: modeManager.scale(360)
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                    id: calendarBackground
                    anchors.fill: parent
                    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
                    border.width: 0
                    radius: modeManager.scale(26)

                    layer.enabled: true
                    layer.effect: Glow {
                        samples: 24
                        radius: modeManager.scale(12)
                        spread: 0.5
                        color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.20) : Qt.rgba(0.65, 0.55, 0.85, 0.20)
                        transparentBorder: true
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: modeManager.scale(14)

                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: modeManager.scale(32)

                        Text {
                            text: "‹"
                            color: (theme ? theme.textSecondary : Qt.rgba(0.91, 0.91, 0.94, 0.70))
                            font.pixelSize: modeManager.scale(20)
                            font.weight: Font.Normal
                            font.family: "M PLUS 2"
                            opacity: prevMonthArea.containsMouse ? 1.0 : 0.7

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }
                            }

                            MouseArea {
                                id: prevMonthArea
                                anchors.fill: parent
                                anchors.margins: modeManager.scale(-12)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (monthHeader.currentMonth === 1) {
                                        monthHeader.currentMonth = 12
                                        monthHeader.currentYear--
                                    } else {
                                        monthHeader.currentMonth--
                                    }
                                    calendarGrid.updateCalendar()
                                }
                            }
                        }

                        Text {
                            id: monthHeader
                            property int currentYear: 2025
                            property int currentMonth: 1

                            text: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"][currentMonth - 1] + " " + currentYear
                            color: (theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.85))
                            font.pixelSize: modeManager.scale(18)
                            font.weight: Font.Medium
                            font.family: "M PLUS 2"

                            Component.onCompleted: {
                                const now = new Date();
                                currentYear = now.getFullYear();
                                currentMonth = now.getMonth() + 1;
                            }
                        }

                        Text {
                            text: "›"
                            color: (theme ? theme.textSecondary : Qt.rgba(0.91, 0.91, 0.94, 0.70))
                            font.pixelSize: modeManager.scale(20)
                            font.weight: Font.Normal
                            font.family: "M PLUS 2"
                            opacity: nextMonthArea.containsMouse ? 1.0 : 0.7

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }
                            }

                            MouseArea {
                                id: nextMonthArea
                                anchors.fill: parent
                                anchors.margins: modeManager.scale(-12)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (monthHeader.currentMonth === 12) {
                                        monthHeader.currentMonth = 1
                                        monthHeader.currentYear++
                                    } else {
                                        monthHeader.currentMonth++
                                    }
                                    calendarGrid.updateCalendar()
                                }
                            }
                        }
                    }

                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: modeManager.scale(16)

                        Repeater {
                            model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                            Text {
                                text: modelData
                                color: {
                                    if (index === 0) {
                                        return Qt.hsla(0.0, 0.20, 0.72, 1.0)
                                    }
                                    if (index === 6) {
                                        return Qt.hsla(0.6, 0.20, 0.72, 1.0)
                                    }
                                    return Qt.rgba(0.82, 0.82, 0.87, 1.0)
                                }
                                font.pixelSize: modeManager.scale(12)
                                font.weight: Font.Light
                                font.family: "M PLUS 2"
                                width: modeManager.scale(48)
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Grid {
                        id: calendarGrid
                        Layout.alignment: Qt.AlignHCenter
                        columns: 7
                        columnSpacing: modeManager.scale(16)
                        rowSpacing: modeManager.scale(11)

                        property int today: new Date().getDate()
                        property int todayMonth: new Date().getMonth() + 1
                        property int todayYear: new Date().getFullYear()
                        property string todayWeekday: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][new Date().getDay()]

                        property int selectedIndex: -1

                        function updateCalendar() {
                            // Force Repeater to regenerate by resetting model
                            calendarRepeater.model = 0
                            calendarRepeater.model = 42
                        }

                        Repeater {
                            id: calendarRepeater
                            model: 42

                            Item {
                                width: modeManager.scale(48)
                                height: modeManager.scale(32)

                                property int dayNumber: {
                                    const firstDay = new Date(monthHeader.currentYear, monthHeader.currentMonth - 1, 1);
                                    const startOffset = firstDay.getDay();
                                    const dayIndex = index - startOffset + 1;
                                    const lastDay = new Date(monthHeader.currentYear, monthHeader.currentMonth, 0).getDate();

                                    if (dayIndex > 0 && dayIndex <= lastDay) {
                                        return dayIndex;
                                    } else if (dayIndex <= 0) {
                                        const prevMonthLastDay = new Date(monthHeader.currentYear, monthHeader.currentMonth - 1, 0).getDate();
                                        return prevMonthLastDay + dayIndex;
                                    } else {
                                        return dayIndex - lastDay;
                                    }
                                }

                                property bool isCurrentMonth: {
                                    const firstDay = new Date(monthHeader.currentYear, monthHeader.currentMonth - 1, 1);
                                    const startOffset = firstDay.getDay();
                                    const dayIndex = index - startOffset + 1;
                                    const lastDay = new Date(monthHeader.currentYear, monthHeader.currentMonth, 0).getDate();
                                    return dayIndex > 0 && dayIndex <= lastDay;
                                }

                                property bool isToday: {
                                    return isCurrentMonth &&
                                           dayNumber === calendarGrid.today &&
                                           monthHeader.currentMonth === calendarGrid.todayMonth &&
                                           monthHeader.currentYear === calendarGrid.todayYear;
                                }

                                property bool isSelected: index === calendarGrid.selectedIndex

                                property string cellDateKey: isCurrentMonth ? root.dateKey(monthHeader.currentYear, monthHeader.currentMonth, dayNumber) : ""
                                property bool hasEvents: cellDateKey ? root.eventsForDate(cellDateKey).length > 0 : false

                                Item {
                                    anchors.centerIn: parent
                                    width: modeManager.scale(56)
                                    height: modeManager.scale(56)

                                    property bool shouldShow: isToday || isSelected
                                    opacity: shouldShow ? 1.0 : 0.0
                                    visible: opacity > 0.01

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 400
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Repeater {
                                        model: 4

                                        Rectangle {
                                            id: blob
                                            x: parent.width / 2 - width / 2
                                            y: parent.height / 2 - height / 2
                                            width: modeManager.scale(40 + index * 3)
                                            height: modeManager.scale(40 + index * 3)
                                            radius: modeManager.scale(40 + index * 3) / 2
                                            color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.12 - index * 0.025) : Qt.rgba(0.65, 0.55, 0.85, 0.12 - index * 0.025)
                                            border.width: 0

                                            property real randomAngle: Math.random() * Math.PI * 2
                                            property real randomDistance: modeManager.scale(2 + Math.random() * 4)
                                            property real randomDuration: 1200 + Math.random() * 1200

                                            property real floatX: 0
                                            property real floatY: 0

                                            SequentialAnimation on floatX {
                                                loops: Animation.Infinite
                                                running: parent.shouldShow

                                                PauseAnimation { duration: index * 300 }
                                                NumberAnimation {
                                                    to: Math.cos(blob.randomAngle) * blob.randomDistance
                                                    duration: blob.randomDuration
                                                    easing.type: Easing.InOutSine
                                                }
                                                NumberAnimation {
                                                    to: -Math.cos(blob.randomAngle) * blob.randomDistance
                                                    duration: blob.randomDuration
                                                    easing.type: Easing.InOutSine
                                                }
                                            }

                                            SequentialAnimation on floatY {
                                                loops: Animation.Infinite
                                                running: parent.shouldShow

                                                PauseAnimation { duration: index * 500 }
                                                NumberAnimation {
                                                    to: Math.sin(blob.randomAngle) * blob.randomDistance
                                                    duration: blob.randomDuration * 1.1
                                                    easing.type: Easing.InOutSine
                                                }
                                                NumberAnimation {
                                                    to: -Math.sin(blob.randomAngle) * blob.randomDistance
                                                    duration: blob.randomDuration * 1.1
                                                    easing.type: Easing.InOutSine
                                                }
                                            }

                                            SequentialAnimation on scale {
                                                loops: Animation.Infinite
                                                running: parent.shouldShow

                                                PauseAnimation { duration: index * 250 }
                                                NumberAnimation {
                                                    to: 1.03 + index * 0.01
                                                    duration: 1400 + index * 300
                                                    easing.type: Easing.InOutSine
                                                }
                                                NumberAnimation {
                                                    to: 0.97
                                                    duration: 1400 + index * 300
                                                    easing.type: Easing.InOutSine
                                                }
                                            }

                                            SequentialAnimation on opacity {
                                                loops: Animation.Infinite
                                                running: parent.shouldShow

                                                PauseAnimation { duration: index * 400 }
                                                NumberAnimation {
                                                    to: 0.8 - index * 0.15
                                                    duration: 1800 + index * 200
                                                    easing.type: Easing.InOutSine
                                                }
                                                NumberAnimation {
                                                    to: 0.5 - index * 0.1
                                                    duration: 1800 + index * 200
                                                    easing.type: Easing.InOutSine
                                                }
                                            }

                                            layer.enabled: true
                                            layer.effect: Glow {
                                                samples: 24 + index * 4
                                                radius: modeManager.scale(16 + index * 4)
                                                spread: 0.7 - index * 0.1
                                                color: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1.0)
                                                transparentBorder: true
                                            }

                                            transform: Translate {
                                                x: blob.floatX
                                                y: blob.floatY
                                            }
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: dayNumber
                                    visible: dayNumber > 0
                                    color: {
                                        if (isToday || isSelected) {
                                            return Qt.rgba(0.98, 0.98, 1.0, 1.0)
                                        }
                                        return (theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.85))
                                    }
                                    opacity: isCurrentMonth ? 1.0 : 0.30
                                    font.pixelSize: modeManager.scale(15)
                                    font.weight: isToday || isSelected ? Font.Normal : Font.Light
                                    font.family: "M PLUS 2"

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 300
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Behavior on font.weight {
                                        NumberAnimation {
                                            duration: 300
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    layer.enabled: isToday || isSelected
                                    layer.effect: Glow {
                                        samples: 16
                                        radius: modeManager.scale(8)
                                        spread: 0.4
                                        color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5)
                                        transparentBorder: true
                                    }
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: -modeManager.scale(2)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: modeManager.scale(4)
                                    height: modeManager.scale(4)
                                    radius: modeManager.scale(2)
                                    color: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1.0)
                                    visible: hasEvents && isCurrentMonth
                                    opacity: 0.85
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: dayNumber > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    enabled: dayNumber > 0 && isCurrentMonth
                                    onClicked: {
                                        calendarGrid.selectedIndex = index
                                        root.openEventModal(cellDateKey)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: eventModal
        parent: calendarWrapper
        anchors.fill: parent
        z: 10
        visible: opacity > 0.01
        opacity: root.modalOpen ? 1 : 0
        focus: root.modalOpen

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                if (root.editingId) {
                    root.cancelEdit()
                } else {
                    root.closeEventModal()
                }
                event.accepted = true
            }
        }

        Rectangle {
            id: modalDimBg
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.25)
            radius: modeManager.scale(26)

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeEventModal()
            }
        }

        Rectangle {
            id: modalPanel
            anchors.centerIn: parent
            width: modeManager.scale(360)
            height: modalContent.implicitHeight + modeManager.scale(36)
            color: Qt.rgba(0.05, 0.05, 0.08, 0.92)
            radius: modeManager.scale(18)
            border.width: 1
            border.color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25)

            layer.enabled: true
            layer.effect: Glow {
                samples: 28
                radius: modeManager.scale(16)
                spread: 0.4
                color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.30) : Qt.rgba(0.65, 0.55, 0.85, 0.30)
                transparentBorder: true
            }

            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                id: modalContent
                anchors.fill: parent
                anchors.margins: modeManager.scale(18)
                spacing: modeManager.scale(12)

                Text {
                    text: root.formatModalDate(root.modalDate)
                    color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                    font.pixelSize: modeManager.scale(16)
                    font.weight: Font.Medium
                    font.family: "M PLUS 2"
                    Layout.alignment: Qt.AlignHCenter

                    layer.enabled: true
                    layer.effect: Glow {
                        samples: 16
                        radius: modeManager.scale(6)
                        spread: 0.3
                        color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                        transparentBorder: true
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: modeManager.scale(6)

                    Repeater {
                        model: root.modalEvents
                        delegate: Item {
                            id: eventRow
                            width: parent.width
                            height: modeManager.scale(28)

                            property bool isEditing: root.editingId === modelData.id

                            MouseArea {
                                id: rowClickArea
                                anchors.fill: parent
                                cursorShape: eventRow.isEditing ? Qt.ArrowCursor : Qt.PointingHandCursor
                                enabled: !eventRow.isEditing
                                onClicked: root.startEdit(modelData)
                            }

                            RowLayout {
                                anchors.fill: parent
                                spacing: modeManager.scale(10)
                                visible: !eventRow.isEditing

                                Text {
                                    text: modelData.time || "All day"
                                    Layout.preferredWidth: modeManager.scale(60)
                                    Layout.fillHeight: true
                                    color: modelData.time ? (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)) : (theme ? theme.textFaint : Qt.rgba(0.55, 0.55, 0.6, 1))
                                    font.pixelSize: modeManager.scale(12)
                                    font.weight: modelData.time ? Font.Medium : Font.Light
                                    font.italic: !modelData.time
                                    font.family: "M PLUS 2"
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: modelData.title
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                                    font.pixelSize: modeManager.scale(13)
                                    font.family: "M PLUS 2"
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Item {
                                    Layout.preferredWidth: modeManager.scale(20)
                                    Layout.fillHeight: true

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        color: deleteHover.containsMouse ? Qt.rgba(1, 0.5, 0.55, 1) : (theme ? theme.textFaint : Qt.rgba(0.55, 0.55, 0.6, 1))
                                        opacity: deleteHover.containsMouse ? 1 : 0.6
                                        font.pixelSize: modeManager.scale(12)

                                        Behavior on opacity { NumberAnimation { duration: 150 } }
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

                            RowLayout {
                                anchors.fill: parent
                                spacing: modeManager.scale(6)
                                visible: eventRow.isEditing

                                Rectangle {
                                    Layout.preferredWidth: modeManager.scale(60)
                                    Layout.preferredHeight: modeManager.scale(26)
                                    color: "transparent"
                                    border.width: 1
                                    border.color: root.isEditTimeFieldInvalid
                                        ? Qt.rgba(1, 0.5, 0.55, 1)
                                        : editTimeInput.activeFocus
                                            ? (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                                            : (theme ? theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18))
                                    radius: modeManager.scale(6)

                                    Behavior on border.color { ColorAnimation { duration: 200 } }

                                    TextInput {
                                        id: editTimeInput
                                        anchors.fill: parent
                                        anchors.leftMargin: modeManager.scale(6)
                                        anchors.rightMargin: modeManager.scale(6)
                                        text: root.editTime
                                        color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                                        selectionColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                                        font.pixelSize: modeManager.scale(12)
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
                                            root.editTime = text
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "All day"
                                            visible: !editTimeInput.text
                                            color: theme ? theme.textFaint : Qt.rgba(0.5, 0.5, 0.55, 1)
                                            font.pixelSize: modeManager.scale(11)
                                            font.italic: true
                                            font.family: "M PLUS 2"
                                        }

                                        Keys.onReturnPressed: root.saveEdit()
                                        Keys.onEnterPressed: root.saveEdit()
                                        Keys.onEscapePressed: root.cancelEdit()
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: modeManager.scale(26)
                                    color: "transparent"
                                    border.width: 1
                                    border.color: editTitleInput.activeFocus
                                        ? (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                                        : (theme ? theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18))
                                    radius: modeManager.scale(6)

                                    Behavior on border.color { ColorAnimation { duration: 200 } }

                                    TextInput {
                                        id: editTitleInput
                                        anchors.fill: parent
                                        anchors.leftMargin: modeManager.scale(8)
                                        anchors.rightMargin: modeManager.scale(8)
                                        text: root.editTitle
                                        onTextChanged: root.editTitle = text
                                        color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                                        selectionColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                                        font.pixelSize: modeManager.scale(12)
                                        font.family: "M PLUS 2"
                                        verticalAlignment: TextInput.AlignVCenter
                                        clip: true

                                        focus: eventRow.isEditing
                                        onFocusChanged: {
                                            if (focus && eventRow.isEditing) {
                                                selectAll()
                                            }
                                        }

                                        Keys.onReturnPressed: root.saveEdit()
                                        Keys.onEnterPressed: root.saveEdit()
                                        Keys.onEscapePressed: root.cancelEdit()
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: modeManager.scale(20)
                                    Layout.fillHeight: true

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: saveHover.containsMouse ? (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)) : (theme ? theme.textSecondary : Qt.rgba(0.75, 0.75, 0.82, 0.9))
                                        opacity: saveHover.containsMouse ? 1 : 0.85
                                        font.pixelSize: modeManager.scale(14)
                                        font.weight: Font.Medium

                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        id: saveHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.saveEdit()
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: modeManager.scale(20)
                                    Layout.fillHeight: true

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        color: editDeleteHover.containsMouse ? Qt.rgba(1, 0.5, 0.55, 1) : (theme ? theme.textFaint : Qt.rgba(0.55, 0.55, 0.6, 1))
                                        opacity: editDeleteHover.containsMouse ? 1 : 0.6
                                        font.pixelSize: modeManager.scale(12)

                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        id: editDeleteHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            let id = root.editingId
                                            root.cancelEdit()
                                            root.deleteEvent(id)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.modalEvents.length === 0
                        text: "Nothing scheduled"
                        color: theme ? theme.textFaint : Qt.rgba(0.55, 0.55, 0.6, 1)
                        font.pixelSize: modeManager.scale(12)
                        font.family: "M PLUS 2"
                        font.italic: true
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: theme ? theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.12)
                    opacity: 0.4
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: modeManager.scale(8)

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: modeManager.scale(30)
                        color: "transparent"
                        border.width: 1
                        border.color: titleInput.activeFocus
                            ? (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                            : (theme ? theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18))
                        radius: modeManager.scale(8)

                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        TextInput {
                            id: titleInput
                            anchors.fill: parent
                            anchors.leftMargin: modeManager.scale(10)
                            anchors.rightMargin: modeManager.scale(10)
                            text: root.formTitle
                            onTextChanged: root.formTitle = text
                            color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                            selectionColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                            font.pixelSize: modeManager.scale(13)
                            font.family: "M PLUS 2"
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Title"
                                visible: !titleInput.text
                                color: theme ? theme.textFaint : Qt.rgba(0.5, 0.5, 0.55, 1)
                                font.pixelSize: modeManager.scale(13)
                                font.family: "M PLUS 2"
                            }

                            Keys.onReturnPressed: root.submitEvent()
                            Keys.onEnterPressed: root.submitEvent()
                        }
                    }

                    Item {
                        Layout.preferredWidth: modeManager.scale(54)
                        Layout.preferredHeight: modeManager.scale(30)

                        Text {
                            id: addText
                            anchors.centerIn: parent
                            text: "Add"
                            color: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
                            opacity: addHover.containsMouse ? 1 : 0.85
                            font.pixelSize: modeManager.scale(14)
                            font.weight: Font.Medium
                            font.family: "M PLUS 2"
                            font.letterSpacing: 0.5

                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            layer.enabled: addHover.containsMouse
                            layer.effect: Glow {
                                samples: 12
                                radius: modeManager.scale(4)
                                spread: 0.2
                                color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6)
                                transparentBorder: true
                            }
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: modeManager.scale(8)

                    Rectangle {
                        Layout.preferredWidth: modeManager.scale(72)
                        Layout.preferredHeight: modeManager.scale(30)
                        color: "transparent"
                        border.width: 1
                        border.color: root.isTimeFieldInvalid
                            ? Qt.rgba(1, 0.5, 0.55, 1)
                            : timeInput.activeFocus
                                ? (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                                : (theme ? theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18))
                        radius: modeManager.scale(8)
                        opacity: root.formAllDay ? 0.4 : 1

                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        TextInput {
                            id: timeInput
                            anchors.fill: parent
                            anchors.leftMargin: modeManager.scale(10)
                            anchors.rightMargin: modeManager.scale(10)
                            enabled: !root.formAllDay
                            text: root.formTime
                            color: theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                            selectionColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                            font.pixelSize: modeManager.scale(13)
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
                                font.pixelSize: modeManager.scale(13)
                                font.family: "M PLUS 2"
                            }

                            Keys.onReturnPressed: root.submitEvent()
                            Keys.onEnterPressed: root.submitEvent()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: modeManager.scale(76)
                        Layout.preferredHeight: modeManager.scale(30)
                        color: root.formAllDay
                            ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.22) : Qt.rgba(0.65, 0.55, 0.85, 0.22))
                            : "transparent"
                        border.width: 1
                        border.color: root.formAllDay
                            ? (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                            : (theme ? theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18))
                        radius: modeManager.scale(8)

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Text {
                            anchors.centerIn: parent
                            text: "All day"
                            color: root.formAllDay
                                ? (theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.95))
                                : (theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85))
                            font.pixelSize: modeManager.scale(11)
                            font.weight: root.formAllDay ? Font.Medium : Font.Light
                            font.family: "M PLUS 2"
                            font.letterSpacing: 0.5

                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.formAllDay = !root.formAllDay
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }
        }

        onOpacityChanged: {
            if (opacity > 0.5 && titleInput) {
                titleInput.forceActiveFocus()
            }
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("calendar")) {
                root.reloadEvents()
            } else {
                root.modalOpen = false
            }
        }
    }

    Connections {
        target: monthHeader
        function onCurrentMonthChanged() { root.reloadEvents() }
        function onCurrentYearChanged() { root.reloadEvents() }
    }

    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("calendar", root)
        }
        root.reloadEvents()
    }
}
