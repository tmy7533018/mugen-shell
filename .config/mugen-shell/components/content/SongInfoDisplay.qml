import QtQuick
import QtQuick.Layouts
import "../common" as Common

ColumnLayout {
    id: root
    
    property var musicManager
    property var cavaManager
    property var theme
    required property var modeManager
    property color extractedColor: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)

    spacing: modeManager.scale(4)
    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: modeManager.scale(260)
    
    Item {
        Layout.preferredWidth: modeManager.scale(260)
        Layout.preferredHeight: modeManager.scale(28)
        clip: true
        visible: root.musicManager && root.musicManager.isAvailable
        
        Common.GlowText {
            id: titleText
            // Repeat title 3x for seamless loop scrolling
            text: {
                if (!root.musicManager || root.musicManager.title === "") return ""
                let title = root.musicManager.title
                if (needsScroll) {
                    return title + "    •    " + title + "    •    " + title
                }
                return title
            }
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            font.pixelSize: modeManager.scale(20)
            font.weight: Font.Bold
            
            glowColor: Qt.rgba(root.extractedColor.r, root.extractedColor.g, root.extractedColor.b, 0.45)
            glowRadius: 6
            glowSpread: 0.3
            glowSamples: 13
            enableGlow: true

            property real originalWidth: {
                if (!root.musicManager || root.musicManager.title === "") return 0
                let metrics = Qt.createQmlObject('import QtQuick; TextMetrics {}', titleText)
                metrics.font = titleText.font
                metrics.text = root.musicManager.title
                let w = metrics.width
                metrics.destroy()
                return w
            }
            
            readonly property bool needsScroll: originalWidth > parent.width

            SequentialAnimation on x {
                running: titleText.needsScroll && root.musicManager && root.musicManager.isAvailable
                loops: Animation.Infinite
                
                PauseAnimation { duration: 2500 }

                // Move by 1/3 of total width for a seamless loop
                NumberAnimation {
                    from: 0
                    to: -(titleText.width / 3)
                    duration: Math.max(4000, (titleText.width / 3) * 20)
                    easing.type: Easing.Linear
                }
                
                ScriptAction {
                    script: titleText.x = 0
                }

                PauseAnimation { duration: 2500 }
            }
            
            Behavior on x {
                enabled: !titleText.needsScroll
                NumberAnimation { duration: 300 }
            }
            
            Component.onCompleted: {
                if (!needsScroll) {
                    x = 0
                }
            }
        }
    }
    
    Common.GlowText {
        text: root.musicManager && root.musicManager.artist !== "" ? root.musicManager.artist : ""
        color: root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
        font.pixelSize: modeManager.scale(14)
        font.weight: Font.Bold
        opacity: 0.8
        Layout.maximumWidth: modeManager.scale(260)
        Layout.leftMargin: modeManager.scale(8)
        elide: Text.ElideRight
        visible: root.musicManager && root.musicManager.isAvailable && root.musicManager.artist !== ""
        
        glowColor: Qt.rgba(root.extractedColor.r, root.extractedColor.g, root.extractedColor.b, 0.35)
        glowRadius: 5
        glowSpread: 0.25
        glowSamples: 11
        enableGlow: true
    }

    RowLayout {
        spacing: modeManager.scale(8)
        Layout.alignment: Qt.AlignLeft
        Layout.leftMargin: modeManager.scale(8)
        visible: root.musicManager && root.musicManager.isAvailable
        
        Item {
            Layout.preferredWidth: Math.max(playingText.implicitWidth, pausedText.implicitWidth, stoppedText.implicitWidth)
            Layout.preferredHeight: modeManager.scale(14)
            
            Common.GlowText {
                id: playingText
                text: "󰽴 Playing"
                color: root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
                font.pixelSize: modeManager.scale(11)
                font.weight: Font.Bold
                opacity: root.musicManager && root.musicManager.status === "Playing" ? 0.6 : 0
                visible: opacity > 0
                
                glowColor: Qt.rgba(root.extractedColor.r, root.extractedColor.g, root.extractedColor.b, 0.3)
                glowRadius: 4
                glowSpread: 0.2
                glowSamples: 9
                enableGlow: true
                
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
            }
            
            Common.GlowText {
                id: pausedText
                text: "󰽳 Paused"
                color: root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
                font.pixelSize: modeManager.scale(11)
                font.weight: Font.Bold
                opacity: root.musicManager && root.musicManager.status === "Paused" ? 0.6 : 0
                visible: opacity > 0
                
                glowColor: Qt.rgba(root.extractedColor.r, root.extractedColor.g, root.extractedColor.b, 0.3)
                glowRadius: 4
                glowSpread: 0.2
                glowSamples: 9
                enableGlow: true
                
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
            }
            
            Common.GlowText {
                id: stoppedText
                text: "󰽳 Stopped"
                color: root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
                font.pixelSize: modeManager.scale(11)
                font.weight: Font.Bold
                opacity: root.musicManager && root.musicManager.status === "Stopped" ? 0.6 : 0
                visible: opacity > 0
                
                glowColor: Qt.rgba(root.extractedColor.r, root.extractedColor.g, root.extractedColor.b, 0.3)
                glowRadius: 4
                glowSpread: 0.2
                glowSamples: 9
                enableGlow: true
                
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
            }
            
        }
        
        Item { Layout.preferredWidth: modeManager.scale(12) }
        
        Common.BarVisualizer {
            cavaManager: root.cavaManager
            barCount: 6
            barWidth: modeManager.scale(3)
            barSpacing: modeManager.scale(3)
            minBarHeight: modeManager.scale(6)
            maxBarHeight: modeManager.scale(28)
            maxHeightMultipliers: [0.6, 0.8, 1.0, 1.0, 0.8, 0.6]
            barColor: Qt.rgba(root.extractedColor.r, root.extractedColor.g, root.extractedColor.b, 0.8)
            baseColor: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.85)
            visible: root.cavaManager
            Layout.alignment: Qt.AlignVCenter
        }
    }
}

