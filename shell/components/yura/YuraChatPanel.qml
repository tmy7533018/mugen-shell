import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
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
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    Connections {
        target: yuraState
        function onExpandedChanged() {
            if (yuraState.expanded) {
                chatWindow.visible = true
                chatHideTimer.stop()
                chatWindow.grabWanted = true
            } else {
                chatHideTimer.restart()
                chatWindow.grabWanted = false
            }
        }
    }

    Timer {
        id: chatHideTimer
        interval: 900
        onTriggered: chatWindow.visible = false
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Ignore other zones (not just reserve none): the window must start at
    // the true screen origin so bar-relative fly coordinates line up, and
    // must not shift when the bar hides under fullscreen.
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    // OnDemand only lets a click focus the panel; the HyprlandFocusGrab
    // below is what actually holds the keyboard while the panel is in use,
    // so an IME switch under follow_mouse can't hand focus to whatever
    // window the cursor sits over.
    WlrLayershell.keyboardFocus: yuraState.expanded
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    // grabWanted drives the focus grab: armed when the panel opens and
    // re-armed by a tap inside it (see chatBox). A click outside breaks the
    // grab — onCleared clears the flag, releasing the keyboard to the
    // clicked window without closing the panel, so it still works as a
    // docked sidebar you click in and out of.
    property bool grabWanted: false

    // True while the stand-in orb is flying in from the bar; hides the real
    // panel orb until the crossfade.
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

    // A fresh yura-shell can't be mid-stream; clear any glow left stale on
    // the bar if the previous process died while streaming.
    Component.onCompleted: Theme.Hypr.exec("qs -c mugen-shell ipc call yura set_thinking false")

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

        // Re-arm the focus grab on any tap inside the panel, so clicking
        // back in after using another window restores keyboard focus here.
        // Passive — it monitors taps without stealing them from the input
        // field or buttons underneath.
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
                            // Flight open: the stand-in orb performs the
                            // entrance, so the real one waits fully grown.
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
                enabled: !yuraState.aiDropdownOpen
                onClicked: yuraState.toggle()
            }
        }

        // Mouse movement counts as activity for the idle auto-collapse. A
        // HoverHandler, not a full-fill hoverEnabled MouseArea: the latter sat
        // above the content and swallowed hover, so row hover states (the
        // Recent list's delete icon) only lit up after a click. HoverHandler
        // is passive and lets hover reach the items below.
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
                    if (!pressed) return
                    let p = mapToItem(chatWindow.contentItem, mouse.x, mouse.y)
                    let dx = p.x - pressX
                    let dy = p.y - pressY
                    let widthSign = yuraState.isLeft ? 1 : -1
                    yuraState.panelWidth = Math.max(480, Math.min(1100, pressW + dx * widthSign))
                    yuraState.panelHeight = Math.max(480, Math.min(1100, pressH - dy))
                }
                onReleased: {
                    if (chatWindow.settingsManager) {
                        chatWindow.settingsManager.yuraPanelWidth = yuraState.panelWidth
                        chatWindow.settingsManager.yuraPanelHeight = yuraState.panelHeight
                        chatWindow.settingsManager.saveSettings()
                    }
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

    // Close the panel after idle minutes (Settings → Yura UI). Streaming
    // pauses the countdown; taps and mouse movement inside restart it.
    Timer {
        id: idleCollapse
        interval: Math.max(1, chatWindow.settingsManager ? chatWindow.settingsManager.yuraAutoCollapseMin : 0) * 60 * 1000
        running: yuraState.expanded
            && (chatWindow.settingsManager ? chatWindow.settingsManager.yuraAutoCollapseMin : 0) > 0
            && !(contentLoader.item && contentLoader.item.streaming)
        onTriggered: yuraState.close()
    }

    // "One orb" illusion: a stand-in orb flies from the bar spotlight's
    // position to the panel orb's spot, then crossfades into the real one.
    // Progress-driven bindings (not to:-captured coords) keep the target
    // live while the async content loader settles the real orb position.
    Item {
        id: flyOrb

        property bool shown: false
        property real px: 0
        property real py: 0

        readonly property real targetX: yuraState.panelRestX + yuraState.orbX
        readonly property real targetY: yuraState.panelRestY + yuraState.orbY

        x: yuraState.flyFromX + (targetX - yuraState.flyFromX) * px
        y: yuraState.flyFromY + (targetY - yuraState.flyFromY) * py
        width: yuraState.flyFromSize + (yuraState.orbSize - yuraState.flyFromSize) * px
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

        // Different x/y easings bend the path slightly so the flight reads
        // as organic rather than a straight interpolation.
        ParallelAnimation {
            NumberAnimation { target: flyOrb; property: "px"; from: 0; to: 1; duration: Theme.Motion.drift; easing.type: Easing.InOutCubic }
            NumberAnimation { target: flyOrb; property: "py"; from: 0; to: 1; duration: Theme.Motion.drift; easing.type: Easing.InOutSine }
        }
        // Reveal the real orb (320ms opacity Behavior) under the fading
        // stand-in; identical geometry makes the swap invisible.
        ScriptAction { script: chatWindow.flying = false }
        NumberAnimation { target: flyOrb; property: "opacity"; from: 1; to: 0; duration: Theme.Motion.standard; easing.type: Easing.InOutCubic }
        ScriptAction { script: { flyOrb.shown = false; flyOrb.opacity = 1 } }
    }

    Connections {
        target: yuraState
        function onFlyRequested() {
            flyAnim.stop()
            flyOrb.opacity = 1
            flyOrb.shown = true
            chatWindow.flying = true
            flyAnim.restart()
        }
        function onExpandedChanged() {
            if (!yuraState.expanded && chatWindow.flying) {
                flyAnim.stop()
                flyOrb.shown = false
                flyOrb.opacity = 1
                chatWindow.flying = false
            }
        }
    }

    // Mirror the float's streaming state to the main shell over IPC so the
    // bar's assistant icon can animate while Yura thinks (separate process).
    Connections {
        target: contentLoader.item
        ignoreUnknownSignals: true
        function onStreamingChanged() {
            Theme.Hypr.exec("qs -c mugen-shell ipc call yura set_thinking "
                + (contentLoader.item.streaming ? "true" : "false"))
        }
    }
}
