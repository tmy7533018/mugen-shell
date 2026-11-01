import QtQuick

Item {
    id: resizeHandle

    required property var yuraState
    property var settingsManager: null
    property Item mapTarget: null

    width: 18
    height: 18
    z: 20

    anchors.top: parent.top
    anchors.right: resizeHandle.yuraState.isLeft ? parent.right : undefined
    anchors.left: resizeHandle.yuraState.isLeft ? undefined : parent.left

    MouseArea {
        anchors.fill: parent
        anchors.margins: -8
        cursorShape: resizeHandle.yuraState.isLeft ? Qt.SizeBDiagCursor : Qt.SizeFDiagCursor
        preventStealing: true

        property real pressX: 0
        property real pressY: 0
        property int pressW: 0
        property int pressH: 0

        onPressed: (mouse) => {
            let p = mapToItem(resizeHandle.mapTarget, mouse.x, mouse.y)
            pressX = p.x
            pressY = p.y
            pressW = resizeHandle.yuraState.panelWidth
            pressH = resizeHandle.yuraState.panelHeight
        }
        onPositionChanged: (mouse) => {
            if (!pressed || !resizeHandle.settingsManager) return
            let p = mapToItem(resizeHandle.mapTarget, mouse.x, mouse.y)
            let dx = p.x - pressX
            let dy = p.y - pressY
            let widthSign = resizeHandle.yuraState.isLeft ? 1 : -1
            resizeHandle.settingsManager.yuraPanelWidth = Math.max(480, Math.min(1100, pressW + dx * widthSign))
            resizeHandle.settingsManager.yuraPanelHeight = Math.max(480, Math.min(1100, pressH - dy))
        }
        onReleased: {
            if (resizeHandle.settingsManager) resizeHandle.settingsManager.saveSettings()
        }
    }
}
