import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../content/ai" as Ai

PanelWindow {
    id: orbWindow

    required property var yuraState
    required property var theme
    property var settingsManager

    color: "transparent"
    visible: false
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    readonly property var hyprMonitor: orbWindow.screen
        ? Hyprland.monitorFor(orbWindow.screen)
        : null
    readonly property bool fullscreenActive: hyprMonitor && hyprMonitor.activeWorkspace
        ? hyprMonitor.activeWorkspace.hasFullscreen
        : false

    onFullscreenActiveChanged: {
        if (yuraState.expanded) return
        if (fullscreenActive) {
            hideTimer.stop()
        } else {
            orbWindow.visible = true
            orb.restOpacity = 1
            scheduleHide()
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        x: orb.x
        y: orb.y
        width: orb.width
        height: orb.height
    }

    function syncScreenSize() {
        yuraState.screenWidth = orbWindow.width
        yuraState.screenHeight = orbWindow.height
    }

    onWidthChanged: syncScreenSize()
    onHeightChanged: syncScreenSize()

    // Show the orb at session start so the user gets a "hi, I'm here"
    // moment, then run the same rest-then-unmap path a normal close
    // would take. yuraOrbRestSeconds === 0 means "stay forever", so we
    // keep it visible without scheduling a hide.
    Component.onCompleted: {
        orbWindow.visible = true
        scheduleHide()
    }

    function scheduleHide() {
        if (orbWindow.settingsManager && orbWindow.settingsManager.yuraOrbRestSeconds <= 0) {
            hideTimer.stop()
            return
        }
        hideTimer.restart()
    }

    // Rest behaviour: keep the orb visible (and animating) for 5 seconds
    // after the panel collapses, then fade it out and unmap the surface
    // so the compositor isn't asked to manage a transparent fullscreen
    // layer for an idle orb. Toggling open inside that 5s window stops
    // the timer immediately.
    Timer {
        id: hideTimer
        interval: orbWindow.settingsManager
            ? Math.max(1000, orbWindow.settingsManager.yuraOrbRestSeconds * 1000)
            : 5000
        onTriggered: orb.restOpacity = 0
    }

    Connections {
        target: yuraState
        function onExpandedChanged() {
            if (yuraState.expanded) {
                hideTimer.stop()
                orbWindow.visible = true
                orb.restOpacity = 1
            } else {
                orbWindow.scheduleHide()
            }
        }
    }

    // If the user flips the rest setting to "Always" while the orb is
    // mid-fade or already hidden, bring it back and stop the timer.
    Connections {
        target: orbWindow.settingsManager
        ignoreUnknownSignals: true
        function onYuraOrbRestSecondsChanged() {
            if (!orbWindow.settingsManager) return
            if (orbWindow.settingsManager.yuraOrbRestSeconds <= 0) {
                hideTimer.stop()
                orbWindow.visible = true
                orb.restOpacity = 1
            }
        }
    }

    Item {
        id: orb

        x: yuraState.orbX
        y: yuraState.orbY
        width: yuraState.orbSize
        height: yuraState.orbSize

        property real restOpacity: 1
        opacity: restOpacity
            * (yuraState.aiDropdownOpen ? 0 : 1)
            * (orbWindow.fullscreenActive && !yuraState.expanded ? 0 : 1)

        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutCubic } }

        onOpacityChanged: if (opacity < 0.01 && orb.restOpacity < 0.01 && !yuraState.expanded) orbWindow.visible = false

        smooth: true
        antialiasing: true
        layer.enabled: true
        layer.smooth: true

        Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

        Ai.AmbientOrb {
            anchors.fill: parent
            orbColor: orbWindow.theme ? orbWindow.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.9)
            showHalo: false
            coreOpacity: 0.6
            // Stop the pulse the moment we start hiding (fullscreen kicks in
            // or panel collapses) so the orb fades out cleanly instead of
            // visibly throbbing on the way down.
            active: orbWindow.visible && !(orbWindow.fullscreenActive && !yuraState.expanded)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: yuraState.toggle()
        }
    }
}
