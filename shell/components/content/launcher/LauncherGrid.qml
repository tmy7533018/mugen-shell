import QtQuick

GridView {
    id: grid

    property var results: []
    // blocks GridView auto-select 0 until first hover/key
    property bool userInteracted: false

    signal launch(var app)
    signal closeRequested()
    signal upToSearch()
    signal leaveToSearch()
    signal menuRequested(var app, var tile)
    signal activity()

    cellWidth: 100
    cellHeight: 110
    clip: true

    cacheBuffer: 200
    reuseItems: true

    model: grid.results

    currentIndex: -1

    onCountChanged: {
        if (!grid.userInteracted && grid.currentIndex !== -1) {
            grid.currentIndex = -1
        }
    }

    highlight: null
    highlightFollowsCurrentItem: false

    function isModifierKey(k) {
        return k === Qt.Key_Shift || k === Qt.Key_Control || k === Qt.Key_Alt
            || k === Qt.Key_Meta || k === Qt.Key_AltGr || k === Qt.Key_CapsLock
            || k === Qt.Key_NumLock || k === Qt.Key_ScrollLock
    }

    Keys.onPressed: (event) => {
        grid.activity()
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (grid.currentIndex >= 0 && grid.results[grid.currentIndex]) {
                grid.launch(grid.results[grid.currentIndex])
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            grid.closeRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            if (grid.currentIndex > 0) {
                grid.currentIndex--
                grid.positionViewAtIndex(grid.currentIndex, GridView.Visible)
            } else {
                grid.currentIndex = grid.count - 1
                grid.positionViewAtIndex(grid.currentIndex, GridView.Visible)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            if (grid.currentIndex < grid.count - 1) {
                grid.currentIndex++
                grid.positionViewAtIndex(grid.currentIndex, GridView.Visible)
            } else {
                grid.currentIndex = 0
                grid.positionViewAtIndex(grid.currentIndex, GridView.Visible)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            if (grid.currentIndex >= Math.floor(grid.width / grid.cellWidth)) {
                grid.currentIndex -= Math.floor(grid.width / grid.cellWidth)
                grid.positionViewAtIndex(grid.currentIndex, GridView.Visible)
            } else {
                grid.upToSearch()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            let colsPerRow = Math.floor(grid.width / grid.cellWidth)
            if (colsPerRow > 0 && grid.currentIndex < grid.count - colsPerRow) {
                grid.currentIndex += colsPerRow
                grid.positionViewAtIndex(grid.currentIndex, GridView.Visible)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Menu
                   || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
            if (grid.currentIndex >= 0 && grid.results[grid.currentIndex]) {
                grid.menuRequested(grid.results[grid.currentIndex], grid.itemAtIndex(grid.currentIndex))
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            if (event.modifiers & Qt.ShiftModifier || event.key === Qt.Key_Backtab) {
                if (grid.currentIndex > 0) {
                    grid.currentIndex--
                    grid.positionViewAtIndex(grid.currentIndex, GridView.Visible)
                } else {
                    grid.currentIndex = grid.count - 1
                    grid.positionViewAtIndex(grid.currentIndex, GridView.Visible)
                }
            } else {
                if (grid.currentIndex < grid.count - 1) {
                    grid.currentIndex++
                    grid.positionViewAtIndex(grid.currentIndex, GridView.Visible)
                } else {
                    grid.currentIndex = 0
                    grid.positionViewAtIndex(grid.currentIndex, GridView.Visible)
                }
            }
            event.accepted = true
        } else if (grid.isModifierKey(event.key)) {
            // A bare Shift keydown is not typing: handing focus over here sent Shift+Tab to the field.
            event.accepted = false
        } else {
            grid.leaveToSearch()
            event.accepted = false
        }
    }
}
