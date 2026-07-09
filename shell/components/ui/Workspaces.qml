import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../lib" as Theme
import "../common" as Common

Item {
    id: workspacesRoot

    property color activeColor: Qt.rgba(0.65, 0.55, 0.85, 0.9)
    property color hasWindowsColor: Qt.rgba(0.93, 0.75, 0.57, 0.85)
    property color emptyColor: Qt.rgba(0.85, 0.85, 0.85, 0.95)

    property var existingWorkspaces: []

    property int activeWorkspaceId: {
        if (!Hyprland.focusedWorkspace) return 1
        let id = Hyprland.focusedWorkspace.id
        if (id < 1) return 1
        if (id > 5) return 5
        return id
    }

    property var modeManager: null

    function scaled(val) {
        if (modeManager) return modeManager.scale(val)
        return val
    }

    implicitWidth: scaled(230)
    implicitHeight: scaled(24)

    function updateWorkspaces() {
        workspacesProc.running = true;
    }

    Process {
        id: workspacesProc
        command: ["bash", "-c", "hyprctl workspaces | awk '/^workspace ID/ {id=$3} /windows:/ {if ($2 > 0) print id}'"]
        running: false

        property var ids: []

        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim();
                if (trimmed.length > 0) {
                    let id = parseInt(trimmed);
                    if (!isNaN(id) && workspacesProc.ids.indexOf(id) === -1) {
                        workspacesProc.ids.push(id);
                    }
                }
            }
        }

        onExited: () => {
            workspacesRoot.existingWorkspaces = workspacesProc.ids;
            workspacesProc.ids = [];
        }
    }

    Connections {
        target: Hyprland

        function onFocusedWorkspaceChanged() {
            if (workspacesRoot.visible && parent.visible) {
                workspaceDebounceTimer.restart()
            }
        }
    }

    property Process hyprlandIpcMonitor: Process {
        id: ipcMonitor

        command: [
            "python3",
            Quickshell.shellDir + "/scripts/hyprland_ipc_monitor.py"
        ]

        running: workspacesRoot.visible && parent.visible

        stdout: SplitParser {
            onRead: data => {
                if (data.trim().length > 0) {
                    workspaceDebounceTimer.restart()
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {
            }
        }

        onExited: {
            if (workspacesRoot.visible && parent.visible && exitCode !== 0) {
                restartTimer.restart()
            }
        }
    }

    property Timer restartTimer: Timer {
        interval: 2000
        repeat: false
        onTriggered: {
            if (workspacesRoot.visible && parent.visible) {
                hyprlandIpcMonitor.running = true
            }
        }
    }

    property Timer workspaceDebounceTimer: Timer {
        interval: 200
        repeat: false
        onTriggered: {
            if (workspacesRoot.visible && parent.visible && !workspacesProc.running) {
                workspacesRoot.updateWorkspaces();
            }
        }
    }

    Item {
        id: activeSmokeContainer
        anchors.fill: parent

        property real targetX: {
            if (!Hyprland.focusedWorkspace) return scaled(25);
            let wsId = Hyprland.focusedWorkspace.id;
            if (wsId < 1 || wsId > 5) return scaled(25);
            return scaled(25) + (wsId - 1) * scaled(45);
        }

        property real currentX: scaled(25)
        property real previousX: scaled(25)
        property bool isMoving: false

        property real brightnessBoost: 0.0

        Behavior on currentX {
            NumberAnimation {
                id: moveAnimation
                duration: Theme.Motion.slow
                easing.type: Easing.OutBack
                easing.overshoot: 1.2

                onRunningChanged: {
                    activeSmokeContainer.isMoving = running;
                    if (running) {
                        brightnessAnimation.stop();
                        activeSmokeContainer.brightnessBoost = 0.0;
                        brightnessAnimation.start();
                    }
                }
            }
        }

        onTargetXChanged: {
            // Only update previousX when not already animating to get correct trail origin.
            if (!moveAnimation.running) {
                previousX = currentX;
            }
            currentX = targetX;
        }

        SequentialAnimation {
            id: brightnessAnimation
            NumberAnimation {
                target: activeSmokeContainer
                property: "brightnessBoost"
                to: 1.0
                duration: Theme.Motion.micro
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: activeSmokeContainer
                property: "brightnessBoost"
                to: 0.0
                duration: Theme.Motion.slow
                easing.type: Easing.InOutCubic
            }
        }

        Item {
            id: trailEffect
            anchors.fill: parent
            visible: activeSmokeContainer.isMoving
            opacity: activeSmokeContainer.isMoving ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.Motion.gentle
                    easing.type: Easing.InOutCubic
                }
            }

            Repeater {
                model: 2

                Item {
                    id: trailBlobLayer

                    width: scaled(35)
                    height: scaled(35)

                    x: activeSmokeContainer.previousX - width / 2
                    y: parent.height / 2 - height / 2

                    opacity: 0.5 - index * 0.25

                    Common.BlobEffect {
                        anchors.fill: parent
                        layers: 1
                        blobColor: workspacesRoot.activeColor
                        baseOpacity: 0.85 - index * 0.25
                        waveAmplitude: scaled(2) + index * scaled(2.0)
                        animationSpeed: 0.08 + index * 0.15
                        running: trailEffect.visible
                    }
                }
            }
        }

        Repeater {
            model: 3

            Item {
                id: blobLayer

                width: scaled(46)
                height: scaled(46)

                x: activeSmokeContainer.currentX - width / 2
                y: parent.height / 2 - height / 2

                property real layerScale: 1.0

                property real pulseScale: 1.0

                // A binding (not cached) so theme changes and the transient
                // brightnessBoost both propagate to the blob live.
                readonly property color layerColor: {
                    var ac = workspacesRoot.activeColor
                    var base
                    if (index === 0) base = ac
                    else if (index === 1) base = Qt.rgba(ac.r * 0.9, ac.g * 1.05, ac.b * 0.95, 1.0)
                    else base = Qt.rgba(ac.r * 1.05, ac.g * 0.95, ac.b * 1.1, 1.0)
                    var boost = activeSmokeContainer.brightnessBoost
                    return Qt.rgba(Math.min(1.0, base.r + boost * 0.3),
                                   Math.min(1.0, base.g + boost * 0.3),
                                   Math.min(1.0, base.b + boost * 0.3), 1.0)
                }

                SequentialAnimation on pulseScale {
                    loops: Animation.Infinite
                    running: !activeSmokeContainer.isMoving

                    NumberAnimation {
                        to: 1.3
                        duration: 1400 + index * 200
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1.0
                        duration: 1400 + index * 200
                        easing.type: Easing.InOutSine
                    }
                }

                transform: Scale {
                    origin.x: blobLayer.width / 2
                    origin.y: blobLayer.height / 2
                    xScale: blobLayer.layerScale * blobLayer.pulseScale
                    yScale: blobLayer.layerScale * blobLayer.pulseScale
                }

                opacity: activeSmokeContainer.isMoving ?
                    (0.5 - index * 0.1) :
                    (0.85 - index * 0.12 + activeSmokeContainer.brightnessBoost * 0.15)

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.Motion.fast
                        easing.type: Easing.InOutQuad
                    }
                }

                Connections {
                    target: activeSmokeContainer
                    function onIsMovingChanged() {
                        layerShrinkAnimation.stop();
                        layerExpandAnimation.stop();
                        layerShrinkTimer.stop();
                        layerExpandTimer.stop();

                        if (activeSmokeContainer.isMoving) {
                            layerShrinkAnimation.from = blobLayer.layerScale;
                            layerShrinkAnimation.to = 0.50;
                            layerShrinkTimer.start();
                        } else {
                            layerExpandAnimation.from = blobLayer.layerScale;
                            layerExpandAnimation.to = 1.0;
                            layerExpandTimer.start();
                        }
                    }

                    function onTargetXChanged() {
                        // Stop in-flight scale animations on workspace change to avoid visual glitches
                        // during rapid switching while expand/shrink is still running
                        if (layerExpandAnimation.running || layerShrinkAnimation.running) {
                            layerShrinkAnimation.stop();
                            layerExpandAnimation.stop();
                            layerShrinkTimer.stop();
                            layerExpandTimer.stop();

                            if (activeSmokeContainer.isMoving) {
                                layerShrinkAnimation.from = blobLayer.layerScale;
                                layerShrinkAnimation.to = 0.50;
                                layerShrinkAnimation.start();
                            } else {
                                layerExpandAnimation.from = blobLayer.layerScale;
                                layerExpandAnimation.to = 1.0;
                                layerExpandAnimation.start();
                            }
                        }
                    }
                }

                Timer {
                    id: layerShrinkTimer
                    interval: index * 30
                    running: false
                    repeat: false
                    onTriggered: {
                        layerShrinkAnimation.start();
                    }
                }

                NumberAnimation {
                    id: layerShrinkAnimation
                    target: blobLayer
                    property: "layerScale"
                    from: blobLayer.layerScale
                    to: 0.50
                    duration: Theme.Motion.fast
                    easing.type: Easing.InCubic
                }

                Timer {
                    id: layerExpandTimer
                    interval: 50 + index * 60
                    running: false
                    repeat: false
                    onTriggered: {
                        layerExpandAnimation.start();
                    }
                }

                NumberAnimation {
                    id: layerExpandAnimation
                    target: blobLayer
                    property: "layerScale"
                    from: blobLayer.layerScale
                    to: 1.0
                    duration: 450
                    easing.type: Easing.OutElastic
                    easing.amplitude: 1.15
                    easing.period: 0.4
                }

                Common.BlobEffect {
                    anchors.fill: parent
                    layers: 1
                    blobColor: blobLayer.layerColor
                    baseOpacity: 0.9 - index * 0.12
                    waveAmplitude: scaled(2) + index * scaled(2.0)
                    // Speed coefficient matches the inactive blobs so the
                    // active and idle rings never drift out of phase.
                    animationSpeed: 0.08 + index * 0.15 + workspacesRoot.activeWorkspaceId * 0.015
                    running: workspacesRoot.visible
                }
            }
        }
    }

    Repeater {
        model: 5

        Item {
            id: inactiveSmokeContainer
            anchors.fill: parent

            property int workspaceId: index + 1
            property bool isActive: {
                if (!Hyprland.focusedWorkspace) return false;
                return workspaceId === Hyprland.focusedWorkspace.id;
            }
            property bool hasWindows: workspacesRoot.existingWorkspaces.indexOf(workspaceId) !==-1

            opacity: isActive ? 0.0 : 1.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.Motion.drift
                    easing.type: Easing.InOutCubic
                }
            }

            property real smokeX: scaled(25) + (workspaceId - 1) * scaled(45)

            property color smokeColor: hasWindows ? workspacesRoot.hasWindowsColor : workspacesRoot.emptyColor

            Repeater {
                model: 2

                Item {
                    id: smallBlobLayer

                    width: scaled(35)
                    height: scaled(35)

                    x: inactiveSmokeContainer.smokeX - width / 2
                    y: parent.height / 2 - height / 2

                    opacity: 0.85 - index * 0.15

                    property real pulseScale: 1.0

                    SequentialAnimation on pulseScale {
                        loops: Animation.Infinite
                        running: workspacesRoot.visible && parent.visible

                        NumberAnimation {
                            to: 1.5
                            duration: 2000 + (inactiveSmokeContainer.workspaceId * 150) + index * 250
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 1.0
                            duration: 2000 + (inactiveSmokeContainer.workspaceId * 150) + index * 250
                            easing.type: Easing.InOutSine
                        }
                    }

                    transform: Scale {
                        origin.x: smallBlobLayer.width / 2
                        origin.y: smallBlobLayer.height / 2
                        xScale: smallBlobLayer.pulseScale
                        yScale: smallBlobLayer.pulseScale
                    }

                    Common.BlobEffect {
                        anchors.fill: parent
                        layers: 1
                        blobColor: inactiveSmokeContainer.smokeColor
                        baseOpacity: (inactiveSmokeContainer.hasWindows ? 0.72 : 0.58) - index * 0.12
                        waveAmplitude: scaled(2) + index * scaled(2.0)
                        animationSpeed: 0.08 + index * 0.15 + inactiveSmokeContainer.workspaceId * 0.015
                        running: inactiveSmokeContainer.visible
                    }
                }
            }
        }
    }

    Repeater {
        model: 5

        MouseArea {
            property int workspaceId: index + 1
            x: scaled(25) + (workspaceId - 1) * scaled(45) - scaled(15)
            y: 0
            width: scaled(30)
            height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Hyprland.dispatch("workspace " + workspaceId);
                workspacesRoot.updateWorkspaces();
            }
        }
    }

    Component.onCompleted: {
        updateWorkspaces();
    }
}
