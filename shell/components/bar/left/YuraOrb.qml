import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme
import "../../content/ai" as Ai

Item {
    id: root

    property var theme
    property var modeManager
    property var settingsManager
    property bool aiThinking: false
    property bool aiPanelOpen: false
    readonly property bool yuraShown: !root.settingsManager || root.settingsManager.yuraEnabled

    function screenRect() {
        const p = root.mapToItem(null, 0, 0)
        return { x: p.x, y: p.y, size: root.width }
    }

    function scaled(val) {
        if (root.modeManager) return root.modeManager.barScale(val)
        return val
    }

    readonly property bool available: root.yuraShown
    visible: root.available
    implicitWidth: root.scaled(24)
    implicitHeight: root.scaled(24)
    Layout.alignment: Qt.AlignVCenter
    Layout.leftMargin: 0
    Layout.rightMargin: 0

    Ai.AmbientOrb {
        id: aiOrb
        anchors.centerIn: parent
        width: root.scaled(26)
        height: root.scaled(26)
        orbColor: root.theme ? root.theme.glowTertiary : Qt.rgba(0.95, 0.72, 0.74, 0.9)
        streaming: root.aiThinking
        showHalo: true
        haloScale: 1.5
        haloOpacity: aiMouseArea.containsMouse ? 0.7 : 0.45
        coreOpacity: aiMouseArea.containsMouse ? 0.9 : 0.72
        corePointCount: 32
        coreWaveAmplitude: 0.8
        haloPointCount: 24
        haloWaveAmplitude: 1.2
        breathEnabled: root.settingsManager ? root.settingsManager.yuraIdleBreath : true
        active: !root.aiPanelOpen
        scale: aiMouseArea.containsMouse ? 1.08 : 1.0
        opacity: root.aiPanelOpen ? 0 : 1

        Behavior on opacity {
            enabled: aiOrb.opacity < 1
            NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.InOutCubic }
        }
        Behavior on haloOpacity { NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic } }
        Behavior on coreOpacity { NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.Motion.slow; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: aiMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.modeManager) {
                root.modeManager.switchMode("ai")
            }
        }
    }
}
