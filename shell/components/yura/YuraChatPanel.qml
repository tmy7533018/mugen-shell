import QtQuick
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

        UI.MugenSurface {
            anchors.fill: parent
            theme: chatWindow.theme
            gradientEnabled: chatWindow.settingsManager
                ? chatWindow.settingsManager.barGradientEnabled
                : true
            radius: 24
        }

        Loader {
            id: contentLoader
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            asynchronous: true

            property bool everLoaded: false
            active: yuraState.expanded || everLoaded
            onLoaded: everLoaded = true

            sourceComponent: Content.AiAssistantFloatingContent {
                anchors.fill: parent
                modeManager: stubModeManager
                theme: chatWindow.theme
                icons: chatWindow.icons
                aiBackend: chatWindow.aiBackend
                settingsManager: chatWindow.settingsManager
                showInternalOrb: false
                Component.onCompleted: sidebarCollapsed = true
            }
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
