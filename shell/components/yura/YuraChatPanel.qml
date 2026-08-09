import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../lib" as Theme
import "../content" as Content
import "../content/ai" as Ai
import "../ui" as UI

PanelWindow {
    id: chatWindow

    required property var yuraState
    required property var theme
    required property var icons
    required property var aiBackend
    required property var settingsManager

    function showConversation(convId) {
        if (contentLoader.item) contentLoader.item.showConversation(convId)
    }

    property bool voiceListening: false
    property bool voiceSpeaking: false

    function setVoiceListening(on) {
        voiceListening = on
        if (on) voiceListeningFailsafe.restart()
        else voiceListeningFailsafe.stop()
    }

    function setVoiceSpeaking(on) {
        voiceSpeaking = on
        if (on) voiceSpeakingFailsafe.restart()
        else voiceSpeakingFailsafe.stop()
    }

    // If yurad dies mid-capture its clearing IPC never arrives.
    Timer {
        id: voiceListeningFailsafe
        interval: 60 * 1000
        onTriggered: chatWindow.voiceListening = false
    }

    // A spoken reply runs minutes at most; past that yurad died mid-turn.
    Timer {
        id: voiceSpeakingFailsafe
        interval: 10 * 60 * 1000
        onTriggered: chatWindow.voiceSpeaking = false
    }

    color: "transparent"

    visible: false
    screen: chatWindow.screenByName(chatWindow.settingsManager ? chatWindow.settingsManager.initialDisplayMonitor : "")

    function screenByName(name) {
        if (!name || name === "") return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) return Quickshell.screens[i]
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    Connections {
        target: yuraState
        function onExpandedChanged() {
            if (yuraState.expanded) {
                chatWindow.visible = true
                chatHideTimer.stop()
                chatWindow.grabWanted = true
                chatWindow.setBarPanelOpen(true)
                if (chatWindow.yuraState.flyFromX < 0) chatWindow.askOrbHome("launch")
            } else {
                chatHideTimer.restart()
                chatWindow.grabWanted = false
            }
        }
    }

    Timer {
        id: chatHideTimer
        interval: 1300
        onTriggered: chatWindow.visible = false
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Ignore, not just reserve none: the window must start at the true screen
    // origin so bar-relative fly coordinates line up, and must not shift when
    // the bar hides under fullscreen.
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    // OnDemand only lets a click focus the panel. The HyprlandFocusGrab below
    // is what holds the keyboard, so an IME switch under follow_mouse can't
    // hand focus to whatever window the cursor sits over.
    WlrLayershell.keyboardFocus: yuraState.expanded
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    // Re-armed by a tap inside the panel (see chatBox). A click outside breaks
    // the grab and onCleared clears this, releasing the keyboard without
    // closing the panel, so it stays usable as a docked sidebar.
    property bool grabWanted: false

    property bool flying: false

    HyprlandFocusGrab {
        windows: [chatWindow]
        active: yuraState.expanded && chatWindow.grabWanted
        onCleared: chatWindow.grabWanted = false
    }

    mask: Region {
        x: chatBox.x
        y: chatBox.y
        width: chatBox.width
        height: chatBox.height
    }

    property bool _sizeReady: false

    // A fresh yura-shell can't be mid-stream, so clear any bar glow left stale
    // by a previous process that died while streaming.
    Component.onCompleted: {
        Theme.Hypr.exec("qs -c mugen-shell ipc call yura set_thinking false")
        chatWindow.setBarPanelOpen(false)
    }

    function setBarPanelOpen(on) {
        Theme.Hypr.exec("qs -c mugen-shell ipc call yura set_panel_open " + (on ? "true" : "false"))
    }

    property string orbHomePurpose: ""

    function askOrbHome(purpose) {
        chatWindow.orbHomePurpose = purpose
        if (!orbHomeProcess.running) orbHomeProcess.running = true
    }

    Process {
        id: orbHomeProcess
        command: ["sh", "-c", "qs -c mugen-shell ipc call yura orb_home"]
        stdout: StdioCollector {
            onStreamFinished: {
                const state = chatWindow.yuraState
                const wantsReturn = chatWindow.orbHomePurpose === "return"
                const parts = this.text.trim().split(/\s+/)
                const x = parts.length === 3 ? parseFloat(parts[0]) : NaN
                const y = parts.length === 3 ? parseFloat(parts[1]) : NaN
                const s = parts.length === 3 ? parseFloat(parts[2]) : NaN
                if (isNaN(x) || isNaN(y) || isNaN(s) || s <= 0) {
                    if (wantsReturn) chatWindow.setBarPanelOpen(false)
                    return
                }
                state.homeX = x
                state.homeY = y
                state.homeSize = s
                if (wantsReturn) chatWindow.startReturnFlight()
                else chatWindow.startLaunchFlight()
            }
        }
    }

    function beginFlight(returning) {
        flyAnim.stop()
        returnAnim.stop()
        flyOrb.returning = returning
        flyOrb.px = 0
        flyOrb.py = 0
        flyOrb.opacity = 1
        flyOrb.shown = true
        chatWindow.flying = true
        if (returning) returnAnim.restart()
        else flyAnim.restart()
    }

    function startReturnFlight() {
        if (chatWindow.yuraState.expanded) return
        chatWindow.beginFlight(true)
    }

    function startLaunchFlight() {
        const state = chatWindow.yuraState
        if (!state.expanded) return
        state.flyFromX = state.homeX
        state.flyFromY = state.homeY
        state.flyFromSize = state.homeSize
        chatWindow.beginFlight(false)
    }

    function syncScreenSize() {
        if (chatWindow.width <= 0 || chatWindow.height <= 0) return
        yuraState.screenWidth = chatWindow.width
        yuraState.screenHeight = chatWindow.height
        if (!chatWindow._sizeReady) {
            chatWindow._sizeReady = true
            if (yuraState.expanded) chatWindow.runOpenAnim()
        }
    }

    function runOpenAnim() {
        panelSlideIn.restart()
        panelFadeIn.restart()
    }

    onWidthChanged: syncScreenSize()
    onHeightChanged: syncScreenSize()

    QtObject {
        id: stubModeManager
        property string currentMode: "ai"
        function scale(v) { return v }
        function bump() {}
        function isMode(name) { return name === "ai" }
        function closeAllModes() { yuraState.close() }
        function registerMode(name, instance) {}
    }

    Item {
        id: chatBox

        y: yuraState.panelRestY
        width: yuraState.panelWidth
        height: yuraState.panelHeight
        opacity: 0
        visible: opacity > 0.01

        Component.onCompleted: x = yuraState.panelHiddenX

        // Re-arms the focus grab so clicking back in after using another window
        // restores keyboard focus. Passive, so taps still reach the input field
        // and buttons underneath.
        TapHandler {
            onPressedChanged: if (pressed) {
                chatWindow.grabWanted = true
                idleCollapse.restart()
            }
        }

        NumberAnimation {
            id: panelSlideIn
            target: chatBox
            property: "x"
            to: yuraState.panelRestX
            duration: Theme.Motion.drift
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            id: panelSlideOut
            target: chatBox
            property: "x"
            to: yuraState.panelHiddenX
            duration: Theme.Motion.drift
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            id: panelFadeIn
            target: chatBox
            property: "opacity"
            to: 1.0
            duration: Theme.Motion.slow
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            id: panelFadeOut
            target: chatBox
            property: "opacity"
            to: 0
            duration: Theme.Motion.slow
            easing.type: Easing.InOutCubic
        }

        Connections {
            target: yuraState
            function onExpandedChanged() {
                if (yuraState.expanded) {
                    panelSlideOut.stop()
                    panelFadeOut.stop()
                    if (chatWindow._sizeReady) chatWindow.runOpenAnim()
                } else {
                    panelSlideIn.stop()
                    panelFadeIn.stop()
                    panelSlideOut.restart()
                    panelFadeOut.restart()
                }
            }
        }

        readonly property int panelRadius: 24

        layer.enabled: true
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: chatBox.width
                height: chatBox.height
                radius: chatBox.panelRadius
            }
        }

        UI.MugenSurface {
            anchors.fill: parent
            theme: chatWindow.theme
            gradientEnabled: chatWindow.settingsManager
                ? chatWindow.settingsManager.barGradientEnabled
                : true
            radius: chatBox.panelRadius
        }

        Loader {
            id: contentLoader
            anchors.fill: parent
            anchors.margins: 1
            asynchronous: true

            property bool everLoaded: false
            active: yuraState.expanded || everLoaded
            onLoaded: everLoaded = true

            sourceComponent: Content.AiAssistantFloatingContent {
                id: aiContent
                anchors.fill: parent
                modeManager: stubModeManager
                theme: chatWindow.theme
                icons: chatWindow.icons
                aiBackend: chatWindow.aiBackend
                settingsManager: chatWindow.settingsManager
                showInternalOrb: false
                voiceListening: chatWindow.voiceListening
                voiceSpeaking: chatWindow.voiceSpeaking
                orbEmptyScale: 0.48
                orbEmptyYRatio: 0.10

                onUserActivity: idleCollapse.restart()

                Component.onCompleted: {
                    if (chatWindow.settingsManager) {
                        sidebarCollapsed = chatWindow.settingsManager.yuraSidebarCollapsed
                    }
                    yuraState.sidebarCollapsed = sidebarCollapsed
                }

                onSidebarCollapsedChanged: {
                    yuraState.sidebarCollapsed = sidebarCollapsed
                    if (chatWindow.settingsManager) {
                        chatWindow.settingsManager.yuraSidebarCollapsed = sidebarCollapsed
                        chatWindow.settingsManager.saveSettings()
                    }
                }
            }
        }

        Binding {
            target: yuraState
            property: "aiOrbX"
            when: contentLoader.item !== null
            value: contentLoader.item ? contentLoader.item.orbExternalX : -1
        }
        Binding {
            target: yuraState
            property: "aiOrbY"
            when: contentLoader.item !== null
            value: contentLoader.item ? contentLoader.item.orbExternalY : -1
        }
        Binding {
            target: yuraState
            property: "aiOrbSize"
            when: contentLoader.item !== null
            value: contentLoader.item ? contentLoader.item.orbExternalSize : -1
        }
        Binding {
            target: yuraState
            property: "aiDropdownOpen"
            when: contentLoader.item !== null
            value: contentLoader.item ? contentLoader.item.modelDropdownOpen : false
        }

        Item {
            id: orb
            x: yuraState.orbX
            y: yuraState.orbY
            width: yuraState.orbSize
            height: yuraState.orbSize
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
                target: yuraState
                function onExpandedChanged() {
                    if (yuraState.expanded) {
                        orbCloseAnim.stop()
                        if (yuraState.flyFromX >= 0) {
                            // The stand-in orb performs the entrance, so the
                            // real one must already be fully grown.
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

            opacity: (yuraState.aiDropdownOpen || chatWindow.flying) ? 0 : 1
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
                orbColor: chatWindow.theme ? chatWindow.theme.glowTertiary : Qt.rgba(0.95, 0.72, 0.74, 0.9)
                showHalo: false
                coreOpacity: 0.6
                corePointCount: 48
                coreWaveAmplitude: 0.5
                idleBreathPeak: 1.20
                idleBreathDuration: 1400
                active: yuraState.expanded
                speaking: chatWindow.voiceSpeaking
                breathEnabled: chatWindow.settingsManager ? chatWindow.settingsManager.yuraIdleBreath : true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                // The orb is invisible but still hit-testable while it flies.
                enabled: !yuraState.aiDropdownOpen && !chatWindow.flying
                onClicked: yuraState.toggle()
            }
        }

        // Not a full-fill hoverEnabled MouseArea: that sits above the content
        // and swallows hover, leaving row hover states dead until a click.
        HoverHandler {
            onPointChanged: idleCollapse.restart()
        }

        Item {
            id: resizeHandle
            width: 18
            height: 18
            z: 20

            anchors.top: parent.top
            anchors.right: yuraState.isLeft ? parent.right : undefined
            anchors.left: yuraState.isLeft ? undefined : parent.left

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: yuraState.isLeft ? Qt.SizeBDiagCursor : Qt.SizeFDiagCursor
                preventStealing: true

                property real pressX: 0
                property real pressY: 0
                property int pressW: 0
                property int pressH: 0

                onPressed: (mouse) => {
                    let p = mapToItem(chatWindow.contentItem, mouse.x, mouse.y)
                    pressX = p.x
                    pressY = p.y
                    pressW = yuraState.panelWidth
                    pressH = yuraState.panelHeight
                }
                onPositionChanged: (mouse) => {
                    if (!pressed || !chatWindow.settingsManager) return
                    let p = mapToItem(chatWindow.contentItem, mouse.x, mouse.y)
                    let dx = p.x - pressX
                    let dy = p.y - pressY
                    let widthSign = yuraState.isLeft ? 1 : -1
                    chatWindow.settingsManager.yuraPanelWidth = Math.max(480, Math.min(1100, pressW + dx * widthSign))
                    chatWindow.settingsManager.yuraPanelHeight = Math.max(480, Math.min(1100, pressH - dy))
                }
                onReleased: {
                    if (chatWindow.settingsManager) chatWindow.settingsManager.saveSettings()
                }
            }
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                yuraState.close()
                event.accepted = true
            }
        }
    }

    Timer {
        id: idleCollapse
        interval: Math.max(1, chatWindow.settingsManager ? chatWindow.settingsManager.yuraAutoCollapseMin : 0) * 60 * 1000
        running: yuraState.expanded
            && (chatWindow.settingsManager ? chatWindow.settingsManager.yuraAutoCollapseMin : 0) > 0
            && !(contentLoader.item && contentLoader.item.streaming)
        onTriggered: yuraState.close()
    }

    // Stand-in orb that flies from the bar spotlight, then crossfades into the
    // real one. Progress-driven bindings, not to:-captured coords, so the
    // target stays live while the async content loader settles the real orb.
    Item {
        id: flyOrb

        property bool shown: false
        property bool returning: false
        property real px: 0
        property real py: 0

        readonly property real targetX: yuraState.panelRestX + yuraState.orbX
        readonly property real targetY: yuraState.panelRestY + yuraState.orbY

        readonly property real originX: returning ? targetX : chatWindow.yuraState.flyFromX
        readonly property real originY: returning ? targetY : chatWindow.yuraState.flyFromY
        readonly property real originSize: returning ? chatWindow.yuraState.orbSize : chatWindow.yuraState.flyFromSize
        readonly property real destX: returning ? chatWindow.yuraState.homeX : targetX
        readonly property real destY: returning ? chatWindow.yuraState.homeY : targetY
        readonly property real destSize: returning ? chatWindow.yuraState.homeSize : chatWindow.yuraState.orbSize

        x: originX + (destX - originX) * px
        y: originY + (destY - originY) * py
        width: originSize + (destSize - originSize) * px
        height: width
        visible: shown
        z: 10

        Ai.AmbientOrb {
            anchors.fill: parent
            orbColor: chatWindow.theme ? chatWindow.theme.glowTertiary : Qt.rgba(0.95, 0.72, 0.74, 0.9)
            showHalo: false
            coreOpacity: 0.6
            corePointCount: 48
            coreWaveAmplitude: 0.5
            active: flyOrb.shown
        }
    }

    SequentialAnimation {
        id: flyAnim

        // x and y easings differ on purpose: it bends the flight path.
        ParallelAnimation {
            NumberAnimation { target: flyOrb; property: "px"; from: 0; to: 1; duration: Theme.Motion.drift; easing.type: Easing.InOutCubic }
            NumberAnimation { target: flyOrb; property: "py"; from: 0; to: 1; duration: Theme.Motion.drift; easing.type: Easing.InOutSine }
        }
        // Must reveal the real orb before the stand-in fades, so its opacity
        // Behavior runs underneath and the swap stays invisible.
        ScriptAction { script: chatWindow.flying = false }
        NumberAnimation { target: flyOrb; property: "opacity"; from: 1; to: 0; duration: Theme.Motion.standard; easing.type: Easing.InOutCubic }
        ScriptAction { script: { flyOrb.shown = false; flyOrb.opacity = 1 } }
    }

    SequentialAnimation {
        id: returnAnim

        ParallelAnimation {
            NumberAnimation { target: flyOrb; property: "px"; from: 0; to: 1; duration: Theme.Motion.drift; easing.type: Easing.InOutCubic }
            NumberAnimation { target: flyOrb; property: "py"; from: 0; to: 1; duration: Theme.Motion.drift; easing.type: Easing.InOutSine }
        }
        ScriptAction { script: chatWindow.setBarPanelOpen(false) }
        NumberAnimation { target: flyOrb; property: "opacity"; from: 1; to: 0; duration: Theme.Motion.standard; easing.type: Easing.InOutCubic }
        ScriptAction { script: { flyOrb.shown = false; flyOrb.opacity = 1; flyOrb.returning = false; chatWindow.flying = false } }
    }

    Connections {
        target: yuraState
        function onFlyRequested() {
            chatWindow.beginFlight(false)
        }
        function onExpandedChanged() {
            if (yuraState.expanded) return
            if (chatWindow.flying) {
                flyAnim.stop()
                flyOrb.shown = false
                flyOrb.opacity = 1
                flyOrb.returning = false
                chatWindow.flying = false
                chatWindow.setBarPanelOpen(false)
                return
            }
            chatWindow.askOrbHome("return")
        }
    }

    // The bar lives in a separate process, so its assistant icon only learns
    // about streaming over IPC.
    Connections {
        target: contentLoader.item
        ignoreUnknownSignals: true
        function onStreamingChanged() {
            Theme.Hypr.exec("qs -c mugen-shell ipc call yura set_thinking "
                + (contentLoader.item.streaming ? "true" : "false"))
        }
    }
}
