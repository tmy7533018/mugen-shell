import QtQuick
import QtQuick.Layouts
import "../../common" as Common
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    readonly property string currentPalette: settingsManager ? settingsManager.moduleBackdropPalette : "harmony"

    width: parent ? parent.width : 420
    height: column.implicitHeight + 24
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function select(id) {
        if (!section.settingsManager) return
        section.settingsManager.moduleBackdropPalette = id
        section.settingsManager.saveSettings()
        section.bump()
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Module Background"
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.weight: Font.Normal
            font.letterSpacing: 0.5
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: Theme.ModulePalettes.list

                Item {
                    id: swatch
                    required property var modelData

                    readonly property bool current: section.currentPalette === swatch.modelData.id

                    Layout.preferredWidth: 76
                    Layout.preferredHeight: 76

                    Common.ModuleBackdrop {
                        anchors.fill: parent
                        surfaceRadius: 18
                        theme: section.theme
                        running: swatch.visible

                        satMin: swatch.modelData.satMin
                        satMax: swatch.modelData.satMax
                        spin: swatch.modelData.spin
                        strength: swatch.modelData.strength
                        levels: swatch.modelData.levels
                        sourceIndex: swatch.modelData.sourceIndex
                        spread: section.settingsManager ? section.settingsManager.moduleBackdropSpread : 0.06
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: "transparent"
                        border.width: swatch.current ? 2 : 1
                        border.color: swatch.current
                            ? (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 1))
                            : Qt.rgba(1, 1, 1, 0.10)

                        Behavior on border.color { ColorAnimation { duration: Theme.Motion.fast } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: section.select(swatch.modelData.id)
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Softness"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Normal
                font.letterSpacing: 0.5
            }

            Common.Slider {
                Layout.preferredWidth: 180
                theme: section.theme
                from: 0.02
                to: 0.20
                stepSize: 0.005
                value: section.settingsManager ? section.settingsManager.moduleBackdropSpread : 0.06
                display: Math.round((value - 0.02) / 0.18 * 100) + "%"

                onMoved: nv => {
                    if (section.settingsManager) section.settingsManager.moduleBackdropSpread = nv
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
