import QtQuick
import QtQuick.Layouts
import "../../common" as Common

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    readonly property bool custom: settingsManager ? settingsManager.barSurfaceCustom : false

    readonly property color previewColor: settingsManager
        ? Qt.hsla(settingsManager.barSurfaceHue,
                  settingsManager.barSurfaceSaturation,
                  settingsManager.barSurfaceLightness,
                  settingsManager.barSurfaceOpacity)
        : Qt.rgba(20 / 255, 22 / 255, 26 / 255, 0.82)

    width: parent ? parent.width : 420
    height: column.implicitHeight + 24
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function commit() {
        if (settingsManager) settingsManager.saveSettings()
        bump()
    }

    // Inline components cannot see the root's ids, so everything it needs arrives as a property.
    component SliderRow: RowLayout {
        id: row

        required property var rowTheme
        required property bool active
        property string label: ""
        property real value: 0
        property string display: Math.round(row.value * 100) + "%"

        signal moved(real newValue)
        signal released()

        Layout.fillWidth: true
        Layout.preferredHeight: 24
        spacing: 12
        enabled: row.active
        opacity: enabled ? 1 : 0.35

        Text {
            Layout.fillWidth: true
            text: row.label
            color: row.rowTheme ? row.rowTheme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.letterSpacing: 0.5
        }

        Common.Slider {
            Layout.preferredWidth: 180
            theme: row.rowTheme
            from: 0.0
            to: 1.0
            stepSize: 0.005
            value: row.value
            display: row.display

            onMoved: nv => row.moved(nv)
            onReleased: row.released()
        }
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
                text: "Bar surface"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.letterSpacing: 0.5
            }

            Common.Switch {
                checked: section.custom
                theme: section.theme

                onToggled: value => {
                    if (!section.settingsManager) return
                    section.settingsManager.barSurfaceCustom = value
                    section.commit()
                }
            }
        }

        SliderRow {
            rowTheme: section.theme
            active: section.custom
            label: "Hue"
            value: section.settingsManager ? section.settingsManager.barSurfaceHue : 0
            display: Math.round(value * 360) + "°"
            onMoved: nv => {
                if (section.settingsManager) section.settingsManager.barSurfaceHue = nv
                section.bump()
            }
            onReleased: section.commit()
        }

        SliderRow {
            rowTheme: section.theme
            active: section.custom
            label: "Saturation"
            value: section.settingsManager ? section.settingsManager.barSurfaceSaturation : 0
            onMoved: nv => {
                if (section.settingsManager) section.settingsManager.barSurfaceSaturation = nv
                section.bump()
            }
            onReleased: section.commit()
        }

        SliderRow {
            rowTheme: section.theme
            active: section.custom
            label: "Lightness"
            value: section.settingsManager ? section.settingsManager.barSurfaceLightness : 0
            onMoved: nv => {
                if (section.settingsManager) section.settingsManager.barSurfaceLightness = nv
                section.bump()
            }
            onReleased: section.commit()
        }

        SliderRow {
            rowTheme: section.theme
            active: section.custom
            label: "Opacity"
            value: section.settingsManager ? section.settingsManager.barSurfaceOpacity : 0
            onMoved: nv => {
                if (section.settingsManager) section.settingsManager.barSurfaceOpacity = nv
                section.bump()
            }
            onReleased: section.commit()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: 12
            enabled: section.custom
            opacity: enabled ? 1 : 0.35

            Text {
                Layout.fillWidth: true
                text: "Border"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.letterSpacing: 0.5
            }

            Common.Switch {
                checked: section.settingsManager ? section.settingsManager.barSurfaceBorder : true
                theme: section.theme

                onToggled: value => {
                    if (!section.settingsManager) return
                    section.settingsManager.barSurfaceBorder = value
                    section.commit()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 14
            // A pale backing, or a translucent preview reads as its own opaque colour.
            color: Qt.rgba(1, 1, 1, 0.12)
            enabled: section.custom
            opacity: enabled ? 1 : 0.35

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: section.previewColor
                border.width: section.settingsManager && section.settingsManager.barSurfaceBorder ? 1 : 0
                border.color: section.theme ? section.theme.surfaceBorder : Qt.rgba(0.70, 0.65, 0.90, 0.3)
            }
        }
    }
}
