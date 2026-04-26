import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

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
                duration: 700
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
            // Behavior automatically animates from current position to new position.
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
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: activeSmokeContainer
                property: "brightnessBoost"
                to: 0.0
                duration: 600
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
                    duration: 400
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

                    Canvas {
                        id: trailBlobCanvas
                        anchors.fill: parent

                        property int pointCount: 16
                        property var offsets: []
                        property real waveAmplitude: scaled(2) + index * scaled(2.0)

                        Component.onCompleted: {
                            offsets = [];
                            for (let i = 0; i < pointCount; i++) {
                                offsets.push(Math.random() * Math.PI * 2);
                            }
                            requestPaint();
                        }

                        Connections {
                            target: workspacesRoot
                            function onActiveColorChanged() {
                                trailBlobCanvas.requestPaint()
                            }
                        }

                        onPaint: {
                            let ctx = getContext("2d");
                            ctx.reset();

                            if (width <= 0 || height <= 0) return;

                            let centerX = width / 2;
                            let centerY = height / 2;
                            let baseRadius = Math.min(width, height) / 2 - waveAmplitude * 2;

                            if (baseRadius <= 0 || !isFinite(baseRadius)) return;

                            ctx.beginPath();

                            for (let i = 0; i <= pointCount; i++) {
                                let angle = (i / pointCount) * Math.PI * 2;
                                let waveOffset = Math.sin(offsets[i % pointCount]) * waveAmplitude;
                                let radius = baseRadius + waveOffset;
                                let x = centerX + Math.cos(angle) * radius;
                                let y = centerY + Math.sin(angle) * radius;

                                if (i === 0) {
                                    ctx.moveTo(x, y);
                                } else {
                                    ctx.lineTo(x, y);
                                }
                            }

                            ctx.closePath();

                            let gradient = ctx.createRadialGradient(
                                centerX, centerY, 0,
                                centerX, centerY, baseRadius
                            );
                            gradient.addColorStop(0, Qt.rgba(
                                workspacesRoot.activeColor.r,
                                workspacesRoot.activeColor.g,
                                workspacesRoot.activeColor.b,
                                0.6 - index * 0.2
                            ));
                            gradient.addColorStop(1, Qt.rgba(
                                workspacesRoot.activeColor.r,
                                workspacesRoot.activeColor.g,
                                workspacesRoot.activeColor.b,
                                0
                            ));

                            ctx.fillStyle = gradient;
                            ctx.fill();
                        }

                        Timer {
                            interval: 150
                            running: trailEffect.visible
                            repeat: true
                            onTriggered: {
                                for (let i = 0; i < trailBlobCanvas.pointCount; i++) {
                                    trailBlobCanvas.offsets[i] += (0.08 + index * 0.15) * 2;
                                }
                                trailBlobCanvas.requestPaint();
                            }
                        }
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
                        duration: 200
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
                    duration: 200
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

                Canvas {
                    id: blobCanvas
                    anchors.fill: parent

                    property int pointCount: 16
                    property var offsets: []
                    property real waveAmplitude: scaled(2) + index * scaled(2.0)

                    property color _cachedBlobColor: Qt.rgba(0, 0, 0, 0)
                    property color _lastActiveColor: Qt.rgba(0, 0, 0, 0)
                    property real _lastBrightnessBoost: -1

                    function calculateBlobColor() {
                        let baseColor;
                        if (index === 0) baseColor = workspacesRoot.activeColor;
                        else if (index === 1) baseColor = Qt.rgba(
                            workspacesRoot.activeColor.r * 0.9,
                            workspacesRoot.activeColor.g * 1.05,
                            workspacesRoot.activeColor.b * 0.95,
                            1.0
                        );
                        else if (index === 2) baseColor = Qt.rgba(
                            workspacesRoot.activeColor.r * 1.05,
                            workspacesRoot.activeColor.g * 0.95,
                            workspacesRoot.activeColor.b * 1.1,
                            1.0
                        );
                        else baseColor = Qt.rgba(
                            workspacesRoot.activeColor.r * 0.95,
                            workspacesRoot.activeColor.g * 0.9,
                            workspacesRoot.activeColor.b * 1.05,
                            1.0
                        );

                        let boost = activeSmokeContainer.brightnessBoost;
                        return Qt.rgba(
                            Math.min(1.0, baseColor.r + boost * 0.3),
                            Math.min(1.0, baseColor.g + boost * 0.3),
                            Math.min(1.0, baseColor.b + boost * 0.3),
                            1.0
                        );
                    }

                    function updateBlobColor() {
                        if (_lastActiveColor !== workspacesRoot.activeColor ||
                            _lastBrightnessBoost !== activeSmokeContainer.brightnessBoost) {
                            _cachedBlobColor = calculateBlobColor()
                            _lastActiveColor = workspacesRoot.activeColor
                            _lastBrightnessBoost = activeSmokeContainer.brightnessBoost
                            blobCanvas.requestPaint()
                        }
                    }

                    property color blobColor: _cachedBlobColor

                    Connections {
                        target: workspacesRoot
                        function onActiveColorChanged() {
                            blobCanvas.updateBlobColor()
                        }
                    }

                    Connections {
                        target: activeSmokeContainer
                        function onBrightnessBoostChanged() {
                            blobCanvas.updateBlobColor()
                        }
                    }

                    Component.onCompleted: {
                        offsets = [];
                        for (let i = 0; i < pointCount; i++) {
                            offsets.push(Math.random() * Math.PI * 2);
                        }
                        _lastActiveColor = workspacesRoot.activeColor
                        _lastBrightnessBoost = activeSmokeContainer.brightnessBoost
                        _cachedBlobColor = calculateBlobColor()
                        requestPaint();
                    }

                    onPaint: {
                        let ctx = getContext("2d");
                        ctx.reset();

                        if (width <= 0 || height <= 0) return;

                        let centerX = width / 2;
                        let centerY = height / 2;
                        let baseRadius = Math.min(width, height) / 2 - waveAmplitude * 2;

                        if (baseRadius <= 0 || !isFinite(baseRadius)) return;

                        ctx.beginPath();

                        for (let i = 0; i <= pointCount; i++) {
                            let angle = (i / pointCount) * Math.PI * 2;
                            let waveOffset = Math.sin(offsets[i % pointCount]) * waveAmplitude;
                            let radius = baseRadius + waveOffset;

                            let x = centerX + Math.cos(angle) * radius;
                            let y = centerY + Math.sin(angle) * radius;

                            if (i === 0) {
                                ctx.moveTo(x, y);
                            } else {
                                ctx.lineTo(x, y);
                            }
                        }

                        ctx.closePath();

                        let gradient = ctx.createRadialGradient(
                            centerX, centerY, 0,
                            centerX, centerY, baseRadius
                        );
                        gradient.addColorStop(0, Qt.rgba(
                            blobColor.r,
                            blobColor.g,
                            blobColor.b,
                            0.7 - index * 0.12
                        ));
                        gradient.addColorStop(1, Qt.rgba(
                            blobColor.r,
                            blobColor.g,
                            blobColor.b,
                            0
                        ));

                        ctx.fillStyle = gradient;
                        ctx.fill();
                    }

                    Timer {
                        interval: 150
                        running: workspacesRoot.visible && parent.visible
                        repeat: true
                        onTriggered: {
                            // Match speed coefficient with inactive blobs to prevent visual drift
                            for (let i = 0; i < blobCanvas.pointCount; i++) {
                                blobCanvas.offsets[i] += (0.08 + index * 0.15 + (workspacesRoot.activeWorkspaceId * 0.015)) * 2;
                            }
                            blobCanvas.requestPaint();
                        }
                    }
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
                    duration: 800
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

                    Canvas {
                        id: smallBlobCanvas
                        anchors.fill: parent

                        property int pointCount: 12
                        property var offsets: []
                        property real waveAmplitude: scaled(2) + index * scaled(2.0)

                        Component.onCompleted: {
                            offsets = [];
                            for (let i = 0; i < pointCount; i++) {
                                offsets.push(Math.random() * Math.PI * 2);
                            }
                            requestPaint();
                        }

                        onPaint: {
                            let ctx = getContext("2d");
                            ctx.reset();

                            if (width <= 0 || height <= 0) return;

                            let centerX = width / 2;
                            let centerY = height / 2;
                            let baseRadius = Math.min(width, height) / 2 - waveAmplitude * 2;

                            if (baseRadius <= 0 || !isFinite(baseRadius)) return;

                            ctx.beginPath();

                            for (let i = 0; i <= pointCount; i++) {
                                let angle = (i / pointCount) * Math.PI * 2;
                                let waveOffset = Math.sin(offsets[i % pointCount]) * waveAmplitude;
                                let radius = baseRadius + waveOffset;

                                let x = centerX + Math.cos(angle) * radius;
                                let y = centerY + Math.sin(angle) * radius;

                                if (i === 0) {
                                    ctx.moveTo(x, y);
                                } else {
                                    ctx.lineTo(x, y);
                                }
                            }

                            ctx.closePath();

                            let gradient = ctx.createRadialGradient(
                                centerX, centerY, 0,
                                centerX, centerY, baseRadius
                            );
                            gradient.addColorStop(0, Qt.rgba(
                                inactiveSmokeContainer.smokeColor.r,
                                inactiveSmokeContainer.smokeColor.g,
                                inactiveSmokeContainer.smokeColor.b,
                                inactiveSmokeContainer.hasWindows ? 0.5 - index * 0.12 : 0.4 - index * 0.12
                            ));
                            gradient.addColorStop(1, Qt.rgba(
                                inactiveSmokeContainer.smokeColor.r,
                                inactiveSmokeContainer.smokeColor.g,
                                inactiveSmokeContainer.smokeColor.b,
                                0
                            ));

                            ctx.fillStyle = gradient;
                            ctx.fill();
                        }

                        Timer {
                            interval: 150
                            running: inactiveSmokeContainer.visible
                            repeat: true
                            onTriggered: {
                                for (let i = 0; i < smallBlobCanvas.pointCount; i++) {
                                    smallBlobCanvas.offsets[i] += (0.08 + index * 0.15 + (workspaceId * 0.015)) * 2;
                                }
                                smallBlobCanvas.requestPaint();
                            }
                        }
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
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    // Open window-switcher with viaIpc=true for reliable keyboard focus
                    if (workspacesRoot.modeManager) {
                        workspacesRoot.modeManager.switchMode("window-switcher", true)
                    }
                    return
                }

                Hyprland.dispatch("workspace " + workspaceId);
                workspacesRoot.updateWorkspaces();
            }
        }
    }

    Component.onCompleted: {
        updateWorkspaces();
    }
}
