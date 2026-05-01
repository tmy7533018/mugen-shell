import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root
    
    property string source: ""
    property color color: Qt.rgba(0.92, 0.92, 0.96, 0.90)
    property bool invertColor: true
    
    implicitWidth: 24
    implicitHeight: 24
    
    property bool _overlayReady: false
    
    Image {
        id: iconImage
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: !_overlayReady
        
        // Load at 2x display size for crisp rendering when scaled
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
        anchors.fill: iconImage
        source: iconImage
        color: root.color
        visible: _overlayReady
    }
    
    Component.onCompleted: {
        if (root.source === "") {
            _overlayReady = true
        }
    }
}

