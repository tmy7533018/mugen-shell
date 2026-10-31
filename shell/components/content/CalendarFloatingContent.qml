import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../common" as Common
import "../../lib" as Theme
import "./calendar" as Cal

Item {
    id: root

    property var theme
    property var settingsManager

    readonly property int weekStart: settingsManager ? settingsManager.calendarWeekStart : 0
    readonly property bool reduceMotion: settingsManager ? settingsManager.reduceMotion : false
    readonly property var weekdayLabels: {
        const names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let rotated = []
        for (let i = 0; i < 7; i++) rotated.push(names[(i + root.weekStart) % 7])
        return rotated
    }

    property int currentYear: new Date().getFullYear()
    property int currentMonth: new Date().getMonth() + 1

    // A binding reads new Date() once, and the window can stay open past midnight.
    property date today: new Date()
    readonly property int todayDay: today.getDate()
    readonly property int todayMonth: today.getMonth() + 1
    readonly property int todayYear: today.getFullYear()

    // Kept apart from the month so the 31st survives a pass through a shorter month.
    property int selectedDay: new Date().getDate()
    readonly property string selectedDate: dateKey(currentYear, currentMonth,
        Math.min(selectedDay, new Date(currentYear, currentMonth, 0).getDate()))

    property var events: []
    property var eventsByDate: ({})

    property string formTitle: ""
    property string formTime: ""
    property bool formAllDay: false
    property bool timeRejected: false

    property string loadError: ""
    property string actionError: ""

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
                                       "July", "August", "September", "October", "November", "December"]

    readonly property var modalEvents: (selectedDate && eventsByDate[selectedDate]) ? eventsByDate[selectedDate] : []

    readonly property bool isTimeFieldInvalid: {
        if (!formTime) return false
        if (formTime.length < 5 && !timeRejected) return false
        return !isValidTime(formTime)
    }

    onFormTimeChanged: timeRejected = false

    function dateKey(year, month, day) {
        let m = month < 10 ? "0" + month : "" + month
        let d = day < 10 ? "0" + day : "" + day
        return year + "-" + m + "-" + d
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

    function reloadEvents() {
        loadEventsProcess.command =
            Theme.CalendarCli.rangeArgv(currentYear, currentMonth - 1)
        loadEventsProcess.running = true
    }

    function addEvent(date, title, time) {
        if (!date || !title) return
        addEventProcess.command = [
            "mugen-ai", "calendar",
            "add", "--date", date, "--title", title, "--time", time || ""
        ]
        addEventProcess.running = true
    }

    function deleteEvent(id) {
        if (!id) return
        deleteEventProcess.command = [
            "mugen-ai", "calendar",
            "delete", "--id", id
        ]
        deleteEventProcess.running = true
    }

    function isValidTime(t) {
        return /^([01]?\d|2[0-3]):[0-5]\d$/.test(t)
    }

    function submitEvent() {
        let title = formTitle.trim()
        if (!title || addEventProcess.running) return
        let t = formAllDay ? "" : formTime.trim()
        if (t && !isValidTime(t)) {
            timeRejected = true
            return
        }
        addEvent(selectedDate, title, t)
    }

    function failureText(what, stderr) {
        let detail = ""
        try { detail = JSON.parse(stderr.split("\n")[0]).error || "" } catch (e) {}
        return detail ? what + ": " + detail : what
    }

    property real gridOpacity: 1.0
    property real gridShift: 0

    property real selectedHeaderOpacity: 1.0
    property real selectedHeaderShift: 0

    SequentialAnimation {
        id: selectedFlip
        NumberAnimation { target: root; property: "selectedHeaderOpacity"; to: 0.0; duration: Theme.Motion.micro; easing.type: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: root; property: "selectedHeaderShift"; from: -6; to: 0; duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "selectedHeaderOpacity"; to: 1.0; duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
        }
    }

    onSelectedDateChanged: selectedFlip.restart()

    SequentialAnimation {
        id: monthFlip
        property int targetMonth: 0
        property int targetYear: 0
        property int targetDay: 0
        property real shiftDir: 0

        ParallelAnimation {
            NumberAnimation { target: root; property: "gridOpacity"; to: 0.0; duration: Theme.Motion.micro; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "gridShift"; to: monthFlip.shiftDir * -18; duration: Theme.Motion.micro; easing.type: Easing.OutCubic }
        }
        ScriptAction {
            script: {
                if (monthFlip.targetDay > 0) root.selectedDay = monthFlip.targetDay
                root.currentMonth = monthFlip.targetMonth
                root.currentYear = monthFlip.targetYear
                root.reloadEvents()
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
        monthFlip.targetDay = 0
        monthFlip.shiftDir = delta >= 0 ? 1 : -1
        monthFlip.start()
    }

    function jumpToToday() {
        let delta = (todayYear - currentYear) * 12 + (todayMonth - currentMonth)
        if (delta === 0) {
            selectedDay = todayDay
            return
        }
        if (monthFlip.running) monthFlip.stop()
        monthFlip.targetMonth = todayMonth
        monthFlip.targetYear = todayYear
        monthFlip.targetDay = todayDay
        monthFlip.shiftDir = delta >= 0 ? 1 : -1
        monthFlip.start()
    }

    function formatSelectedDate(key) {
        if (!key) return ""
        let parts = key.split("-")
        if (parts.length !== 3) return key
        let monthName = monthNames[parseInt(parts[1]) - 1] || parts[1]
        return monthName + " " + parseInt(parts[2]) + ", " + parts[0]
    }

    Process {
        id: loadEventsProcess
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => { loadEventsProcess.output += data }
        }
        stderr: StdioCollector { id: loadEventsErrors }

        onExited: (exitCode) => {
            let parsed = null
            try { parsed = JSON.parse(loadEventsProcess.output) } catch (e) {}
            if (exitCode === 0 && parsed && Array.isArray(parsed.events)) {
                root.events = parsed.events
                root.rebuildIndex()
                root.loadError = ""
            } else {
                root.loadError = root.failureText("Couldn't load events", loadEventsErrors.text)
            }
            loadEventsProcess.output = ""
        }
    }

    Process {
        id: addEventProcess
        running: false
        stderr: StdioCollector { id: addEventErrors }
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.actionError = ""
                root.formTitle = ""
                root.formTime = ""
                eventForm.clear()
            } else {
                root.actionError = root.failureText("Couldn't add the event", addEventErrors.text)
            }
            root.reloadEvents()
        }
    }

    Process {
        id: deleteEventProcess
        running: false
        stderr: StdioCollector { id: deleteEventErrors }
        onExited: (exitCode) => {
            root.actionError = exitCode === 0 ? "" : root.failureText("Couldn't delete the event", deleteEventErrors.text)
            root.reloadEvents()
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.today = new Date()
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

        Cal.NightSky {
            anchors.fill: parent
            theme: root.theme
            reduceMotion: root.reduceMotion
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

                    Cal.NavChevron {
                        theme: root.theme
                        icon: "chevron-left"
                        onClicked: root.changeMonth(-1)
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

                    Cal.NavChevron {
                        theme: root.theme
                        icon: "chevron-right"
                        onClicked: root.changeMonth(1)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: root.weekdayLabels
                        delegate: Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: {
                                    const absoluteDay = (index + root.weekStart) % 7
                                    if (absoluteDay === 0) return Qt.hsla(0.0, 0.20, 0.72, 1.0)
                                    if (absoluteDay === 6) return Qt.hsla(0.6, 0.20, 0.72, 1.0)
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

                Cal.MonthGrid {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    opacity: root.gridOpacity
                    transform: Translate { x: root.gridShift }
                    theme: root.theme
                    year: root.currentYear
                    month: root.currentMonth
                    weekStart: root.weekStart
                    todayDay: root.todayDay
                    todayMonth: root.todayMonth
                    todayYear: root.todayYear
                    selectedDate: root.selectedDate
                    eventsByDate: root.eventsByDate
                    onDaySelected: day => root.selectedDay = day
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
                        text: Qt.formatDate(root.today, "ddd, MMM d, yyyy")
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

                Cal.EventList {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    theme: root.theme
                    events: root.modalEvents
                    loadError: root.loadError
                    onDeleteRequested: eventId => root.deleteEvent(eventId)
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: theme ? theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.1)
                    opacity: 0.3
                }

                Cal.EventForm {
                    id: eventForm
                    Layout.fillWidth: true
                    theme: root.theme
                    title: root.formTitle
                    time: root.formTime
                    allDay: root.formAllDay
                    timeInvalid: root.isTimeFieldInvalid
                    onTitleEdited: value => root.formTitle = value
                    onTimeEdited: value => root.formTime = value
                    onAllDayToggled: root.formAllDay = !root.formAllDay
                    onSubmitRequested: root.submitEvent()
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.actionError || root.loadError
                    textFormat: Text.PlainText
                    color: Qt.rgba(1, 0.5, 0.55, 1)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }
    }

    Component.onCompleted: {
        reloadEvents()
    }
}
