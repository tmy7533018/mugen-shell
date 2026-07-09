import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    width: parent ? parent.width : 420
    height: 86
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function formatPreview(fmt) {
        const safe = fmt && fmt.length > 0 ? fmt : "ddd M/d"
        try {
            return Qt.formatDate(new Date(), safe)
        } catch (e) {
            return "—"
        }
    }

    function commit() {
        if (!section.settingsManager) return
        const fmt = formatInput.text.length > 0 ? formatInput.text : "ddd M/d"
        if (section.settingsManager.dateFormat !== fmt) {
            section.settingsManager.dateFormat = fmt
            section.settingsManager.saveSettings()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Date Format"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Normal
                font.letterSpacing: 0.5
            }

            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 26
                color: "transparent"
                border.width: 1
                border.color: formatInput.activeFocus
                    ? (section.theme ? section.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1))
                    : (section.theme ? section.theme.surfaceBorder : Qt.rgba(1, 1, 1, 0.18))
                radius: 8

                Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }

                TextInput {
                    id: formatInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    text: section.settingsManager ? section.settingsManager.dateFormat : "ddd M/d"
                    color: section.theme ? section.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                    selectionColor: section.theme ? Qt.rgba(section.theme.glowPrimary.r, section.theme.glowPrimary.g, section.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true

                    onEditingFinished: {
                        section.commit()
                        section.bump()
                    }
                    Keys.onReturnPressed: {
                        section.commit()
                        section.bump()
                        focus = false
                    }
                    Keys.onEnterPressed: {
                        section.commit()
                        section.bump()
                        focus = false
                    }
                }
            }

            Text {
                Layout.preferredWidth: 90
                horizontalAlignment: Text.AlignRight
                text: section.formatPreview(formatInput.text)
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Tokens: d dd ddd dddd · M MM MMM MMMM · yy yyyy"
            color: section.theme ? section.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.55)
            font.pixelSize: 10
            font.family: "M PLUS 2"
            font.letterSpacing: 0.3
            elide: Text.ElideRight
        }
    }

    Connections {
        target: section.settingsManager
        function onDateFormatChanged() {
            if (!formatInput.activeFocus && formatInput.text !== section.settingsManager.dateFormat) {
                formatInput.text = section.settingsManager.dateFormat
            }
        }
    }
}
