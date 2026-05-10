import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
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

    color: "transparent"

    visible: false
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    Connections {
        target: yuraState
        function onExpandedChanged() {
            if (yuraState.expanded) {
                chatWindow.visible = true
                chatHideTimer.stop()
            } else {
                chatHideTimer.restart()
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

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: yuraState.expanded
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    mask: Region {
        x: chatBox.x
        y: chatBox.y
        width: chatBox.width
        height: chatBox.height
    }

    property bool _sizeReady: false

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

        NumberAnimation {
            id: panelSlideIn
            target: chatBox
            property: "x"
            to: yuraState.panelRestX
            duration: 850
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            id: panelSlideOut
            target: chatBox
            property: "x"
            to: yuraState.panelHiddenX
            duration: 850
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            id: panelFadeIn
            target: chatBox
            property: "opacity"
            to: 1.0
            duration: 700
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            id: panelFadeOut
            target: chatBox
            property: "opacity"
            to: 0
            duration: 700
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
                orbEmptyScale: 0.48
                orbEmptyYRatio: 0.10

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
                PauseAnimation { duration: 250 }
                NumberAnimation { target: orb; property: "expandGate"; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
            }

            NumberAnimation {
                id: orbCloseAnim
                target: orb; property: "expandGate"; to: 0; duration: 750; easing.type: Easing.OutCubic
            }

            Connections {
                target: yuraState
                function onExpandedChanged() {
                    if (yuraState.expanded) {
                        orbCloseAnim.stop()
                        orb.expandGate = 0
                        orbOpenAnim.restart()
                    } else {
                        orbOpenAnim.stop()
                        orbCloseAnim.restart()
                    }
                }
            }

            opacity: yuraState.aiDropdownOpen ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.InOutCubic } }

            scale: 0.4 + expandGate * 0.6
            transformOrigin: Item.Center

            smooth: true
            antialiasing: true

            Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

            Ai.AmbientOrb {
                anchors.fill: parent
                orbColor: chatWindow.theme ? chatWindow.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                showHalo: false
                coreOpacity: 0.6
                corePointCount: 48
                coreWaveAmplitude: 0.5
                idleBreathPeak: 1.20
                idleBreathDuration: 1400
                active: yuraState.expanded
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: yuraState.toggle()
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: (w) => w.accepted = false
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
}
