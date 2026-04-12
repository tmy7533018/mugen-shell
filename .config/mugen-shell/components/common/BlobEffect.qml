import QtQuick

Item {
    id: root
    
    property color blobColor: Qt.rgba(0.65, 0.55, 0.85, 0.9)
    property int layers: 3
    property real waveAmplitude: 3.0
    property real baseOpacity: 0.85
    property real animationSpeed: 0.08
    property int pointCount: 16
    property bool running: true

    function getLayerOpacity(layerIndex) {
        return baseOpacity - layerIndex * 0.12
    }
    
    function getLayerAmplitude(layerIndex) {
        return waveAmplitude + layerIndex * 3.0
    }
    
    Repeater {
        model: root.layers
        
        Item {
            id: blobLayer
            anchors.fill: parent
            opacity: root.getLayerOpacity(index)
            
            Canvas {
                id: blobCanvas
                anchors.fill: parent
                
                property var offsets: []
                property real layerWaveAmplitude: root.getLayerAmplitude(index)
                
                Component.onCompleted: {
                    offsets = []
                    for (let i = 0; i < root.pointCount; i++) {
                        offsets.push(Math.random() * Math.PI * 2)
                    }
                    requestPaint()
                }
                
                onPaint: {
                    let ctx = getContext("2d")
                    ctx.reset()
                    
                    let centerX = width / 2
                    let centerY = height / 2
                    let baseRadius = Math.max(15, Math.min(width, height) / 2 - layerWaveAmplitude * 2)
                    
                    ctx.beginPath()
                    
                    for (let i = 0; i <= root.pointCount; i++) {
                        let angle = (i / root.pointCount) * Math.PI * 2
                        let waveOffset = Math.sin(offsets[i % root.pointCount]) * layerWaveAmplitude
                        let radius = baseRadius + waveOffset
                        
                        let x = centerX + Math.cos(angle) * radius
                        let y = centerY + Math.sin(angle) * radius
                        
                        if (i === 0) {
                            ctx.moveTo(x, y)
                        } else {
                            ctx.lineTo(x, y)
                        }
                    }
                    
                    ctx.closePath()
                    
                    let gradient = ctx.createRadialGradient(
                        centerX, centerY, 0,
                        centerX, centerY, baseRadius
                    )
                    gradient.addColorStop(0, Qt.rgba(
                        root.blobColor.r,
                        root.blobColor.g,
                        root.blobColor.b,
                        0.9 - index * 0.12
                    ))
                    gradient.addColorStop(1, Qt.rgba(
                        root.blobColor.r,
                        root.blobColor.g,
                        root.blobColor.b,
                        0
                    ))
                    
                    ctx.fillStyle = gradient
                    ctx.fill()
                }
                
                Timer {
                    interval: root.visible && root.running ? 150 : 1000
                    running: root.running && root.visible && parent.visible
                    repeat: true
                    onTriggered: {
                        if (!root.visible || !root.running) {
                            return
                        }
                        for (let i = 0; i < root.pointCount; i++) {
                            blobCanvas.offsets[i] += (root.animationSpeed + index * 0.15) * 2
                        }
                        blobCanvas.requestPaint()
                    }
                }
            }
        }
    }
}

