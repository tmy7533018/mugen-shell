import QtQuick
import QtQuick.Layouts
import "../../common" as Common

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    readonly property var rows: [
        { key: "barHeight", label: "Bar Height", from: 40, to: 90, unit: "px" },
        { key: "barRadius", label: "Bar Corner Radius", from: 0, to: 60, unit: "px" },
        { key: "barMarginH", label: "Bar Side Margin", from: 0, to: 40, unit: "px" },
        { key: "barMarginV", label: "Bar Top/Bottom Margin", from: 0, to: 30, unit: "px" }
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
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 24
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: parent.modelData.label
                    color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    font.weight: Font.Normal
                    font.letterSpacing: 0.5
                }

                Common.Slider {
                    Layout.preferredWidth: 180
                    theme: section.theme
                    from: modelData.from
                    to: modelData.to
                    stepSize: 1
                    value: section.settingsManager ? section.settingsManager[modelData.key] : modelData.from
                    display: Math.round(value) + modelData.unit

                    onMoved: nv => {
                        if (section.settingsManager) section.settingsManager[modelData.key] = Math.round(nv)
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
