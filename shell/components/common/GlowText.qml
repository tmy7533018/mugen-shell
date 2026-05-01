import QtQuick
import Qt5Compat.GraphicalEffects

Text {
    id: root
    
    property color glowColor: Qt.rgba(0.65, 0.55, 0.85, 0.6)
    property int glowSamples: 20
    property real glowRadius: 8
    property real glowSpread: 0.4
    property bool enableGlow: true
    property bool _glowReady: false
    
    color: Qt.rgba(0.91, 0.91, 0.94, 0.85)
    font.pixelSize: 20
    font.weight: Font.Light
    font.family: "M PLUS 2"
    font.letterSpacing: 1.5
    
    layer.enabled: enableGlow && _glowReady
    layer.effect: Glow {
        samples: root.glowSamples
        radius: root.glowRadius
        spread: root.glowSpread
        color: root.glowColor
        transparentBorder: true
    }
    
    Component.onCompleted: {
        Qt.callLater(() => {
            _glowReady = true
        })
    }
}

