import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    
    property real level: 0.0
    property real levelLow: 0.0
    property real levelMid: 0.0
    property real levelHigh: 0.0
    property bool isActive: level > 0.05
    property real phaseOffset: 0.0
    property Timer phaseTimer: Timer {
        interval: 100
        running: root.isActive || root.level > 0.05
        repeat: true
        onTriggered: {
            root.phaseOffset += 0.2;
            if (root.phaseOffset > Math.PI * 2) root.phaseOffset = 0;
            root.levelLow = Math.max(0, Math.min(1, root.level + Math.sin(root.phaseOffset) * 0.15));
            root.levelMid = Math.max(0, Math.min(1, root.level + Math.sin(root.phaseOffset + Math.PI * 0.66) * 0.15));
            root.levelHigh = Math.max(0, Math.min(1, root.level + Math.sin(root.phaseOffset + Math.PI * 1.33) * 0.15));
        }
    }
}
