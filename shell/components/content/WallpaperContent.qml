import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../common" as Common
import "../ui" as UI
import "../../lib" as Theme

FocusScope {
    id: root

    Theme.Typography { id: typography }

    required property var modeManager
    required property var wallpaperManager
    property var theme
    property var icons
    property bool expanded: false

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(root.expanded ? 560 : 240),
        "leftMargin": modeManager.scale(root.expanded ? 340 : 550),
        "rightMargin": modeManager.scale(root.expanded ? 340 : 550),
        "topMargin": modeManager.normalBarSize.topMargin,
        "bottomMargin": modeManager.normalBarSize.bottomMargin
    })

    onExpandedChanged: root.restoreSelection()

    Connections {
        target: wallpaperManager
        function onSearchQueryChanged() {
            if (wallpaperManager.searchQuery.length > 0)
                root.expanded = true
        }
    }

    function setWallpaper(path) {
        wallpaperManager.setWallpaper(path)
        modeManager.closeAllModes()
    }

    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("wallpaper", root)
            wallpaperManager.pickerOpen = modeManager.isMode("wallpaper")
            if (modeManager.isMode("wallpaper")) {
                root.expanded = false
                wallpaperManager.searchQuery = ""
                searchField.text = ""
                root.anchorPath = ""
                wallpaperManager.loadWallpapers()
                focusTimer.restart()
            }
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            wallpaperManager.pickerOpen = modeManager.isMode("wallpaper")
            if (modeManager.isMode("wallpaper")) {
                root.expanded = false
                wallpaperManager.searchQuery = ""
                searchField.text = ""
                root.anchorPath = ""
                wallpaperManager.loadWallpapers()
                focusTimer.restart()
            }
        }
    }

    // A Binding here sticks pickerOpen on: the owning Loader tears it down without restoring.
    Component.onDestruction: wallpaperManager.pickerOpen = false

    function resetAutoCloseTimer() {
        if (modeManager.isMode("wallpaper")) modeManager.bump()
    }

    // Longer interval to wait for PanelWindow.forceActiveFocus()
    Timer {
        id: focusTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (wallpaperLayer) {
                wallpaperLayer.forceActiveFocus()
            }
            Qt.callLater(() => {
                if (listView) {
                    listView.forceActiveFocus()
                    if (!listView.activeFocus) {
                        Qt.callLater(() => {
                            if (listView) {
                                listView.forceActiveFocus()
                            }
                        })
                    }
                }
            })
        }
    }

    readonly property var listModel: ["__add__"].concat(wallpaperManager.visibleWallpapers || [])

    function openWallpaperFolder() {
        openWallpaperDirProcess.running = false
        openWallpaperDirProcess.command = ["xdg-open", wallpaperManager.wallpaperDir]
        openWallpaperDirProcess.running = true
    }

    Process {
        id: openWallpaperDirProcess
        command: []
        running: false
    }

    // Kept as a path, not an index, so the selection survives a file appearing or disappearing.
    property string anchorPath: ""

    function activeView() {
        return root.expanded ? gridView : listView
    }

    function moveTo(index) {
        let view = root.activeView()
        view.currentIndex = index
        if (view === gridView)
            gridView.positionViewAtIndex(index, GridView.Visible)
        root.anchorPath = index >= 1 ? (root.listModel[index] || "") : ""
    }

    function activateCurrent() {
        let view = root.activeView()
        if (view.currentIndex === 0) {
            root.openWallpaperFolder()
        } else if (view.currentIndex >= 1) {
            let path = root.listModel[view.currentIndex]
            if (path)
                root.setWallpaper(path)
        }
    }

    function focusResults(backwards) {
        let view = root.activeView()
        if (backwards && view.count > 0)
            root.moveTo(view.count - 1)
        view.forceActiveFocus()
    }

    function isPrintable(text) {
        if (!text || text.length === 0)
            return false
        let c = text.charCodeAt(0)
        return c >= 0x20 && c !== 0x7f
    }

    function forwardPrintableToSearch(event) {
        if (!root.isPrintable(event.text) || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
            return false
        // The field only exists while expanded, so it has to be shown before it can take focus.
        root.expanded = true
        searchField.searchFieldItem.forceActiveFocus()
        searchField.text += event.text
        return true
    }

    function restoreSelection() {
        Qt.callLater(function() {
            let view = root.activeView()
            if (!view)
                return

            let index = root.listModel.indexOf(root.anchorPath)
            if (index < 1)
                index = root.listModel.indexOf(wallpaperManager.currentWallpaperPath)
            if (index < 1)
                index = root.listModel.length > 1 ? 1 : 0

            view.currentIndex = index
            if (view === listView)
                listView.positionViewAtIndex(index, ListView.Center)
            else
                gridView.positionViewAtIndex(index, GridView.Visible)
        })
    }

    Connections {
        target: wallpaperManager
        function onWallpapersChanged() {
            root.restoreSelection()
        }

        function onCurrentWallpaperPathChanged() {
            root.restoreSelection()
        }
    }

    Item {
        id: wallpaperLayer
        anchors.fill: parent
        anchors.leftMargin: root.requiredBarSize.leftMargin + modeManager.scale(10)
        anchors.rightMargin: root.requiredBarSize.rightMargin + modeManager.scale(10)
        anchors.topMargin: modeManager.scale(20)
        anchors.bottomMargin: modeManager.scale(20)
        visible: modeManager.isMode("wallpaper")
        z: 10

        Behavior on anchors.leftMargin {
            NumberAnimation {
                duration: Theme.Motion.sweep
                easing.type: Easing.OutExpo
            }
        }

        Behavior on anchors.rightMargin {
            NumberAnimation {
                duration: Theme.Motion.sweep
                easing.type: Easing.OutExpo
            }
        }

        focus: modeManager.isMode("wallpaper")

        opacity: 0

        states: [
            State {
                name: "visible"
                when: modeManager.isMode("wallpaper")
                PropertyChanges { target: wallpaperLayer; opacity: 1.0 }
            }
        ]

        transitions: [
            Transition {
                from: "visible"
                to: ""
                NumberAnimation {
                    property: "opacity"
                    duration: Theme.Motion.standard
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: Theme.Motion.standard }
                    NumberAnimation {
                        property: "opacity"
                        duration: Theme.Motion.gentle
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        ]

        // Forwarding runs before this item's own handlers, so the typing field has to opt out here.
        Keys.forwardTo: searchField.searchFieldItem.activeFocus
            ? []
            : [root.expanded ? gridView : listView]

        Keys.onPressed: (event) => {
            if (modeManager.isMode("wallpaper")) {
                root.resetAutoCloseTimer()
            }
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: modeManager.scale(root.expanded ? 38 : 32)

                Common.GlowText {
                    anchors.centerIn: parent
                    text: "select wallpaper"
                    color: (theme ? theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))
                    font.pixelSize: modeManager.scale(20)
                    font.family: "M PLUS 2"
                    font.weight: Font.Light
                    font.letterSpacing: 1.5
                    enableGlow: true
                    glowColor: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6)
                    glowSamples: 20
                    glowRadius: modeManager.scale(12)
                    glowSpread: 0.5
                }

                RowLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: modeManager.scale(12)

                    UI.SearchField {
                        visible: root.expanded
                        id: searchField
                        theme: root.theme
                        icons: root.icons
                        typo: typography
                        modeManager: root.modeManager
                        placeholder: "Search wallpapers"
                        resultCount: wallpaperManager.visibleWallpapers.length
                        Layout.preferredWidth: modeManager.scale(260)
                        Layout.preferredHeight: modeManager.scale(38)
                        onSearchTextChanged: text => wallpaperManager.searchQuery = text
                        onRequestActivateSelected: root.activateCurrent()
                        onRequestFocusResults: backwards => root.focusResults(backwards)
                    }

                    Rectangle {
                        id: moreChip
                        Layout.preferredHeight: modeManager.scale(30)
                        Layout.preferredWidth: moreRow.implicitWidth + modeManager.scale(24)
                        Layout.alignment: Qt.AlignVCenter
                        radius: height / 2
                        color: "transparent"
                        border.width: 1
                        border.color: root.theme ? root.theme.surfaceBorder : Qt.rgba(0.70, 0.65, 0.90, 0.3)

                        RowLayout {
                            id: moreRow
                            anchors.centerIn: parent
                            spacing: modeManager.scale(6)

                            Text {
                                text: root.expanded ? "less" : "more"
                                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                                font.pixelSize: modeManager.scale(11)
                                font.family: "M PLUS 2"
                            }

                            UI.SvgIcon {
                                Layout.preferredWidth: modeManager.scale(12)
                                Layout.preferredHeight: modeManager.scale(12)
                                source: Quickshell.shellDir + "/assets/icons/chevron-down.svg"
                                color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                                rotation: root.expanded ? 180 : 0

                                Behavior on rotation {
                                    NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.expanded = !root.expanded
                        }
                    }
                }
            }

            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.expanded

                model: root.listModel
                orientation: ListView.Horizontal
                spacing: modeManager.scale(16)
                clip: true

                highlightFollowsCurrentItem: true
                highlightMoveDuration: 300
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: width / 2 - modeManager.scale(120)
                preferredHighlightEnd: width / 2 + modeManager.scale(120)
                snapMode: ListView.SnapToItem

                focus: !root.expanded

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        modeManager.closeAllModes()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (currentIndex === 0) {
                            root.openWallpaperFolder()
                        } else if (currentIndex >= 1) {
                            root.setWallpaper(root.listModel[currentIndex])
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        if (currentIndex > 0) {
                            root.moveTo(currentIndex - 1)
                            root.resetAutoCloseTimer()
                            event.accepted = true
                        } else {
                            event.accepted = false
                        }
                    } else if (event.key === Qt.Key_Right) {
                        if (currentIndex < count - 1) {
                            root.moveTo(currentIndex + 1)
                            root.resetAutoCloseTimer()
                            event.accepted = true
                        } else {
                            event.accepted = false
                        }
                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        if (event.modifiers & Qt.ShiftModifier || event.key === Qt.Key_Backtab) {
                            if (currentIndex > 0) {
                                root.moveTo(currentIndex - 1)
                                root.resetAutoCloseTimer()
                                event.accepted = true
                            } else {
                                event.accepted = false
                            }
                        } else {
                            if (currentIndex < count - 1) {
                                root.moveTo(currentIndex + 1)
                                root.resetAutoCloseTimer()
                                event.accepted = true
                            } else {
                                event.accepted = false
                            }
                        }
                    } else if (event.key === Qt.Key_Home) {
                        root.moveTo(0)
                        root.resetAutoCloseTimer()
                        event.accepted = true
                    } else if (event.key === Qt.Key_End) {
                        root.moveTo(count - 1)
                        root.resetAutoCloseTimer()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        root.expanded = true
                        gridView.forceActiveFocus()
                        root.resetAutoCloseTimer()
                        event.accepted = true
                    } else if (root.forwardPrintableToSearch(event)) {
                        event.accepted = true
                    } else {
                        event.accepted = false
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    z: -1

                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) {
                            if (listView.currentIndex > 0) {
                                root.moveTo(listView.currentIndex - 1)
                            }
                        } else if (wheel.angleDelta.y < 0) {
                            if (listView.currentIndex < listView.count - 1) {
                                root.moveTo(listView.currentIndex + 1)
                            }
                        }
                        root.resetAutoCloseTimer()
                    }

                    onPositionChanged: {
                        root.resetAutoCloseTimer()
                    }
                }

                onCountChanged: {
                    if (modeManager.isMode("wallpaper")) {
                        root.restoreSelection()
                    }
                }

                delegate: Item {
                    id: cellRoot
                    width: modeManager.scale(240)
                    height: listView.height

                    property bool isCurrent: ListView.isCurrentItem
                    property bool isAddCell: modelData === "__add__"
                    property string wallpaperPath: isAddCell ? "" : modelData

                    WallpaperTile {
                        anchors.fill: parent
                        anchors.margins: modeManager.scale(8)

                        scale: cellRoot.isCurrent ? 1.0 : 0.75
                        opacity: cellRoot.isCurrent ? 1.0 : 0.7

                        Behavior on scale { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }

                        theme: root.theme
                        modeManager: root.modeManager
                        wallpaperManager: root.wallpaperManager
                        path: cellRoot.wallpaperPath
                        selected: cellRoot.isCurrent
                        isAddCell: cellRoot.isAddCell
                        isVideo: !cellRoot.isAddCell && wallpaperManager.isVideoFile(cellRoot.wallpaperPath)

                        onActivated: {
                            root.moveTo(index)
                            // setWallpaper() tears down this delegate, so bump before it runs.
                            root.resetAutoCloseTimer()
                            if (cellRoot.isAddCell) {
                                root.openWallpaperFolder()
                            } else {
                                root.setWallpaper(cellRoot.wallpaperPath)
                            }
                        }
                    }
                }
            }

            GridView {
                id: gridView
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.expanded

                model: root.listModel
                cellWidth: modeManager.scale(240)
                cellHeight: modeManager.scale(142)
                clip: true

                onCountChanged: {
                    if (modeManager.isMode("wallpaper")) {
                        root.restoreSelection()
                    }
                }

                Keys.onPressed: (event) => {
                    let colsPerRow = Math.max(1, Math.floor(gridView.width / gridView.cellWidth))

                    if (event.key === Qt.Key_Escape) {
                        modeManager.closeAllModes()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.activateCurrent()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        if (currentIndex > 0) {
                            root.moveTo(currentIndex - 1)
                            root.resetAutoCloseTimer()
                            event.accepted = true
                        } else {
                            event.accepted = false
                        }
                    } else if (event.key === Qt.Key_Right) {
                        if (currentIndex < count - 1) {
                            root.moveTo(currentIndex + 1)
                            root.resetAutoCloseTimer()
                            event.accepted = true
                        } else {
                            event.accepted = false
                        }
                    } else if (event.key === Qt.Key_Up) {
                        if (currentIndex < colsPerRow) {
                            root.expanded = false
                            root.resetAutoCloseTimer()
                        } else {
                            root.moveTo(currentIndex - colsPerRow)
                            root.resetAutoCloseTimer()
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        if (currentIndex < count - colsPerRow) {
                            root.moveTo(currentIndex + colsPerRow)
                            root.resetAutoCloseTimer()
                            event.accepted = true
                        } else {
                            event.accepted = false
                        }
                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        if (event.modifiers & Qt.ShiftModifier || event.key === Qt.Key_Backtab) {
                            if (currentIndex > 0) {
                                root.moveTo(currentIndex - 1)
                                root.resetAutoCloseTimer()
                                event.accepted = true
                            } else {
                                event.accepted = false
                            }
                        } else {
                            if (currentIndex < count - 1) {
                                root.moveTo(currentIndex + 1)
                                root.resetAutoCloseTimer()
                                event.accepted = true
                            } else {
                                event.accepted = false
                            }
                        }
                    } else if (event.key === Qt.Key_Home) {
                        root.moveTo(0)
                        root.resetAutoCloseTimer()
                        event.accepted = true
                    } else if (event.key === Qt.Key_End) {
                        root.moveTo(count - 1)
                        root.resetAutoCloseTimer()
                        event.accepted = true
                    } else if (root.forwardPrintableToSearch(event)) {
                        event.accepted = true
                    } else {
                        event.accepted = false
                    }
                }

                delegate: Item {
                    id: gridCellRoot
                    width: gridView.cellWidth
                    height: gridView.cellHeight

                    property bool isCurrent: GridView.isCurrentItem
                    property bool isAddCell: modelData === "__add__"
                    property string wallpaperPath: isAddCell ? "" : modelData

                    WallpaperTile {
                        anchors.fill: parent
                        anchors.margins: modeManager.scale(8)

                        theme: root.theme
                        modeManager: root.modeManager
                        wallpaperManager: root.wallpaperManager
                        path: gridCellRoot.wallpaperPath
                        selected: gridCellRoot.isCurrent
                        isAddCell: gridCellRoot.isAddCell
                        isVideo: !gridCellRoot.isAddCell && wallpaperManager.isVideoFile(gridCellRoot.wallpaperPath)

                        onActivated: {
                            root.moveTo(index)
                            root.resetAutoCloseTimer()
                            if (gridCellRoot.isAddCell) {
                                root.openWallpaperFolder()
                            } else {
                                root.setWallpaper(gridCellRoot.wallpaperPath)
                            }
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: wallpaperManager.isLoading
                    ? "loading..."
                    : (wallpaperManager.wallpapers.length === 0
                        ? "no wallpapers yet, press + to open the folder"
                        : (wallpaperManager.searchQuery.length > 0
                            ? wallpaperManager.visibleWallpapers.length + " of " + wallpaperManager.wallpapers.length + " wallpapers"
                            : wallpaperManager.wallpapers.length + " wallpapers"))
                color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                font.pixelSize: modeManager.scale(10)
                font.family: "M PLUS 2"
                opacity: 0.6
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 1
        enabled: modeManager.isMode("wallpaper")
        visible: enabled
        hoverEnabled: true
        onClicked: modeManager.closeAllModes()

        onPositionChanged: {
            if (modeManager.isMode("wallpaper")) {
                root.resetAutoCloseTimer()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: root.requiredBarSize.topMargin
        anchors.bottomMargin: root.requiredBarSize.bottomMargin
        anchors.leftMargin: root.requiredBarSize.leftMargin
        anchors.rightMargin: root.requiredBarSize.rightMargin
        z: 1.8
        enabled: modeManager.isMode("wallpaper")
        visible: enabled
        hoverEnabled: true
        onClicked: modeManager.bump()
        onPositionChanged: modeManager.bump()
    }
}
