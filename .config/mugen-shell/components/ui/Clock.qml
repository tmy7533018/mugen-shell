import QtQuick
import Qt5Compat.GraphicalEffects

Text {
    id: clockText
    
    property var theme
    property var typo
    property var modeManager
    property bool showSeconds: false
    property bool isHovered: false
    property color glowColor: Qt.rgba(0.65, 0.55, 0.85, 0.6)
    
    property string timeString: "--:--:--"
    
    text: timeString
    
    // Brighten slightly to compensate for Text rendering appearing darker than icons at the same color
    color: {
        if (theme) {
            let baseColor = theme.textPrimary
            return Qt.rgba(
                Math.min(1.0, baseColor.r * 1.05),
                Math.min(1.0, baseColor.g * 1.05),
                Math.min(1.0, baseColor.b * 1.05),
                baseColor.a
            )
        } else {
            return Qt.rgba(0.96, 0.96, 1.0, 0.90)
        }
    }
    
    font.family: typo ? typo.clockStyle.family : "JetBrainsMono Nerd Font"
    font.pixelSize: modeManager ? modeManager.scale(typo ? typo.clockStyle.size : 14) : (typo ? typo.clockStyle.size : 14)
    font.weight: typo ? (typo.clockStyle.weight > Font.Normal ? typo.clockStyle.weight : Font.Bold) : Font.Bold
    font.letterSpacing: typo ? typo.clockStyle.letterSpacing : 0
    font.hintingPreference: typo ? typo.clockStyle.hinting : Font.PreferDefaultHinting
    font.kerning: typo ? typo.clockStyle.kerning : true
    
    renderType: Text.QtRendering
    smooth: true
    
    // layer.enabled always on; glow visibility controlled via color alpha
    layer.enabled: true
    layer.effect: Glow {
        samples: 20
        radius: 8
        spread: 0.4
        color: (isHovered || isMinuteExpanding) ? glowColor : Qt.rgba(glowColor.r, glowColor.g, glowColor.b, 0)
        transparentBorder: true
        
        Behavior on color {
            ColorAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
    }
    
    property bool isMinuteExpanding: false
    property real minuteScaleFactor: 1.0
    readonly property real minutePulseTargetScale: 1.3
    transformOrigin: Item.Center
    transform: Scale {
        id: minutePulseTransform
        origin.x: clockText.width / 2
        origin.y: clockText.height / 2
        xScale: clockText.minuteScaleFactor
        yScale: clockText.minuteScaleFactor
    }
    
    Timer {
        id: tick
        interval: 1000
        repeat: true
        running: clockText.visible && parent.visible
        onTriggered: {
            const now = new Date();
            let hh = now.getHours().toString().padStart(2, "0");
            let mm = now.getMinutes().toString().padStart(2, "0");
            let ss = now.getSeconds().toString().padStart(2, "0");
            clockText.timeString = showSeconds ? (hh + ":" + mm + ":" + ss) : (hh + ":" + mm);

            if (ss === "59" && !clockText.isMinuteExpanding) {
                clockText.isMinuteExpanding = true;
                clockText.minuteScaleFactor = clockText.computeMinuteScaleFactor();
            } else if (ss === "01" && clockText.isMinuteExpanding) {
                clockText.isMinuteExpanding = false;
                clockText.minuteScaleFactor = 1.0;
            } else if (clockText.isMinuteExpanding && parseInt(ss) >= 2 && parseInt(ss) < 59) {
                // Safety: reset if expansion state lingers outside the 59-01 window
                clockText.isMinuteExpanding = false;
                clockText.minuteScaleFactor = 1.0;
            }
        }
    }
    
    onScaleChanged: {
        if (isMinuteExpanding) {
            minuteScaleFactor = computeMinuteScaleFactor();
        }
    }
    
    Behavior on minuteScaleFactor {
        NumberAnimation {
            duration: 600
            easing.type: Easing.OutCubic
        }
    }
    
    function computeMinuteScaleFactor() {
        const baseScale = clockText.scale > 0 ? clockText.scale : 1.0;
        const desired = minutePulseTargetScale;
        const factor = desired / baseScale;
        return factor < 1.0 ? 1.0 : factor;
    }

    Component.onCompleted: {
        tick.triggered();
    }
}
