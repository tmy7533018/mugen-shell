import QtQuick
import QtQuick.Layouts
import Quickshell
import "../ui" as UI

UI.SvgIcon {
    id: root

    property var theme
    property var modeManager

    function scaled(val) {
        if (root.modeManager) return root.modeManager.barScale(val)
        return val
    }

    width: 1
    height: root.scaled(16)
    Layout.alignment: Qt.AlignVCenter
    // Negate parent RowLayout spacing
    Layout.leftMargin: root.scaled(-4)
    Layout.rightMargin: root.scaled(-4)
    source: Quickshell.shellDir + "/assets/icons/divider.svg"
    color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.40)
    opacity: 0.5
}
