import QtQuick

Row {
    id: root
    
    spacing: barSpacing
    // Fixed height prevents bar positions from shifting when levels change
    height: maxBarHeight

    required property var cavaManager
    
    property int barCount: 6
    property real barWidth: 3
    property real barSpacing: 3
    property real minBarHeight: 6
    property real maxBarHeight: 28
    property real heightBlend: 0.7
    property var barIndices: [14, 7, 0, 1, 8, 15]
    // Diamond pattern: center bars are tallest, edges are shortest
    property var maxHeightMultipliers: [0.6, 0.8, 1.0, 1.0, 0.8, 0.6]
    property color barColor: Qt.rgba(0.72, 0.72, 0.82, 0.90)
    property color baseColor: Qt.rgba(0.72, 0.72, 0.82, 0.90)
    
    function getBarMaxHeight(barIndex) {
        let multipliers = (maxHeightMultipliers && maxHeightMultipliers.length === barCount)
            ? maxHeightMultipliers
            : Array.from({length: barCount}, () => 1.0)
        let multiplier = multipliers[Math.min(barIndex, multipliers.length - 1)] || 1.0
        return root.minBarHeight + (root.maxBarHeight - root.minBarHeight) * multiplier
    }
    
    // Levels are used as-is: cava's autosens already owns the gain range, so a
    // second QML-side normalization on top only fights it. Keep this a plain
    // blend of the per-bar level and the overall rms.
    function getBarLevel(index) {
        if (!cavaManager || !cavaManager.barLevels) {
            return 0
        }

        let indices = (barIndices && barIndices.length === barCount)
            ? barIndices
            : Array.from({length: barCount}, (_, i) => Math.min(Math.round(i * 15 / Math.max(1, barCount - 1)), 15))

        let sourceIndex = indices[Math.min(index, indices.length - 1)]
        let specific = cavaManager.barLevels[sourceIndex] || 0
        let overall = cavaManager.rms || 0
        let blended = specific * heightBlend + overall * (1.0 - heightBlend)

        return Math.max(0, Math.min(1, blended))
    }
    
    Repeater {
        model: root.barCount
        
        Item {
            width: root.barWidth
            height: root.maxBarHeight
            
            Rectangle {
                id: bar
                width: root.barWidth
                height: root.minBarHeight
                x: 0
                property real targetY: (parent.height - root.minBarHeight) / 2
                y: targetY
                property real currentLevel: 0
                radius: root.barWidth / 2
                
                // 80ms: at the 60fps feed this is just enough to bridge frames
                // without adding visible lag (120ms read as sluggish).
                Behavior on height {
                    NumberAnimation {
                        duration: 80
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on targetY {
                    NumberAnimation {
                        duration: 80
                        easing.type: Easing.OutQuad
                    }
                }
                
                gradient: Gradient {
                    GradientStop {
                        id: bottomStop
                        position: 0.0
                        color: root.barColor
                    }
                    GradientStop {
                        id: topStop
                        position: 1.0
                        color: Qt.rgba(
                            root.barColor.r + (root.baseColor.r - root.barColor.r) * bar.currentLevel,
                            root.barColor.g + (root.baseColor.g - root.barColor.g) * bar.currentLevel,
                            root.barColor.b + (root.baseColor.b - root.barColor.b) * bar.currentLevel,
                            root.barColor.a
                        )
                    }
                }
                
                onCurrentLevelChanged: {
                    topStop.color = Qt.rgba(
                        root.barColor.r + (root.baseColor.r - root.barColor.r) * bar.currentLevel,
                        root.barColor.g + (root.baseColor.g - root.barColor.g) * bar.currentLevel,
                        root.barColor.b + (root.baseColor.b - root.barColor.b) * bar.currentLevel,
                        root.barColor.a
                    )
                }
                
                // Phase-offset color cycling per bar for a staggered shimmer effect
                property int animationDuration: 800
                property int totalCycle: animationDuration * 2
                property int colorOffset: Math.floor((index / root.barCount) * totalCycle)
                
                SequentialAnimation on currentLevel {
                    id: colorAnimation
                    loops: Animation.Infinite
                    running: root.cavaManager && root.cavaManager.isActive

                    PauseAnimation {
                        duration: bar.colorOffset
                    }
                    
                    NumberAnimation {
                        from: 0.0
                        to: 1.0
                        duration: bar.animationDuration
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 1.0
                        to: 0.0
                        duration: bar.animationDuration
                        easing.type: Easing.InOutSine
                    }
                }
                
                function updateAppearance() {
                    if (!root.cavaManager) {
                        bar.height = root.minBarHeight
                        bar.targetY = (parent.height - bar.height) / 2
                        return
                    }
                    let level = root.getBarLevel(index)
                    let barMaxHeight = root.getBarMaxHeight(index)
                    bar.height = root.minBarHeight + level * (barMaxHeight - root.minBarHeight)
                    bar.targetY = (parent.height - bar.height) / 2
                }
                
                Connections {
                    target: root.cavaManager || null
                    function onBarLevelsChanged() {
                        bar.updateAppearance()
                    }
                }
                
                Component.onCompleted: {
                    bar.updateAppearance()
                }
            }
        }
    }
}
