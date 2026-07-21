import QtQuick
import Quickshell

QtObject {
    id: state

    property bool expanded: false
    property string panelSide: "left"
    property var settingsManager

    function screenByName(name) {
        if (!name || name === "") return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) return Quickshell.screens[i]
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }
    readonly property var boundScreen: screenByName(settingsManager ? settingsManager.displayMonitor : "")

    // Overwritten at runtime by YuraChatPanel.qml once the window is sized;
    // these are only the initial defaults before that happens.
    property int screenWidth: boundScreen ? boundScreen.width : 1920
    property int screenHeight: boundScreen ? boundScreen.height : 1080

    readonly property bool isLeft: panelSide !== "right"

    property int panelWidth: 700
    property int panelHeight: 640
    property int panelMargin: 16

    property bool aiDropdownOpen: false

    property int orbCollapsedSize: 80

    property int sidebarWidth: 200
    property bool sidebarCollapsed: false

    readonly property int mainPaneWidth: panelWidth - (sidebarCollapsed ? 0 : sidebarWidth)
    readonly property int mainPaneHeight: panelHeight

    property real aiOrbX: -1
    property real aiOrbY: -1
    property real aiOrbSize: -1

    // Screen position the bar spotlight orb flew from; -1 = plain open.
    property real flyFromX: -1
    property real flyFromY: -1
    property real flyFromSize: -1
    signal flyRequested()

    readonly property real orbExpandedSize: aiOrbSize > 0
        ? aiOrbSize
        : Math.min(mainPaneWidth, mainPaneHeight) * 0.28

    readonly property int panelRestX: isLeft
        ? panelMargin
        : screenWidth - panelWidth - panelMargin
    readonly property int panelRestY: screenHeight - panelHeight - panelMargin
    readonly property int panelHiddenX: isLeft
        ? -panelWidth - panelMargin
        : screenWidth + panelMargin

    readonly property real orbActiveX: aiOrbX >= 0
        ? 1 + aiOrbX
        : (sidebarCollapsed ? 0 : sidebarWidth) + (mainPaneWidth - orbExpandedSize) / 2
    readonly property real orbActiveY: aiOrbY >= 0
        ? 1 + aiOrbY
        : mainPaneHeight * 0.18

    readonly property real orbX: orbActiveX
    readonly property real orbY: orbActiveY
    readonly property real orbSize: orbExpandedSize

    readonly property real panelX: expanded ? panelRestX : panelHiddenX
    readonly property real panelY: panelRestY
    readonly property real panelOpacity: expanded ? 1.0 : 0.0

    function toggle() { expanded ? close() : open() }
    function open() {
        flyFromX = -1
        flyFromY = -1
        flyFromSize = -1
        expanded = true
    }
    function close()  { expanded = false }

    // Fly coords are set before expanded so onExpandedChanged handlers can
    // tell a flight open from a plain one.
    function toggleFrom(x, y, size) {
        if (expanded) { close(); return }
        flyFromX = x
        flyFromY = y
        flyFromSize = size
        expanded = true
        flyRequested()
    }
}
