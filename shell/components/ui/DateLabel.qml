import QtQuick

Text {
    id: dateText

    property var theme
    property var typo
    property var modeManager
    property bool isHovered: false
    property color glowColor: Qt.rgba(0.65, 0.55, 0.85, 0.6)
    property string format: "ddd M/d"
    property real fontScale: 0.62

    property string dateString: ""

    text: dateString

    onFormatChanged: update()

    color: theme ? theme.textPrimaryBright : Qt.rgba(0.96, 0.96, 1.0, 0.90)

    font.family: typo ? typo.clockStyle.family : "M PLUS 2"
    font.pixelSize: {
        const base = typo ? typo.clockStyle.size : 14
        const scaled = base * fontScale
        return modeManager ? modeManager.scale(scaled) : scaled
    }
    font.weight: typo ? (typo.clockStyle.weight > Font.Normal ? typo.clockStyle.weight : Font.Medium) : Font.Medium
    font.letterSpacing: typo ? typo.clockStyle.letterSpacing : 0
    font.hintingPreference: typo ? typo.clockStyle.hinting : Font.PreferDefaultHinting
    font.kerning: typo ? typo.clockStyle.kerning : true

    renderType: Text.QtRendering
    smooth: true

    function update() {
        const now = new Date()
        const fmt = format && format.length > 0 ? format : "ddd M/d"
        let result = ""
        try {
            result = Qt.formatDate(now, fmt)
        } catch (e) {
            result = Qt.formatDate(now, "ddd M/d")
        }
        dateString = result
    }

    Timer {
        interval: 60000
        repeat: true
        running: dateText.visible
        onTriggered: dateText.update()
    }

    Component.onCompleted: update()
}
