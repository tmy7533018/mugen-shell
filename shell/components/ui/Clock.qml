import QtQuick
import Qt5Compat.GraphicalEffects
import "../../lib" as Theme

Text {
    id: clockText
    
    property var theme
    property var typo
    property var modeManager
    property bool showSeconds: false
    property bool use24Hour: true
    property bool reduceMotion: false
    property bool isHovered: false
    property color glowColor: Qt.rgba(0.65, 0.55, 0.85, 0.6)
    
    property string timeString: "--:--:--"
    
    text: timeString
    
    // Brightened: Text renders darker than icons at the same color
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
    
    // Stays on and hides the glow via color alpha; toggling layer.enabled
    // instead re-rasterizes the item and pops on every minute change.
    layer.enabled: true
    layer.effect: Glow {
        samples: 20
        radius: 8
        spread: 0.4
        color: isMinuteExpanding ? glowColor : Qt.rgba(glowColor.r, glowColor.g, glowColor.b, 0)
        transparentBorder: true
        
        Behavior on color {
            ColorAnimation {
                duration: Theme.Motion.standard
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
            let hours24 = now.getHours();
            let suffix = "";
            if (!clockText.use24Hour) {
                suffix = hours24 >= 12 ? " PM" : " AM";
                hours24 = hours24 % 12;
                if (hours24 === 0) hours24 = 12;
            }
            let hh = clockText.use24Hour ? hours24.toString().padStart(2, "0") : hours24.toString();
            let mm = now.getMinutes().toString().padStart(2, "0");
            let ss = now.getSeconds().toString().padStart(2, "0");
            clockText.timeString = (showSeconds ? (hh + ":" + mm + ":" + ss) : (hh + ":" + mm)) + suffix;

            if (ss === "59" && !clockText.isMinuteExpanding && !clockText.reduceMotion) {
                clockText.isMinuteExpanding = true;
                clockText.minuteScaleFactor = clockText.computeMinuteScaleFactor();
            } else if (ss === "01" && clockText.isMinuteExpanding) {
                clockText.isMinuteExpanding = false;
                clockText.minuteScaleFactor = 1.0;
            } else if (clockText.isMinuteExpanding && parseInt(ss) >= 2 && parseInt(ss) < 59) {
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
            duration: Theme.Motion.slow
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
