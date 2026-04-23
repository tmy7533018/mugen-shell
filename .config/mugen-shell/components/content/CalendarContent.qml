import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

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

    Timer {
        id: autoCloseTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            if (modeManager.isMode("calendar")) {
                modeManager.closeAllModes()
            }
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("calendar")) {
                autoCloseTimer.restart()
            } else {
                autoCloseTimer.stop()
            }
        }
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
            if (modeManager.isMode("calendar")) {
                autoCloseTimer.restart()
            }
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
            if (modeManager.isMode("calendar")) {
                autoCloseTimer.restart()
            }
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
                color: Qt.rgba(0.91, 0.91, 0.94, 0.85)
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
                Layout.preferredWidth: modeManager.scale(480)
                Layout.preferredHeight: modeManager.scale(360)
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                    id: calendarBackground
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.25)
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
                            color: Qt.rgba(0.91, 0.91, 0.94, 0.70)
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

                            text: currentYear + "年 " + currentMonth + "月"
                            color: Qt.rgba(0.91, 0.91, 0.94, 0.85)
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
                            color: Qt.rgba(0.91, 0.91, 0.94, 0.70)
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
                            model: ["日", "月", "火", "水", "木", "金", "土"]
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
                        property string todayWeekday: ["日", "月", "火", "水", "木", "金", "土"][new Date().getDay()]

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
                                        return Qt.rgba(0.91, 0.91, 0.94, 0.85)
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

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: dayNumber > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    enabled: dayNumber > 0
                                    onClicked: {
                                        if (calendarGrid.selectedIndex === index) {
                                            calendarGrid.selectedIndex = -1
                                        } else {
                                            calendarGrid.selectedIndex = index
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("calendar", root)
            if (modeManager.isMode("calendar")) {
                autoCloseTimer.restart()
            }
        }
    }
}
