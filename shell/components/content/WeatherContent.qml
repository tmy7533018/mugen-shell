import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../common" as Common
import "../ui" as UI
import "../../lib" as Theme

Item {
    id: root

    required property var modeManager
    required property var weatherManager
    property var theme
    property var icons
    property bool reduceMotion: false

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(478),
        "leftMargin": modeManager.scale(576),
        "rightMargin": modeManager.scale(576),
        "topMargin": modeManager.normalBarSize.topMargin,
        "bottomMargin": modeManager.normalBarSize.bottomMargin
    })

    function scaled(v) { return modeManager ? modeManager.scale(v) : v }

    Component.onCompleted: modeManager.registerMode("weather", root)

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("weather") && root.weatherManager) root.weatherManager.refresh()
        }
    }


    // --- Weather-driven "夢幻" palette ---
    readonly property string wtype: (icons && weatherManager) ? icons.weatherType(weatherManager.weatherCode, weatherManager.isDay) : "clouds"
    readonly property var pal: icons ? icons.weatherPalette(wtype) : null
    readonly property color cAccent: pal ? pal.accent : Qt.rgba(0.74, 0.78, 0.90, 1)
    readonly property color cAccent2: pal ? pal.accent2 : Qt.rgba(0.58, 0.63, 0.78, 1)
    readonly property color cGlow: pal ? pal.glow : Qt.rgba(0.74, 0.78, 0.90, 0.4)
    readonly property color cFg: pal ? pal.fg : Qt.rgba(0.93, 0.95, 0.98, 1)
    readonly property color cDim: pal ? pal.dim : Qt.rgba(0.86, 0.89, 0.96, 0.58)

    readonly property real weekMin: {
        let d = weatherManager ? weatherManager.daily : []
        if (!d || d.length === 0) return 0
        let m = d[0].tempMin
        for (let i = 0; i < d.length; i++) m = Math.min(m, d[i].tempMin)
        return m
    }
    readonly property real weekMax: {
        let d = weatherManager ? weatherManager.daily : []
        if (!d || d.length === 0) return 1
        let m = d[0].tempMax
        for (let i = 0; i < d.length; i++) m = Math.max(m, d[i].tempMax)
        return m
    }

    function isHourDay(t) {
        let h = new Date(t).getHours()
        return h >= 6 && h < 19
    }

    function hourlyStart() {
        let h = weatherManager ? weatherManager.hourly : []
        if (!h || h.length === 0) return 0
        let now = new Date()
        for (let i = 0; i < h.length; i++) {
            if (new Date(h[i].time) >= now) return Math.max(0, i - 1)
        }
        return 0
    }
    readonly property var hourlySlice: {
        let h = weatherManager ? weatherManager.hourly : []
        return h.slice(hourlyStart(), hourlyStart() + 18)
    }

    MouseArea {
        anchors.fill: parent
        z: 1.5
        enabled: modeManager.isMode("weather")
        visible: enabled
        hoverEnabled: true
        onClicked: modeManager.closeAllModes()
        onPositionChanged: { if (modeManager.isMode("weather")) modeManager.bump() }
    }

    FocusScope {
        id: contentScope
        anchors.fill: parent
        anchors.topMargin: root.requiredBarSize.topMargin + root.scaled(16)
        anchors.bottomMargin: root.requiredBarSize.bottomMargin + root.scaled(16)
        anchors.leftMargin: root.requiredBarSize.leftMargin + root.scaled(22)
        anchors.rightMargin: root.requiredBarSize.rightMargin + root.scaled(22)
        z: 3
        focus: modeManager.isMode("weather")

        opacity: 0

        states: [
            State {
                name: "visible"
                when: modeManager.isMode("weather")
                PropertyChanges { target: contentScope; opacity: 1.0 }
            }
        ]

        transitions: [
            Transition {
                from: "visible"
                to: ""
                NumberAnimation {
                    property: "opacity"
                    duration: Theme.Motion.standard
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: Theme.Motion.standard }
                    NumberAnimation {
                        property: "opacity"
                        duration: Theme.Motion.gentle
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        ]
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) { modeManager.closeAllModes(); event.accepted = true }
        }

        // Palette-gradient panel body with floating blobs.
        Rectangle {
            id: panelBg
            anchors.fill: parent
            radius: root.scaled(26)
            clip: true
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.07)
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.pal ? root.pal.bg1 : "#20232e" }
                GradientStop { position: 0.38; color: root.pal ? root.pal.bg2 : "#2b2f3d" }
                GradientStop { position: 1.0; color: root.pal ? root.pal.bg3 : "#0e1015" }
            }

            Common.BlobEffect {
                id: blob1
                width: root.scaled(230); height: root.scaled(230)
                x: root.scaled(120) + drift; y: -root.scaled(70)
                property real drift: 0
                blobColor: Qt.darker(root.cAccent, 1.35)
                baseOpacity: 0.32
                layers: 2
                waveAmplitude: 5.0
                animationSpeed: 0.05
                running: !root.reduceMotion
                SequentialAnimation on drift {
                    running: !root.reduceMotion; loops: Animation.Infinite
                    NumberAnimation { from: 0; to: root.scaled(26); duration: 13000; easing.type: Easing.InOutSine }
                    NumberAnimation { from: root.scaled(26); to: 0; duration: 13000; easing.type: Easing.InOutSine }
                }
            }
            Common.BlobEffect {
                id: blob2
                width: root.scaled(210); height: root.scaled(210)
                x: parent.width - root.scaled(200) + drift; y: parent.height - root.scaled(90)
                property real drift: 0
                blobColor: Qt.darker(root.cAccent2, 1.35)
                baseOpacity: 0.23
                layers: 2
                waveAmplitude: 5.0
                animationSpeed: 0.045
                running: !root.reduceMotion
                SequentialAnimation on drift {
                    running: !root.reduceMotion; loops: Animation.Infinite
                    NumberAnimation { from: 0; to: -root.scaled(28); duration: 16000; easing.type: Easing.InOutSine }
                    NumberAnimation { from: -root.scaled(28); to: 0; duration: 16000; easing.type: Easing.InOutSine }
                }
            }

            WeatherParticles {
                anchors.fill: parent
                wtype: root.wtype
                windKmh: root.weatherManager ? root.weatherManager.wind : 0
                tint: root.cAccent
                active: !root.reduceMotion
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.scaled(22)
                spacing: root.scaled(14)

                // ---- Row 1: current + hourly ----
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: root.scaled(14)

                    // Current conditions glass card
                    Rectangle {
                        Layout.preferredWidth: root.scaled(226)
                        Layout.fillHeight: true
                        radius: root.scaled(20)
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.12)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: root.scaled(18)
                            spacing: root.scaled(2)

                            Text {
                                text: root.weatherManager ? root.weatherManager.locationName : ""
                                font.family: "M PLUS 2"; font.pixelSize: root.scaled(10.5)
                                font.letterSpacing: 2.5
                                font.capitalization: Font.AllUppercase
                                color: root.cDim
                            }
                            RowLayout {
                                Layout.topMargin: root.scaled(4)
                                spacing: root.scaled(10)
                                Text {
                                    id: bigTemp
                                    Layout.preferredHeight: root.scaled(62)
                                    verticalAlignment: Text.AlignVCenter
                                    text: root.weatherManager ? Math.round(root.weatherManager.temperature) + "°" : "—"
                                    font.family: "M PLUS 2"; font.pixelSize: root.scaled(58); font.weight: Font.Light
                                    color: root.cFg
                                    layer.enabled: true
                                    layer.effect: Glow { color: root.cGlow; radius: 14; samples: 25; spread: 0.2; transparentBorder: true }
                                }
                                UI.SvgIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: root.scaled(58)
                                    Layout.preferredHeight: root.scaled(58)
                                    source: (root.icons && root.weatherManager) ? root.icons.weatherIcon(root.weatherManager.weatherCode, root.weatherManager.isDay) : ""
                                    color: root.cAccent
                                    layer.enabled: true
                                    layer.effect: Glow { color: root.cGlow; radius: 10; samples: 21; spread: 0.3; transparentBorder: true }
                                }
                            }
                            Text {
                                Layout.topMargin: root.scaled(5)
                                text: (root.icons && root.weatherManager) ? root.icons.weatherText(root.weatherManager.weatherCode) : ""
                                font.family: "M PLUS 2"; font.pixelSize: root.scaled(15)
                                color: root.cDim
                            }
                            Text {
                                Layout.topMargin: root.scaled(12)
                                text: root.weatherManager ? ("Feels " + Math.round(root.weatherManager.feelsLike) + "°   ·   Humidity " + root.weatherManager.humidity + "%") : ""
                                font.family: "M PLUS 2"; font.pixelSize: root.scaled(11.5); color: root.cDim
                            }
                            Text {
                                text: root.weatherManager ? "Wind " + Math.round(root.weatherManager.wind) + " km/h" : ""
                                font.family: "M PLUS 2"; font.pixelSize: root.scaled(11.5); color: root.cDim
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }

                    // Hourly glass card
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: root.scaled(20)
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.1)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: root.scaled(16)
                            spacing: root.scaled(8)

                            Text {
                                text: "24 HOURS"
                                font.family: "M PLUS 2"; font.pixelSize: root.scaled(10)
                                font.letterSpacing: 2.5
                                color: root.cDim
                            }
                            ListView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                orientation: ListView.Horizontal
                                spacing: root.scaled(8)
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                model: root.hourlySlice

                                delegate: Rectangle {
                                    width: (ListView.view.width - 6 * ListView.view.spacing) / 7
                                    height: ListView.view.height
                                    radius: root.scaled(15)
                                    color: Qt.rgba(1, 1, 1, 0.06)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.1)

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.topMargin: root.scaled(14)
                                        anchors.bottomMargin: root.scaled(14)
                                        spacing: root.scaled(7)
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: index === 0 ? "Now" : Qt.formatDateTime(new Date(modelData.time), "H")
                                            font.family: "M PLUS 2"; font.pixelSize: root.scaled(11); color: root.cDim
                                        }
                                        Item { Layout.fillHeight: true }
                                        UI.SvgIcon {
                                            Layout.alignment: Qt.AlignHCenter
                                            source: root.icons ? root.icons.weatherIcon(modelData.code, root.isHourDay(modelData.time)) : ""
                                            color: root.cAccent
                                            width: root.scaled(20); height: root.scaled(20)
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData.precip > 0 ? modelData.precip + "%" : ""
                                            font.family: "M PLUS 2"; font.pixelSize: root.scaled(11); font.weight: Font.Medium; color: root.cAccent2
                                        }
                                        Item { Layout.fillHeight: true }
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: Math.round(modelData.temp) + "°"
                                            font.family: "M PLUS 2"; font.pixelSize: root.scaled(14); font.weight: Font.Medium; color: root.cFg
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- Row 2: 7-day columns with vertical range bars ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.scaled(190)
                    radius: root.scaled(20)
                    color: Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.13)

                    RowLayout {
                        id: dailyRow
                        anchors.fill: parent
                        anchors.margins: root.scaled(14)
                        spacing: root.scaled(4)

                        Repeater {
                            model: root.weatherManager ? root.weatherManager.daily : []

                            ColumnLayout {
                                Layout.preferredWidth: (dailyRow.width - 6 * dailyRow.spacing) / 7
                                Layout.fillHeight: true
                                spacing: root.scaled(5)

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: index === 0 ? "Today" : Qt.formatDateTime(new Date(modelData.date), "ddd")
                                    font.family: "M PLUS 2"; font.pixelSize: root.scaled(12.5); color: root.cDim
                                }
                                UI.SvgIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    source: root.icons ? root.icons.weatherIcon(modelData.code, true) : ""
                                    color: root.cAccent
                                    width: root.scaled(20); height: root.scaled(20)
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.precipProb > 0 ? modelData.precipProb + "%" : ""
                                    font.family: "M PLUS 2"; font.pixelSize: root.scaled(11); font.weight: Font.Medium; color: root.cAccent2
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Math.round(modelData.tempMax) + "°"
                                    font.family: "M PLUS 2"; font.pixelSize: root.scaled(14); font.weight: Font.Medium; color: root.cFg
                                }
                                // vertical range bar
                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.fillHeight: true
                                    width: root.scaled(6)
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: root.scaled(6); height: parent.height
                                        radius: width / 2
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                    }
                                    Rectangle {
                                        property real span: Math.max(1, root.weekMax - root.weekMin)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: root.scaled(6)
                                        y: parent.height * (root.weekMax - modelData.tempMax) / span
                                        height: parent.height * (modelData.tempMax - modelData.tempMin) / span
                                        radius: width / 2
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: root.cAccent }
                                            GradientStop { position: 1.0; color: root.cAccent2 }
                                        }
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Math.round(modelData.tempMin) + "°"
                                    font.family: "M PLUS 2"; font.pixelSize: root.scaled(12); color: root.cDim
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
