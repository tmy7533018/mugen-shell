pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../common" as Common
import "../../ui" as UI
import "../../../lib" as Lib

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    readonly property int tileHeight: 62
    readonly property int dragThreshold: 4
    readonly property string sourceId: "source"

    readonly property var items: settingsManager ? settingsManager.barLayoutItems : Lib.BarLayoutRules.defaultItems()

    property var drag: null
    property point dragPointer: Qt.point(0, 0)
    property var dropZone: null
    property string hintText: ""
    property var hintOwner: null

    readonly property color textPrimary: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
    readonly property color textSecondary: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
    readonly property color textFaint: theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
    readonly property color accent: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 1.0)
    readonly property color danger: theme ? theme.danger : Qt.rgba(0.95, 0.55, 0.65, 1.0)
    readonly property color wellColor: theme ? theme.surfaceInsetCard : Qt.rgba(0.05, 0.05, 0.08, 0.92)
    readonly property color wellDropColor: Qt.rgba(accent.r, accent.g, accent.b, 0.10)
    readonly property color tileColor: Qt.rgba(0.55, 0.55, 0.65, 0.22)
    readonly property color lineBorderColor: Qt.rgba(accent.r, accent.g, accent.b, 0.3)

    width: parent ? parent.width : 420
    height: body.implicitHeight + 24
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    onItemsChanged: section.hintText = ""

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    function commitItems(next) {
        if (!settingsManager) return
        const sanitized = Lib.BarLayoutRules.itemsOf(next)
        if (JSON.stringify(sanitized) === JSON.stringify(section.items)) return
        settingsManager.barLayoutItems = sanitized
        settingsManager.saveSettings()
        section.bump()
    }

    function catalogEntry(id) {
        return Lib.BarLayoutRules.catalog.find(c => c.id === id)
    }

    function labelOf(id) {
        const entry = section.catalogEntry(id)
        return entry ? entry.label : ""
    }

    function iconPathOf(id) {
        const entry = section.catalogEntry(id)
        return entry ? Quickshell.shellDir + "/assets/icons/" + entry.icon + ".svg" : ""
    }

    function showHint(tile) {
        const entry = section.catalogEntry(tile.entryId)
        section.hintOwner = tile
        section.hintText = entry ? entry.hint : ""
        if (section.hintText === "") return
        const at = tile.mapToItem(section, 0, 0)
        const centered = at.x + (tile.width - hint.width) / 2
        hint.x = Math.max(4, Math.min(section.width - hint.width - 4, centered))
        hint.y = at.y - hint.height - 4
    }

    // Between two tiles the new one can report its enter before the old one reports its leave.
    function hideHint(tile) {
        if (section.hintOwner === tile) section.hintText = ""
    }

    function zoneAt(point) {
        for (const zone of [leftZone, rightZone, hiddenZone]) {
            if (zone.holds(point)) return zone
        }
        return null
    }

    function beginDrag(tile, grabX, grabY) {
        section.hintText = ""
        section.drag = { entryId: tile.entryId, itemIndex: tile.itemIndex, grabX: grabX, grabY: grabY }
    }

    function moveDrag(point) {
        section.dragPointer = point
        const zone = section.zoneAt(point)
        section.dropZone = zone
        if (zone) zone.placeCaret(point, section.drag.itemIndex)
    }

    function cancelDrag() {
        section.drag = null
        section.dropZone = null
    }

    function droppedItems(zone, point) {
        const itemIndex = section.drag.itemIndex
        const isNewSeparator = itemIndex < 0
        if (zone.zoneId === "hidden") {
            if (isNewSeparator || !section.items[itemIndex].visible) return null
            return Lib.BarLayoutRules.hidden(section.items, itemIndex)
        }
        const position = zone.positionAt(point, itemIndex)
        return isNewSeparator
            ? Lib.BarLayoutRules.withSeparator(section.items, zone.zoneId, position)
            : Lib.BarLayoutRules.placed(section.items, itemIndex, zone.zoneId, position)
    }

    function endDrag(point) {
        const zone = section.zoneAt(point)
        const next = zone ? section.droppedItems(zone, point) : null
        section.cancelDrag()
        if (next) section.commitItems(next)
    }

    component DashedFrame: Canvas {
        id: frame
        required property color strokeColor
        anchors.fill: parent
        onStrokeColorChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = frame.strokeColor
            ctx.lineWidth = 1
            ctx.setLineDash([3, 3])
            ctx.beginPath()
            ctx.roundedRect(0.5, 0.5, width - 1, height - 1, 11, 11)
            ctx.stroke()
        }
    }

    component TileFace: Rectangle {
        id: face
        required property var host
        required property string entryId
        readonly property bool isSource: entryId === host.sourceId
        readonly property bool isSeparator: entryId === Lib.BarLayoutRules.separatorId

        width: face.isSource ? 88 : (face.isSeparator ? 22 : 64)
        height: face.host.tileHeight
        radius: 12
        color: face.isSource || face.isSeparator ? "transparent" : face.host.tileColor

        DashedFrame {
            visible: face.isSource || face.isSeparator
            strokeColor: face.isSource ? face.host.accent : face.host.lineBorderColor
        }

        Rectangle {
            visible: face.isSeparator
            anchors.centerIn: parent
            width: 1
            height: 26
            color: face.host.textSecondary
        }

        Row {
            visible: face.isSource
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 26
                color: face.host.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Separator"
                color: face.host.accent
                font.pixelSize: 11
                font.family: "M PLUS 2"
                font.weight: Font.Medium
            }
        }

        Column {
            visible: !face.isSource && !face.isSeparator
            anchors.centerIn: parent
            spacing: 5

            UI.SvgIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 20
                height: 20
                source: face.host.iconPathOf(face.entryId)
                color: face.host.textPrimary
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.host.labelOf(face.entryId)
                color: face.host.textSecondary
                font.pixelSize: 10
                font.family: "M PLUS 2"
            }
        }
    }

    component Tile: TileFace {
        id: tile
        required property int itemIndex

        opacity: tile.itemIndex >= 0 && tile.host.drag && tile.host.drag.itemIndex === tile.itemIndex ? 0.3 : 1

        MouseArea {
            id: tileArea
            property real pressX: 0
            property real pressY: 0

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            // The settings list is a Flickable and would otherwise take the drag as a scroll.
            preventStealing: true
            cursorShape: tile.host.drag ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onContainsMouseChanged: {
                if (containsMouse && !tile.host.drag) tile.host.showHint(tile)
                else tile.host.hideHint(tile)
            }
            onPressed: mouse => {
                tileArea.pressX = mouse.x
                tileArea.pressY = mouse.y
            }
            onPositionChanged: mouse => {
                if (!pressed) return
                if (!tile.host.drag) {
                    if (Math.hypot(mouse.x - tileArea.pressX, mouse.y - tileArea.pressY) < tile.host.dragThreshold) return
                    tile.host.beginDrag(tile, tileArea.pressX, tileArea.pressY)
                }
                tile.host.moveDrag(tileArea.mapToItem(tile.host, mouse.x, mouse.y))
            }
            onReleased: mouse => {
                if (tile.host.drag) tile.host.endDrag(tileArea.mapToItem(tile.host, mouse.x, mouse.y))
            }
            onCanceled: tile.host.cancelDrag()
        }
    }

    component Zone: Column {
        id: zone
        required property var host
        required property string zoneId
        required property string title
        required property var entries
        readonly property bool isHiddenZone: zoneId === "hidden"
        readonly property bool isDropTarget: host.dropZone === zone
        readonly property bool removesSeparator: isHiddenZone && host.drag !== null
            && host.drag.entryId === Lib.BarLayoutRules.separatorId

        function holds(point) {
            const local = well.mapFromItem(zone.host, point.x, point.y)
            return well.contains(local)
        }

        function placedTiles(skipItemIndex) {
            const out = []
            for (let i = 0; i < tileRepeater.count; i++) {
                const tile = tileRepeater.itemAt(i) as Tile
                if (tile && tile.itemIndex >= 0 && tile.itemIndex !== skipItemIndex) out.push(tile)
            }
            return out
        }

        function rowNearest(tiles, y) {
            const distance = t => Math.max(t.y - y, y - t.y - t.height, 0)
            const nearest = tiles.reduce((best, t) => distance(t) < distance(best) ? t : best)
            return tiles.filter(t => t.y === nearest.y)
        }

        function positionAt(point, skipItemIndex) {
            const tiles = zone.placedTiles(skipItemIndex)
            if (tiles.length === 0) return 0
            const at = tileFlow.mapFromItem(zone.host, point.x, point.y)
            const row = zone.rowNearest(tiles, at.y)
            const next = row.find(t => at.x < t.x + t.width / 2)
            return next ? tiles.indexOf(next) : tiles.indexOf(row[row.length - 1]) + 1
        }

        function placeCaret(point, skipItemIndex) {
            const tiles = zone.placedTiles(skipItemIndex)
            if (tiles.length === 0) {
                caret.x = tileFlow.x
                caret.y = tileFlow.y
                return
            }
            const position = zone.positionAt(point, skipItemIndex)
            const row = zone.rowNearest(tiles, tileFlow.mapFromItem(zone.host, point.x, point.y).y)
            const before = tiles[position - 1]
            const edge = row.includes(before)
                ? before.x + before.width + tileFlow.spacing / 2
                : tiles[position].x - tileFlow.spacing / 2
            caret.x = tileFlow.x + edge - caret.width / 2
            caret.y = tileFlow.y + row[0].y
        }

        spacing: 6

        Text {
            text: zone.title
            color: zone.host.textSecondary
            font.pixelSize: 12
            font.family: "M PLUS 2"
            font.weight: Font.Medium
            font.letterSpacing: 0.4
        }

        Rectangle {
            id: well
            width: zone.width
            height: Math.max(86, tileFlow.implicitHeight + 2 * tileFlow.y)
            radius: 14
            color: zone.isDropTarget ? zone.host.wellDropColor : zone.host.wellColor
            border.width: 1
            border.color: !zone.isDropTarget ? "transparent"
                : (zone.removesSeparator ? zone.host.danger : zone.host.accent)

            Flow {
                id: tileFlow
                x: 8
                y: 8
                width: well.width - 2 * x
                spacing: 6

                Repeater {
                    id: tileRepeater
                    model: zone.entries

                    delegate: Tile {
                        required property var modelData
                        host: zone.host
                        entryId: modelData.id
                        itemIndex: modelData.itemIndex
                    }
                }
            }

            Text {
                visible: zone.entries.length === 0
                anchors.centerIn: parent
                text: "Drop icons here"
                color: zone.host.textFaint
                font.pixelSize: 12
                font.family: "M PLUS 2"
            }

            Rectangle {
                id: caret
                objectName: "barIconCaret"
                visible: zone.isDropTarget && !zone.isHiddenZone
                width: 2
                height: zone.host.tileHeight
                radius: 1
                color: zone.host.accent
            }
        }
    }

    Column {
        id: body
        x: 12
        y: 12
        width: section.width - 2 * x
        spacing: 12

        Item {
            width: body.width
            height: resetButton.height

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Bar icons"
                color: section.textPrimary
                font.pixelSize: 14
                font.family: "M PLUS 2"
                font.weight: Font.Medium
            }

            Common.SubtleButton {
                id: resetButton
                anchors.right: parent.right
                theme: section.theme
                label: "Reset"
                onClicked: section.commitItems(Lib.BarLayoutRules.defaultItems())
            }
        }

        Zone {
            id: leftZone
            width: body.width
            host: section
            zoneId: "left"
            title: "Left side"
            entries: Lib.BarLayoutRules.displayEntries(section.items, "left")
        }

        Zone {
            id: rightZone
            width: body.width
            host: section
            zoneId: "right"
            title: "Right side"
            entries: Lib.BarLayoutRules.displayEntries(section.items, "right")
        }

        Text {
            width: body.width
            horizontalAlignment: Text.AlignHCenter
            text: "Workspaces stay in the center"
            color: section.textFaint
            font.pixelSize: 12
            font.family: "M PLUS 2"
        }

        Zone {
            id: hiddenZone
            width: body.width
            host: section
            zoneId: "hidden"
            title: "Hidden"
            entries: [{ id: section.sourceId, itemIndex: -1 }].concat(Lib.BarLayoutRules.hiddenEntries(section.items))
        }
    }

    TileFace {
        objectName: "barIconDragGhost"
        z: 2
        visible: section.drag !== null
        opacity: 0.85
        host: section
        entryId: section.drag ? section.drag.entryId : ""
        x: section.dragPointer.x - (section.drag ? section.drag.grabX : 0)
        y: section.dragPointer.y - (section.drag ? section.drag.grabY : 0)
    }

    Rectangle {
        id: hint
        objectName: "barIconHint"
        z: 1
        visible: section.hintText !== "" && section.drag === null
        width: hintLabel.implicitWidth + 16
        height: hintLabel.implicitHeight + 8
        radius: 8
        color: section.theme ? section.theme.surfaceInsetCard : Qt.rgba(0.05, 0.05, 0.08, 0.92)
        border.width: 1
        border.color: section.lineBorderColor

        Text {
            id: hintLabel
            anchors.centerIn: parent
            text: section.hintText
            color: section.textPrimary
            font.pixelSize: 11
            font.family: "M PLUS 2"
        }
    }
}
