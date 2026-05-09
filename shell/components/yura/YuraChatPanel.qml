import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import "../content" as Content
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
        interval: 650
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

        x: yuraState.panelX
        y: yuraState.panelY
        width: yuraState.panelWidth
        height: yuraState.panelHeight
        opacity: yuraState.panelOpacity
        visible: opacity > 0.01

        Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.InOutCubic } }
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }

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
                onSidebarCollapsedChanged: yuraState.sidebarCollapsed = sidebarCollapsed
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

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: (w) => w.accepted = false
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                yuraState.close()
                event.accepted = true
            }
        }
    }
}
