import QtQuick
import QtQuick.Layouts
import "../common" as Common
import "../ui" as UI
import "../../lib" as Theme

Item {
    id: root

    required property var modeManager
    required property var weatherManager
    property var theme
    property var icons

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(544),
        "leftMargin": modeManager.scale(540),
        "rightMargin": modeManager.scale(540),
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

    readonly property color cText: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.9)
    readonly property color cSub: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.9)
    readonly property color cFaint: theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.9)
    readonly property color cCard: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)

    // Open-Meteo hourly starts at today 00:00; slice from the current hour.
    function hourlyStart() {
        let h = weatherManager ? weatherManager.hourly : []
        if (!h || h.length === 0) return 0
        let now = new Date()
        for (let i = 0; i < h.length; i++) {
            if (new Date(h[i].time) >= now) return Math.max(0, i - 1)
        }
        return 0
    }

    property var hourlySlice: {
        let h = weatherManager ? weatherManager.hourly : []
        let s = hourlyStart()
        return h.slice(s, s + 24)
    }

    property real weekMin: {
        let d = weatherManager ? weatherManager.daily : []
        if (!d || d.length === 0) return 0
        let m = d[0].tempMin
        for (let i = 0; i < d.length; i++) m = Math.min(m, d[i].tempMin)
        return m
    }
    property real weekMax: {
        let d = weatherManager ? weatherManager.daily : []
        if (!d || d.length === 0) return 1
        let m = d[0].tempMax
        for (let i = 0; i < d.length; i++) m = Math.max(m, d[i].tempMax)
        return m
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

    // The content Loader fills the whole window; inset onto the bar surface
    // (which is sized to requiredBarSize) so nothing spills past the pill.
    FocusScope {
        anchors.fill: parent
        anchors.topMargin: root.requiredBarSize.topMargin + root.scaled(22)
        anchors.bottomMargin: root.requiredBarSize.bottomMargin + root.scaled(22)
        anchors.leftMargin: root.requiredBarSize.leftMargin + root.scaled(30)
        anchors.rightMargin: root.requiredBarSize.rightMargin + root.scaled(30)
        z: 3
        focus: modeManager.isMode("weather")
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: root.scaled(16)

            // --- Current conditions ---
            RowLayout {
                Layout.fillWidth: true
                spacing: root.scaled(18)

                Text {
                    text: (root.icons && root.weatherManager)
                        ? root.icons.weatherGlyph(root.weatherManager.weatherCode, root.weatherManager.isDay)
                        : ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: root.scaled(64)
                    color: root.cText
                    renderType: Text.QtRendering
                }

                ColumnLayout {
                    spacing: root.scaled(2)
                    Text {
                        text: root.weatherManager ? (Math.round(root.weatherManager.temperature) + "°") : "—"
                        font.family: "M PLUS 2"
                        font.pixelSize: root.scaled(52)
                        font.weight: Font.Light
                        color: root.cText
                    }
                    Text {
                        text: (root.icons && root.weatherManager) ? root.icons.weatherText(root.weatherManager.weatherCode) : ""
                        font.family: "M PLUS 2"
                        font.pixelSize: root.scaled(15)
                        color: root.cSub
                    }
                }

                Item { Layout.fillWidth: true }

                ColumnLayout {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    spacing: root.scaled(4)
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: root.weatherManager ? root.weatherManager.locationName : ""
                        font.family: "M PLUS 2"
                        font.pixelSize: root.scaled(18)
                        font.weight: Font.Medium
                        color: root.cText
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: root.weatherManager
                            ? ("Feels " + Math.round(root.weatherManager.feelsLike) + "°   ·   Humidity " + root.weatherManager.humidity + "%   ·   Wind " + Math.round(root.weatherManager.wind) + " km/h")
                            : ""
                        font.family: "M PLUS 2"
                        font.pixelSize: root.scaled(12)
                        color: root.cFaint
                    }
                }
            }

            // --- Hourly (next 24h) ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.scaled(128)
                color: root.cCard
                radius: root.scaled(12)

                ListView {
                    anchors.fill: parent
                    anchors.margins: root.scaled(10)
                    orientation: ListView.Horizontal
                    spacing: root.scaled(4)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.hourlySlice

                    delegate: Column {
                        width: root.scaled(52)
                        height: ListView.view.height
                        spacing: root.scaled(6)

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: index === 0 ? "Now" : Qt.formatDateTime(new Date(modelData.time), "H") + "時"
                            font.family: "M PLUS 2"
                            font.pixelSize: root.scaled(11)
                            color: root.cFaint
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.icons ? root.icons.weatherGlyph(modelData.code, Qt.formatDateTime(new Date(modelData.time), "H") >= 6 && Qt.formatDateTime(new Date(modelData.time), "H") < 19) : ""
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: root.scaled(20)
                            color: root.cText
                            renderType: Text.QtRendering
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (modelData.precip > 0 ? modelData.precip + "%" : "")
                            font.family: "M PLUS 2"
                            font.pixelSize: root.scaled(10)
                            color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round(modelData.temp) + "°"
                            font.family: "M PLUS 2"
                            font.pixelSize: root.scaled(13)
                            font.weight: Font.Medium
                            color: root.cText
                        }
                    }
                }
            }

            // --- Daily (7 days) ---
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.cCard
                radius: root.scaled(12)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.scaled(12)
                    spacing: 0

                    Repeater {
                        model: root.weatherManager ? root.weatherManager.daily : []

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.scaled(30)
                            Layout.maximumHeight: root.scaled(32)
                            spacing: root.scaled(12)

                            Text {
                                Layout.preferredWidth: root.scaled(52)
                                text: index === 0 ? "Today" : Qt.formatDateTime(new Date(modelData.date), "ddd")
                                font.family: "M PLUS 2"
                                font.pixelSize: root.scaled(14)
                                color: root.cSub
                            }
                            Text {
                                Layout.preferredWidth: root.scaled(28)
                                Layout.preferredHeight: root.scaled(30)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: root.icons ? root.icons.weatherGlyph(modelData.code, true) : ""
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: root.scaled(16)
                                color: root.cText
                                renderType: Text.QtRendering
                            }
                            Text {
                                Layout.preferredWidth: root.scaled(40)
                                text: modelData.precipProb > 0 ? modelData.precipProb + "%" : ""
                                font.family: "M PLUS 2"
                                font.pixelSize: root.scaled(12)
                                color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                            }

                            Text {
                                Layout.preferredWidth: root.scaled(34)
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(modelData.tempMin) + "°"
                                font.family: "M PLUS 2"
                                font.pixelSize: root.scaled(13)
                                color: root.cFaint
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.scaled(4)
                                radius: height / 2
                                color: Qt.rgba(root.cFaint.r, root.cFaint.g, root.cFaint.b, 0.25)

                                Rectangle {
                                    property real span: Math.max(1, root.weekMax - root.weekMin)
                                    x: parent.width * (modelData.tempMin - root.weekMin) / span
                                    width: parent.width * (modelData.tempMax - modelData.tempMin) / span
                                    height: parent.height
                                    radius: height / 2
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: theme ? theme.glowSecondary : Qt.rgba(0.4, 0.6, 0.9, 0.9) }
                                        GradientStop { position: 1.0; color: theme ? theme.accent : Qt.rgba(0.9, 0.6, 0.4, 0.9) }
                                    }
                                }
                            }
                            Text {
                                Layout.preferredWidth: root.scaled(34)
                                text: Math.round(modelData.tempMax) + "°"
                                font.family: "M PLUS 2"
                                font.pixelSize: root.scaled(13)
                                font.weight: Font.Medium
                                color: root.cText
                            }
                        }
                    }
                }
            }
        }
    }
}
