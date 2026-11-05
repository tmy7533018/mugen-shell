pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../common" as Common

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    readonly property var rows: [
        { key: "volumeStep", label: "Volume step", from: 1, to: 10, stepSize: 1, fallback: 2 },
        { key: "volumeMax", label: "Volume limit", from: 100, to: 150, stepSize: 5, fallback: 100 }
    ]

    width: parent ? parent.width : 420
    height: rowsColumn.implicitHeight + 24
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    ColumnLayout {
        id: rowsColumn
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Repeater {
            model: section.rows

            RowLayout {
                id: settingRow
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 24
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: settingRow.modelData.label
                    color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    font.weight: Font.Normal
                    font.letterSpacing: 0.5
                }

                Common.Slider {
                    Layout.preferredWidth: 180
                    theme: section.theme
                    from: settingRow.modelData.from
                    to: settingRow.modelData.to
                    stepSize: settingRow.modelData.stepSize
                    value: section.settingsManager ? section.settingsManager[settingRow.modelData.key] : settingRow.modelData.fallback
                    display: Math.round(value) + "%"

                    onMoved: nv => {
                        if (section.settingsManager) section.settingsManager[settingRow.modelData.key] = Math.round(nv)
                        section.bump()
                    }
                    onReleased: {
                        if (section.settingsManager) section.settingsManager.saveSettings()
                        section.bump()
                    }
                }
            }
        }
    }
}
