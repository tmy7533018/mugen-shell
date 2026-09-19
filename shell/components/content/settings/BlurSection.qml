import QtQuick
import QtQuick.Layouts
import "../../common" as Common

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    // The values ride along with the signal so an apply never races the settings save.
    signal previewBlur(var params)
    signal applyBlur(var params)

    readonly property bool enabled: settingsManager ? settingsManager.blurEnabled : true

    width: parent ? parent.width : 420
    height: column.implicitHeight + 24
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function nudge() {
        if (!settingsManager) return
        section.previewBlur(settingsManager.blurParams())
        bump()
    }

    function settle() {
        if (!settingsManager) return
        section.applyBlur(settingsManager.blurParams())
        bump()
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Blur"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.letterSpacing: 0.5
            }

            Common.Switch {
                checked: section.enabled
                theme: section.theme
                onToggled: value => {
                    if (!section.settingsManager) return
                    section.settingsManager.blurEnabled = value
                    section.settle()
                }
            }
        }

        Common.SliderRow {
            rowTheme: section.theme
            active: section.enabled
            label: "Size"
            value: section.settingsManager ? (section.settingsManager.blurSize - 1) / 49 : 0
            display: (section.settingsManager ? section.settingsManager.blurSize : 0) + " px"
            onMoved: nv => { section.settingsManager.blurSize = 1 + Math.round(nv * 49); section.nudge() }
            onReleased: section.settle()
        }

        Common.SliderRow {
            rowTheme: section.theme
            active: section.enabled
            label: "Passes"
            value: section.settingsManager ? (section.settingsManager.blurPasses - 1) / 4 : 0
            display: String(section.settingsManager ? section.settingsManager.blurPasses : 0)
            onMoved: nv => { section.settingsManager.blurPasses = 1 + Math.round(nv * 4); section.nudge() }
            onReleased: section.settle()
        }

        Common.SliderRow {
            rowTheme: section.theme
            active: section.enabled
            label: "Noise"
            value: section.settingsManager ? section.settingsManager.blurNoise / 0.3 : 0
            display: (section.settingsManager ? section.settingsManager.blurNoise : 0).toFixed(3)
            onMoved: nv => { section.settingsManager.blurNoise = Math.round(nv * 300) / 1000; section.nudge() }
            onReleased: section.settle()
        }

        Common.SliderRow {
            rowTheme: section.theme
            active: section.enabled
            label: "Contrast"
            value: section.settingsManager ? (section.settingsManager.blurContrast - 0.5) / 1.5 : 0
            display: (section.settingsManager ? section.settingsManager.blurContrast : 0).toFixed(2)
            onMoved: nv => { section.settingsManager.blurContrast = Math.round((0.5 + nv * 1.5) * 100) / 100; section.nudge() }
            onReleased: section.settle()
        }

        Common.SliderRow {
            rowTheme: section.theme
            active: section.enabled
            label: "Brightness"
            value: section.settingsManager ? section.settingsManager.blurBrightness - 0.5 : 0
            display: (section.settingsManager ? section.settingsManager.blurBrightness : 0).toFixed(2)
            onMoved: nv => { section.settingsManager.blurBrightness = Math.round((0.5 + nv) * 100) / 100; section.nudge() }
            onReleased: section.settle()
        }

        Common.SliderRow {
            rowTheme: section.theme
            active: section.enabled
            label: "Vibrancy"
            value: section.settingsManager ? section.settingsManager.blurVibrancy : 0
            display: (section.settingsManager ? section.settingsManager.blurVibrancy : 0).toFixed(2)
            onMoved: nv => { section.settingsManager.blurVibrancy = Math.round(nv * 100) / 100; section.nudge() }
            onReleased: section.settle()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: 12
            enabled: section.enabled
            opacity: enabled ? 1 : 0.35

            Text {
                Layout.fillWidth: true
                text: "X-ray"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.letterSpacing: 0.5
            }

            Common.Switch {
                checked: section.settingsManager ? section.settingsManager.blurXray : false
                theme: section.theme
                onToggled: value => { section.settingsManager.blurXray = value; section.settle() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: 12
            enabled: section.enabled
            opacity: enabled ? 1 : 0.35

            Text {
                Layout.fillWidth: true
                text: "Ignore opacity"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.letterSpacing: 0.5
            }

            Common.Switch {
                checked: section.settingsManager ? section.settingsManager.blurIgnoreOpacity : true
                theme: section.theme
                onToggled: value => { section.settingsManager.blurIgnoreOpacity = value; section.settle() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item { Layout.fillWidth: true }

            Common.ActionButton {
                theme: section.theme
                label: "Reset to default"
                buttonWidth: 130
                onClicked: {
                    if (!section.settingsManager) return
                    section.settingsManager.resetBlur()
                    section.settle()
                }
            }
        }
    }
}
