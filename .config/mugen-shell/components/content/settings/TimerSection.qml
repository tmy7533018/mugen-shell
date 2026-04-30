import QtQuick
import QtQuick.Layouts

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    width: parent ? parent.width : 420
    height: 64
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Auto Close Timer"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.weight: Font.Normal
            font.letterSpacing: 0.5
        }

        Item {
            id: timerSlider
            Layout.preferredWidth: 180
            Layout.preferredHeight: 24

            property real from: 0
            property real to: 30
            property real stepSize: 1
            property real value: section.settingsManager ? Math.round(section.settingsManager.autoCloseTimerInterval / 1000) : 5

            function valueAt(x) {
                const w = Math.max(1, width)
                const ratio = Math.max(0, Math.min(1, x / w))
                const raw = from + ratio * (to - from)
                return Math.round(raw / stepSize) * stepSize
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.15)

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * (timerSlider.value - timerSlider.from) / (timerSlider.to - timerSlider.from)
                    radius: parent.radius
                    color: section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                }
            }

            Rectangle {
                x: ((timerSlider.value - timerSlider.from) / (timerSlider.to - timerSlider.from)) * (timerSlider.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 8
                color: section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, timerMouseArea.pressed ? 1.0 : 0.95) : Qt.rgba(0.65, 0.55, 0.85, 0.95)
                border.width: 1
                border.color: section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5)
            }

            MouseArea {
                id: timerMouseArea
                anchors.fill: parent
                anchors.topMargin: -12
                anchors.bottomMargin: -12
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                onPressed: (mouse) => {
                    timerSlider.value = timerSlider.valueAt(mouse.x)
                    section.bump()
                }
                onPositionChanged: (mouse) => {
                    if (pressed) timerSlider.value = timerSlider.valueAt(mouse.x)
                }
                onReleased: {
                    if (section.settingsManager) {
                        section.settingsManager.autoCloseTimerInterval = Math.round(timerSlider.value) * 1000
                        section.settingsManager.saveSettings()
                    }
                    section.bump()
                }
            }
        }

        Text {
            Layout.preferredWidth: 40
            horizontalAlignment: Text.AlignRight
            text: timerSlider.value === 0 ? "Off" : Math.round(timerSlider.value) + "s"
            color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.weight: Font.Medium
        }
    }
}
