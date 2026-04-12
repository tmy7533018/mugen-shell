import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root
    
    property string source: ""
    property color color: Qt.rgba(0.95, 0.93, 0.98, 0.95)
    property bool invertColor: true

    property color glowColor: Qt.rgba(0.65, 0.55, 0.85, 0.6)
    property int glowSamples: 20
    property real glowRadius: 12
    property real glowSpread: 0.5
    property bool enableGlow: true
    
    implicitWidth: 24
    implicitHeight: 24
    
    property bool _overlayReady: false
    property bool _glowReady: false
    
    Image {
        id: iconImage
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: !_overlayReady

        // Load at 2x display size for sharpness when scaled on HiDPI
        sourceSize.width: Math.max(root.width, 24) * 2
        sourceSize.height: Math.max(root.height, 24) * 2
        
        onStatusChanged: {
            if (status === Image.Ready && !_overlayReady) {
                Qt.callLater(() => {
                    _overlayReady = true
                })
            }
        }
    }
    
    ColorOverlay {
        id: colorOverlay
        anchors.fill: iconImage
        source: iconImage
        color: root.color
        visible: _overlayReady
    }
    
    layer.enabled: enableGlow && _overlayReady && _glowReady
    layer.effect: Glow {
        samples: root.glowSamples
        radius: root.glowRadius
        spread: root.glowSpread
        color: root.glowColor
        transparentBorder: true
        source: colorOverlay
    }
    
    Component.onCompleted: {
        if (root.source === "") {
            _overlayReady = true
        }
        Qt.callLater(() => {
            _glowReady = true
        })
    }
}

