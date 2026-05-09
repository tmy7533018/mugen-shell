import QtQuick

QtObject {
    id: state

    property bool expanded: false
    property string panelSide: "left"

    property int screenWidth: 1920
    property int screenHeight: 1080

    readonly property bool isLeft: panelSide !== "right"

    property int panelWidth: 620
    property int panelHeight: 640
    property int panelMargin: 16

    property int orbCollapsedSize: 56

    property int sidebarWidth: 200
    property bool sidebarCollapsed: false

    readonly property int mainPaneWidth: panelWidth - (sidebarCollapsed ? 0 : sidebarWidth)
    readonly property int mainPaneHeight: panelHeight

    // AI-content-driven orb target. <0 means fall back to the empty-state
    // geometry below (useful before the chat content has loaded or while
    // the panel is collapsed and the AI tree hasn't been instantiated).
    property real aiOrbX: -1
    property real aiOrbY: -1
    property real aiOrbSize: -1

    readonly property real orbExpandedSize: aiOrbSize > 0
        ? aiOrbSize
        : Math.min(mainPaneWidth, mainPaneHeight) * 0.28

    readonly property int panelRestX: isLeft
        ? panelMargin
        : screenWidth - panelWidth - panelMargin
    readonly property int panelRestY: screenHeight - panelHeight - panelMargin
    readonly property int panelHiddenX: isLeft
        ? -panelWidth
        : screenWidth

    readonly property real orbRestX: isLeft
        ? panelMargin
        : screenWidth - orbCollapsedSize - panelMargin
    readonly property real orbRestY: screenHeight - orbCollapsedSize - panelMargin

    readonly property real orbActiveX: aiOrbX >= 0
        ? panelRestX + 1 + aiOrbX
        : (isLeft
            ? panelRestX + (sidebarCollapsed ? 0 : sidebarWidth) + (mainPaneWidth - orbExpandedSize) / 2
            : panelRestX + (mainPaneWidth - orbExpandedSize) / 2)
    readonly property real orbActiveY: aiOrbY >= 0
        ? panelRestY + 1 + aiOrbY
        : panelRestY + mainPaneHeight * 0.18

    readonly property real orbX: expanded ? orbActiveX : orbRestX
    readonly property real orbY: expanded ? orbActiveY : orbRestY
    readonly property real orbSize: expanded ? orbExpandedSize : orbCollapsedSize

    readonly property real panelX: expanded ? panelRestX : panelHiddenX
    readonly property real panelY: panelRestY
    readonly property real panelOpacity: expanded ? 1.0 : 0.0

    function toggle() { expanded = !expanded }
    function open()   { expanded = true }
    function close()  { expanded = false }
}
