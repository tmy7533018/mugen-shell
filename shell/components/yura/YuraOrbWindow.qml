import QtQuick
import Quickshell
import Quickshell.Wayland
import "../content/ai" as Ai

PanelWindow {
    id: orbWindow

    required property var yuraState
    required property var theme

    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
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

    Component.onCompleted: syncScreenSize()
    onWidthChanged: syncScreenSize()
    onHeightChanged: syncScreenSize()

    Item {
        id: orb

        x: yuraState.orbX
        y: yuraState.orbY
        width: yuraState.orbSize
        height: yuraState.orbSize

        Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

        Ai.AmbientOrb {
            anchors.fill: parent
            orbColor: orbWindow.theme ? orbWindow.theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.9)
            haloScale: 1.6
            haloOpacity: 0.5
            active: yuraState.expanded
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: yuraState.toggle()
        }
    }
}
