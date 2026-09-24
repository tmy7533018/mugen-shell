import QtQuick
import "../common" as Common

// Home is three stacked grids (favourites, groups, every app) that the keyboard walks as one
// list: left/right/Tab run through the whole thing, up/down cross the band boundaries.
Item {
    id: home

    property var theme
    property var typo
    property var favorites: []
    property var groups: []
    property var allApps: []
    property Component tileDelegate
    property int columns: 1
    property int cellWidth: 100
    property int cellHeight: 110
    property int bandGap: 24
    property int titleGap: 8

    // The cursor lives here, not in the grids, so only one band ever shows a selection.
    property int section: -1
    property int local: -1
    readonly property var current: section < 0 ? null : itemAt(section, local)

    signal launch(var item)
    signal contextMenu(var item, real px, real py)
    signal leaveToSearch()
    signal closeRequested()
    signal activity()

    function count(s) { return s === 0 ? favorites.length : (s === 1 ? groups.length : allApps.length) }
    function list(s) { return s === 0 ? favorites : (s === 1 ? groups : allApps) }
    function grid(s) { return s === 0 ? favGrid : (s === 1 ? groupGrid : allGrid) }
    function itemAt(s, i) {
        let l = list(s)
        return i >= 0 && i < l.length ? l[i] : null
    }
    function total() { return favorites.length + groups.length + allApps.length }

    function reset() {
        section = -1
        local = -1
        apply()
    }

    function apply() {
        favGrid.currentIndex = section === 0 ? local : -1
        groupGrid.currentIndex = section === 1 ? local : -1
        allGrid.currentIndex = section === 2 ? local : -1
        ensureVisible()
    }

    function hoverSelect(s, i) {
        section = s
        local = i
        apply()
    }

    function firstBand(from, step) {
        for (let s = from; s >= 0 && s < 3; s += step) {
            if (count(s) > 0) return s
        }
        return -1
    }

    function virtualIndex() {
        if (section < 0) return -1
        let v = local
        if (section > 0) v += favorites.length
        if (section > 1) v += groups.length
        return v
    }

    function setVirtual(v) {
        if (v < favorites.length) {
            section = 0; local = v
        } else if (v < favorites.length + groups.length) {
            section = 1; local = v - favorites.length
        } else {
            section = 2; local = v - favorites.length - groups.length
        }
        apply()
    }

    function enterFrom(backwards) {
        let n = total()
        if (n === 0) return
        if (section < 0) setVirtual(backwards ? n - 1 : 0)
    }

    function moveFlat(delta) {
        let n = total()
        if (n === 0) return
        let v = virtualIndex()
        if (v < 0) v = delta > 0 ? -1 : 0
        setVirtual(((v + delta) % n + n) % n)
    }

    function moveDown() {
        if (section < 0) {
            let s = firstBand(0, 1)
            if (s >= 0) { section = s; local = 0; apply() }
            return
        }
        let n = count(section)
        let row = Math.floor(local / columns)
        let col = local % columns
        if ((row + 1) * columns < n) {
            local = Math.min(local + columns, n - 1)
            apply()
            return
        }
        let s = firstBand(section + 1, 1)
        if (s >= 0) {
            section = s
            local = Math.min(col, count(s) - 1)
            apply()
        }
    }

    // Returns false when there is nothing above, so the caller can hand focus to the field.
    function moveUp() {
        if (section < 0) return false
        let row = Math.floor(local / columns)
        let col = local % columns
        if (row > 0) {
            local -= columns
            apply()
            return true
        }
        let s = firstBand(section - 1, -1)
        if (s < 0) return false
        let n = count(s)
        let lastRow = Math.floor((n - 1) / columns)
        section = s
        local = Math.min(lastRow * columns + col, n - 1)
        apply()
        return true
    }

    function ensureVisible() {
        if (section < 0) return
        let g = grid(section)
        let row = Math.floor(local / columns)
        let top = g.mapToItem(flick.contentItem, 0, row * cellHeight).y
        let bottom = top + cellHeight
        if (top < flick.contentY) {
            flick.contentY = top
        } else if (bottom > flick.contentY + flick.height) {
            flick.contentY = Math.max(0, bottom - flick.height)
        }
    }

    // Point in Home coordinates -> the tile under it, across the three bands (scroll included).
    function tileAt(px, py) {
        if (px < 0 || py < 0 || px >= width || py >= height) return null
        for (let s = 0; s < 3; s++) {
            let g = grid(s)
            if (!g.visible) continue
            let p = g.mapFromItem(home, px, py)
            if (p.x < 0 || p.y < 0 || p.x >= g.width || p.y >= g.height) continue
            let i = g.indexAt(p.x, p.y + g.contentY)
            if (i >= 0 && i < count(s)) return { item: itemAt(s, i), section: s, index: i }
        }
        return null
    }

    function currentTilePoint(target) {
        if (section < 0) return null
        let item = grid(section).itemAtIndex(local)
        if (!item) return null
        return item.mapToItem(target, item.width * 0.7, item.height * 0.7)
    }

    function isModifierKey(k) {
        return k === Qt.Key_Shift || k === Qt.Key_Control || k === Qt.Key_Alt
            || k === Qt.Key_Meta || k === Qt.Key_AltGr || k === Qt.Key_CapsLock
            || k === Qt.Key_NumLock || k === Qt.Key_ScrollLock
    }

    Keys.onPressed: (event) => {
        home.activity()
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (current) home.launch(current)
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            home.closeRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            moveFlat(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            moveFlat(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            if (!moveUp()) home.leaveToSearch()
            event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            moveDown()
            event.accepted = true
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            moveFlat((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Menu
                   || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
            if (current) {
                let p = currentTilePoint(home)
                home.contextMenu(current, p ? p.x : width / 2, p ? p.y : height / 2)
            }
            event.accepted = true
        } else if (isModifierKey(event.key)) {
            event.accepted = false
        } else {
            home.leaveToSearch()
            event.accepted = false
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: bands.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: bands
            width: parent.width
            spacing: home.bandGap

            Column {
                width: parent.width
                visible: favGrid.count > 0
                spacing: home.titleGap

                Common.SectionTitle {
                    x: 6
                    text: "Favorites"
                    theme: home.theme
                    typo: home.typo
                }

                GridView {
                    id: favGrid
                    readonly property int sectionIndex: 0
                    width: parent.width
                    height: contentHeight
                    visible: count > 0
                    interactive: false
                    cellWidth: home.cellWidth
                    cellHeight: home.cellHeight
                    model: home.favorites
                    delegate: home.tileDelegate
                    currentIndex: -1
                    // GridView selects item 0 whenever a model arrives; the cursor above is the only authority.
                    onModelChanged: home.apply()
                    highlight: null
                    highlightFollowsCurrentItem: false
                }
            }

            Column {
                width: parent.width
                visible: groupGrid.count > 0
                spacing: home.titleGap

                Common.SectionTitle {
                    x: 6
                    text: "Groups"
                    theme: home.theme
                    typo: home.typo
                }

                GridView {
                    id: groupGrid
                    readonly property int sectionIndex: 1
                    width: parent.width
                    height: contentHeight
                    visible: count > 0
                    interactive: false
                    cellWidth: home.cellWidth
                    cellHeight: home.cellHeight
                    model: home.groups
                    delegate: home.tileDelegate
                    currentIndex: -1
                    onModelChanged: home.apply()
                    highlight: null
                    highlightFollowsCurrentItem: false
                }
            }

            Column {
                width: parent.width
                visible: allGrid.count > 0
                spacing: home.titleGap

                Common.SectionTitle {
                    x: 6
                    text: "All apps"
                    theme: home.theme
                    typo: home.typo
                }

                GridView {
                    id: allGrid
                    readonly property int sectionIndex: 2
                    width: parent.width
                    height: contentHeight
                    visible: count > 0
                    interactive: false
                    cellWidth: home.cellWidth
                    cellHeight: home.cellHeight
                    model: home.allApps
                    delegate: home.tileDelegate
                    currentIndex: -1
                    onModelChanged: home.apply()
                    highlight: null
                    highlightFollowsCurrentItem: false
                }
            }
        }
    }
}
