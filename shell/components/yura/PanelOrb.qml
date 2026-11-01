import QtQuick
import "../../lib" as Theme
import "../content/ai" as Ai

Item {
    id: orb

    required property var yuraState
    property var theme: null
    property var settingsManager: null
    property bool flying: false

    x: orb.yuraState.orbX
    y: orb.yuraState.orbY
    width: orb.yuraState.orbSize
    height: orb.yuraState.orbSize
    z: 4

    property real expandGate: 0

    SequentialAnimation {
        id: orbOpenAnim
        PauseAnimation { duration: Theme.Motion.fast }
        NumberAnimation { target: orb; property: "expandGate"; to: 1.0; duration: Theme.Motion.drift; easing.type: Easing.InOutSine }
    }

    NumberAnimation {
        id: orbCloseAnim
        target: orb; property: "expandGate"; to: 0; duration: Theme.Motion.drift; easing.type: Easing.OutCubic
    }

    Connections {
        target: orb.yuraState
        function onExpandedChanged() {
            if (orb.yuraState.expanded) {
                orbCloseAnim.stop()
                if (orb.yuraState.flyFromX >= 0) {
                    // The stand-in orb performs the entrance, so the real one must already be grown.
                    orbOpenAnim.stop()
                    orb.expandGate = 1.0
                } else {
                    orb.expandGate = 0
                    orbOpenAnim.restart()
                }
            } else {
                orbOpenAnim.stop()
                orbCloseAnim.restart()
            }
        }
    }

    opacity: (orb.yuraState.aiDropdownOpen || orb.flying) ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.InOutCubic } }

    scale: 0.4 + expandGate * 0.6
    transformOrigin: Item.Center

    smooth: true
    antialiasing: true

    Behavior on x { NumberAnimation { duration: Theme.Motion.slow; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: Theme.Motion.slow; easing.type: Easing.OutCubic } }
    Behavior on width { NumberAnimation { duration: Theme.Motion.slow; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: Theme.Motion.slow; easing.type: Easing.OutCubic } }

    Ai.AmbientOrb {
        anchors.fill: parent
        orbColor: orb.theme ? orb.theme.glowTertiary : Qt.rgba(0.95, 0.72, 0.74, 0.9)
        showHalo: false
        coreOpacity: 0.6
        corePointCount: 48
        coreWaveAmplitude: 0.5
        idleBreathPeak: 1.20
        idleBreathDuration: 1400
        active: orb.yuraState.expanded
        breathEnabled: orb.settingsManager ? orb.settingsManager.yuraIdleBreath : true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // The orb is invisible but still hit-testable while it flies.
        enabled: !orb.yuraState.aiDropdownOpen && !orb.flying
        onClicked: orb.yuraState.toggle()
    }
}
