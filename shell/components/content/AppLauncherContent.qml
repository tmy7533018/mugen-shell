import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../common" as Common
import "../ui" as UI
import "../../lib" as Theme
import "./launcher" as Launcher

FocusScope {
    id: root

    required property var modeManager
    property var theme
    property var typo
    property var icons
    property var settingsManager

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(520),
        "leftMargin": modeManager.scale(450),
        "rightMargin": modeManager.scale(450),
        "topMargin": modeManager.normalBarSize.topMargin,
        "bottomMargin": modeManager.normalBarSize.bottomMargin
    })

    property var apps: []
    property string lastAppsJson: ""
    property var filteredApps: []
    property bool appsLoaded: false
    property bool isLoading: false
    property bool appsFailed: false

    property string searchText: ""

    Launcher.LauncherStore {
        id: launcherStore
        apps: root.apps
        onCommitted: root.filterApps()
        onLoaded: if (root.appsLoaded) root.filterApps()
    }

    property string activeGenre: ""

    // Only genres that actually hold something: an empty chip is a dead end.
    readonly property var presentGenres: {
        let seen = {}
        for (let i = 0; i < apps.length; i++) {
            let g = Theme.LauncherSearch.genreOf(apps[i])
            if (g !== "") seen[g] = true
        }
        let out = []
        for (let g = 0; g < Theme.LauncherSearch.genres.length; g++) {
            if (seen[Theme.LauncherSearch.genres[g].label]) out.push(Theme.LauncherSearch.genres[g].label)
        }
        return out
    }

    readonly property var tabs: ["Home"].concat(presentGenres)

    function selectGenre(label) {
        activeGenre = (activeGenre === label) ? "" : label
        appGrid.userInteracted = false
        appGrid.currentIndex = -1
        homeView.reset()
        filterApps()
        modeManager.bump()
    }

    property var homeFavorites: []
    property var homeGroups: []
    property var homeAllApps: []

    readonly property bool isHome: activeGenre === "" && searchText.trim() === ""

    property string dragExec: ""
    property var dragApp: null
    property var dragSourceView: null
    property real dragX: 0
    property real dragY: 0
    property real dragGrabX: 44
    property real dragGrabY: 49
    property string dropTargetExec: ""
    property bool dropArmed: false

    // Hovering alone must never group: only a deliberate pause over a tile arms the drop.
    Timer {
        id: dropDwell
        interval: 250
        onTriggered: if (root.dropTargetExec !== "") root.dropArmed = true
    }

    function dragStart(app, view, x, y, grabX, grabY) {
        dragApp = app
        dragExec = app.exec
        dragSourceView = view
        dragGrabX = grabX
        dragGrabY = grabY
        dragX = x
        dragY = y
        dropTargetExec = ""
        dropArmed = false
        modeManager.bump()
    }

    function dragMove(x, y) {
        dragX = x
        dragY = y
        // Inside an open group the only meaningful drop is outside its panel.
        let hit = openGroupId !== "" ? null : tileAt(x, y)
        let exec = hit && hit.item && hit.item.exec !== dragExec ? hit.item.exec : ""
        if (exec !== dropTargetExec) {
            dropTargetExec = exec
            dropArmed = false
            if (exec !== "") dropDwell.restart()
            else dropDwell.stop()
        }
    }

    function dragEnd(x, y) {
        let app = dragApp
        let target = dropArmed ? findDropTarget(dropTargetExec) : null
        let fromGroup = dragSourceView === groupPanel.grid ? openGroupId : ""
        dragCancel()
        if (!app) return
        if (target) {
            if (target.kind === "group") launcherStore.addToGroup(target.id, app.exec)
            else createGroupAndOpen(target.exec, app.exec)
            return
        }
        if (fromGroup !== "" && !pointInPanel(x, y)) {
            launcherStore.removeFromGroup(fromGroup, app.exec)
            if (launcherStore.findGroup(fromGroup) === null) closeGroup()
        }
    }

    function dragCancel() {
        dropDwell.stop()
        dragApp = null
        dragExec = ""
        dragSourceView = null
        dropTargetExec = ""
        dropArmed = false
    }

    function createGroupAndOpen(execA, execB) {
        let g = launcherStore.createGroup(execA, execB)
        if (g) openGroup(g.id, true)
    }

    function findDropTarget(execKey) {
        if (execKey.startsWith("group:")) {
            for (let i = 0; i < homeGroups.length; i++) {
                if (homeGroups[i].exec === execKey) return homeGroups[i]
            }
            return null
        }
        return launcherStore.findApp(execKey)
    }

    function pointInPanel(x, y) {
        if (openGroupId === "") return false
        let p = groupPanel.mapFromItem(launcherLayer, x, y)
        return p.x >= 0 && p.y >= 0 && p.x < groupPanel.width && p.y < groupPanel.height
    }

    // Which tile is under a point in layer coordinates, across whichever view is showing.
    function tileAt(x, y) {
        if (openGroupId !== "") {
            let p = groupPanel.grid.mapFromItem(launcherLayer, x, y)
            if (p.x < 0 || p.y < 0 || p.x >= groupPanel.grid.width || p.y >= groupPanel.grid.height) return null
            let i = groupPanel.grid.indexAt(p.x, p.y + groupPanel.grid.contentY)
            return i >= 0 && i < openGroupMembers.length ? { item: openGroupMembers[i] } : null
        }
        if (isHome) {
            let p = homeView.mapFromItem(launcherLayer, x, y)
            return homeView.tileAt(p.x, p.y)
        }
        return null
    }

    function launchExec(execCmd, inTerminal) {
        if (!execCmd) return
        if (inTerminal) {
            let terminal = (settingsManager && settingsManager.launcherTerminal) ? settingsManager.launcherTerminal : "kitty"
            Theme.Hypr.execInTerminal(terminal, execCmd)
        } else {
            Theme.Hypr.exec(execCmd)
        }
        modeManager.closeAllModes()
    }

    function launchApp(app) {
        if (!app) return
        if (app.kind === "group") {
            openGroup(app.id)
            return
        }
        launchExec(app.exec || "", app.terminal === true)
    }

    property string openGroupId: ""
    property bool groupNameEditing: false
    readonly property var openGroupMembers: {
        let g = launcherStore.findGroup(openGroupId)
        return g ? g.items.map(e => launcherStore.findApp(e)).filter(a => a !== null) : []
    }
    // What the panel draws: it keeps the last group on close so the fade-out still shows the members.
    property string shownGroupId: ""
    readonly property var shownGroup: launcherStore.findGroup(shownGroupId)
    readonly property var shownGroupMembers: {
        let g = launcherStore.findGroup(shownGroupId)
        return g ? g.items.map(e => launcherStore.findApp(e)).filter(a => a !== null) : []
    }

    function openGroup(id, editName) {
        shownGroupId = id
        openGroupId = id
        groupNameEditing = editName === true
        groupPanel.grid.currentIndex = -1
        modeManager.bump()
        groupFocusTimer.restart()
    }

    // Same dance as focusTimer: the surface needs a beat before forceActiveFocus sticks.
    Timer {
        id: groupFocusTimer
        interval: 120
        onTriggered: {
            if (root.openGroupId === "") return
            if (root.groupNameEditing) {
                groupPanel.nameInput.forceActiveFocus()
                groupPanel.nameInput.selectAll()
            } else {
                groupPanel.grid.forceActiveFocus()
            }
        }
    }

    function closeGroup() {
        openGroupId = ""
        groupNameEditing = false
        if (modeManager.isMode("launcher")) homeView.forceActiveFocus()
    }

    function openContextMenu(app, px, py) {
        if (!app || app.kind === "group") return
        let leavable = openGroupId !== "" ? launcherStore.groupsOf(app.exec || "").filter(g => g.id === openGroupId) : launcherStore.groupsOf(app.exec || "")
        contextMenu.openFor(app, launcherStore.isFavorite(app.exec || ""), leavable)
        contextMenu.x = Math.max(0, Math.min(px, launcherLayer.width - contextMenu.width))
        contextMenu.y = Math.max(0, Math.min(py, launcherLayer.height - contextMenu.height))
        modeManager.bump()
    }

    function startUninstall(app) {
        let terminal = (settingsManager && settingsManager.launcherTerminal) ? settingsManager.launcherTerminal : "kitty"
        let argv = Theme.AppUninstall.argv(app, terminal)
        if (!argv) return
        Quickshell.execDetached(argv)
        modeManager.closeAllModes()
    }

    function loadApps() {
        if (appsLoaded) {
            filterApps()
        } else if (!isLoading) {
            isLoading = true
        }
        // always re-run so installs/removals show up; the model is swapped only when the JSON changed
        if (!appsProcess.running) {
            appsProcess.running = true
        }
    }

    function scoreApp(app, search) {
        return Theme.LauncherSearch.scoreApp(app, search, app && launcherStore.isFavorite(app.exec))
    }

    function applyPendingFilter() {
        if (!filterDebounceTimer.running) return
        filterDebounceTimer.stop()
        filterApps()
    }

    function filterApps() {
        // trim: a trailing space would fail the substring tiers and drop real hits
        let search = searchText.trim().toLowerCase()
        // The chip narrows the pool the search then ranks, so the two compose.
        let pool = []
        for (let i = 0; i < apps.length; i++) {
            if (activeGenre === "" || Theme.LauncherSearch.genreOf(apps[i]) === activeGenre) {
                pool.push(apps[i])
            }
        }
        if (search === "") {
            let byName = (a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase())
            let favs = pool.filter(a => launcherStore.isFavorite(a.exec)).sort(byName)
            if (activeGenre !== "") {
                filteredApps = favs.concat(pool.filter(a => !launcherStore.isFavorite(a.exec)).sort(byName))
                return
            }
            let groupTiles = []
            for (let g = 0; g < launcherStore.groups.length; g++) {
                let members = launcherStore.groups[g].items.map(e => launcherStore.findApp(e)).filter(a => a !== null)
                if (members.length < 2) continue
                groupTiles.push({ kind: "group", id: launcherStore.groups[g].id, name: launcherStore.groups[g].name,
                                  exec: "group:" + launcherStore.groups[g].id, members: members })
            }
            // The bottom band is the whole A-Z: favourites and grouped apps appear there too.
            let all = pool.slice().sort(byName)
            homeFavorites = favs
            homeGroups = groupTiles
            homeAllApps = all
            filteredApps = favs.concat(groupTiles).concat(all)
            return
        }
        let scored = []
        for (let i = 0; i < pool.length; i++) {
            let s = scoreApp(pool[i], search)
            if (s > 0) scored.push({ app: pool[i], score: s })
        }
        scored.sort((a, b) => {
            if (a.score !== b.score) return b.score - a.score
            return a.app.name.toLowerCase().localeCompare(b.app.name.toLowerCase())
        })
        let result = []
        for (let i = 0; i < scored.length; i++) result.push(scored[i].app)
        filteredApps = result
    }

    Timer {
        id: filterDebounceTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: {
            root.filterApps()
        }
    }

    Theme.IconResolver {
        id: launcherIcons
    }

    Process {
        id: appsProcess
        command: ["python3", Quickshell.shellDir + "/scripts/list-apps.py"]
        running: false

        property string output: ""
        property string lastError: ""

        stdout: SplitParser {
            onRead: data => {
                appsProcess.output += data
            }
        }

        onRunningChanged: { if (running) lastError = "" }

        onExited: (exitCode) => {
            // list-apps.py prints [] when it fails, so only the exit code tells a broken listing from an empty one.
            root.appsFailed = exitCode !== 0
            if (root.appsFailed) {
                console.warn("list-apps failed (" + exitCode + "): " + appsProcess.lastError)
                root.isLoading = false
                appsProcess.output = ""
                return
            }
            try {
                let out = appsProcess.output || ""
                if (out.trim().length === 0 || out === root.lastAppsJson) {
                    root.isLoading = false
                    appsProcess.output = ""
                    return
                }

                let parsed = JSON.parse(out)

                if (!Array.isArray(parsed)) {
                    root.isLoading = false
                    appsProcess.output = ""
                    return
                }

                root.lastAppsJson = out
                root.apps = parsed
                root.appsLoaded = true
                root.isLoading = false
                root.filterApps()
            } catch (e) {
                root.isLoading = false
            }
            appsProcess.output = ""
        }

        stderr: SplitParser {
            onRead: data => {
                if (data.trim() !== "") appsProcess.lastError = data.trim()
            }
        }
    }

    Process {
        id: iconThemeProcess
        command: ["bash", "-c", "grep '^gtk-icon-theme-name' \"${XDG_CONFIG_HOME:-$HOME/.config}\"/gtk-3.0/settings.ini 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo 'hicolor'"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                let theme = data.trim()
                if (theme.length > 0) {
                    launcherIcons.iconTheme = theme
                }
            }
        }
    }

    Connections {
        target: modeManager
        function onLauncherQueryRequested(text, append) {
            const nextText = append ? (root.searchText + text) : text
            if (searchField) searchField.text = nextText
            focusTimer.restart()
        }
        function onCurrentModeChanged() {
            contextMenu.shown = false
            root.openGroupId = ""
            root.groupNameEditing = false
            if (modeManager.isMode("launcher")) {
                root.loadApps()
                root.searchText = ""
                if (searchField) {
                    searchField.text = ""
                }
                if (appGrid) {
                    appGrid.userInteracted = false
                    appGrid.currentIndex = -1
                }
                // wait for PanelWindow IPC activation
                focusTimer.restart()
            }
        }
    }

    // Bar.qml's escKeyHandler holds focus until focusTimer fires, so it hands typed keys here.
    function forwardKeyToSearch(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return false
        if (!searchField || !searchField.searchFieldItem) return false
        const code = event.text ? event.text.charCodeAt(0) : 0
        const printable = code >= 0x20 && code !== 0x7f
        if (printable || event.key === Qt.Key_Backspace) {
            focusTimer.stop()
            searchField.searchFieldItem.forceActiveFocus()
            searchField.text = printable ? root.searchText + event.text : root.searchText.slice(0, -1)
            return true
        }
        if (!searchField.handleNavigationKey(event.key)) return false
        focusTimer.stop()
        return true
    }

    Timer {
        id: focusTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (launcherLayer) {
                launcherLayer.forceActiveFocus()
            }
            if (searchField && searchField.searchFieldItem) {
                searchField.searchFieldItem.forceActiveFocus()
                if (!searchField.searchFieldItem.activeFocus) {
                    Qt.callLater(() => {
                        if (searchField && searchField.searchFieldItem) {
                            searchField.searchFieldItem.forceActiveFocus()
                        }
                    })
                }
            }
        }
    }

    Component {
        id: tileDelegate

        Item {
            id: delegateWrapper
            width: GridView.view.cellWidth
            height: GridView.view.cellHeight

            property bool isCurrentItem: GridView.isCurrentItem

            property var wrapperModelData: {
                if (typeof modelData !== 'undefined') {
                    return modelData
                }
                if (GridView.view && GridView.view.model && typeof index !== 'undefined' && index >= 0) {
                    let model = GridView.view.model
                    if (Array.isArray(model) && index < model.length) {
                        return model[index]
                    }
                }
                return undefined
            }

            UI.AppItemDelegate {
                id: delegateItem
                anchors.fill: parent
                modelData: delegateWrapper.wrapperModelData
                isCurrent: delegateWrapper.isCurrentItem
                theme: root.theme
                typo: root.typo
                iconResolver: launcherIcons
                modeManager: root.modeManager
                // The star and tint mark the Favorites band and the genre grid; All and group panels list plain apps.
                isFavorite: launcherStore.isFavorite(delegateWrapper.wrapperModelData ? delegateWrapper.wrapperModelData.exec : "")
                    && delegateWrapper.GridView.view
                    && (delegateWrapper.GridView.view.sectionIndex === 0 || delegateWrapper.GridView.view === appGrid)
                dragEnabled: {
                    let view = delegateWrapper.GridView.view
                    return view ? (view.sectionIndex !== undefined || view === groupPanel.grid) : false
                }
                willGroup: root.dropArmed && delegateWrapper.wrapperModelData
                    && root.dropTargetExec === delegateWrapper.wrapperModelData.exec
                isDragging: root.dragExec !== "" && delegateWrapper.wrapperModelData
                    && root.dragExec === delegateWrapper.wrapperModelData.exec
                    && delegateWrapper.GridView.view === root.dragSourceView

                onLaunchApp: (app) => {
                    root.launchApp(app)
                }

                onDragStarted: (app, lx, ly) => {
                    let p = delegateItem.mapToItem(launcherLayer, lx, ly)
                    root.dragStart(app, delegateWrapper.GridView.view, p.x, p.y, lx, ly)
                }
                onDragMoved: (lx, ly) => {
                    let p = delegateItem.mapToItem(launcherLayer, lx, ly)
                    root.dragMove(p.x, p.y)
                }
                onDragEnded: (lx, ly) => {
                    let p = delegateItem.mapToItem(launcherLayer, lx, ly)
                    root.dragEnd(p.x, p.y)
                }
                onDragCancelled: root.dragCancel()

                onResetAutoCloseTimer: () => {
                    modeManager.bump()
                }

                onContextMenuRequested: (app, px, py) => {
                    let p = delegateItem.mapToItem(launcherLayer, px, py)
                    root.openContextMenu(app, p.x, p.y)
                }

                onEntered: {
                    let view = delegateWrapper.GridView.view
                    if (!view) return
                    if (view.sectionIndex !== undefined) {
                        homeView.hoverSelect(view.sectionIndex, index)
                    } else {
                        view.userInteracted = true
                        view.currentIndex = index
                    }
                }
            }
        }
    }

    Item {
        id: launcherLayer
        anchors.fill: parent
        anchors.leftMargin: modeManager.scale(470)
        anchors.rightMargin: modeManager.scale(470)
        anchors.topMargin: modeManager.scale(30)
        anchors.bottomMargin: modeManager.scale(30)
        z: 10

        opacity: 0
        visible: opacity > 0.01

        states: [
            State {
                name: "visible"
                when: modeManager.isMode("launcher")
                PropertyChanges { target: launcherLayer; opacity: 1.0 }
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

        focus: modeManager.isMode("launcher")

        // With a group open its grid is the only key target; anything else would leak into the Home behind it.
        Keys.forwardTo: root.openGroupId !== ""
            ? [groupPanel.grid]
            : [searchField ? searchField.searchFieldItem : null, root.isHome ? homeView : appGrid]

        Keys.onPressed: (event) => {
            if (modeManager.isMode("launcher")) {
                modeManager.bump()
            }
            if (event.key === Qt.Key_Escape) {
                if (root.openGroupId !== "") {
                    root.closeGroup()
                } else {
                    modeManager.closeAllModes()
                }
                event.accepted = true
            }
        }

        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            spacing: 16
            opacity: root.openGroupId !== "" ? 0.3 : 1.0
            Behavior on opacity { NumberAnimation { duration: Theme.Motion.standard; easing.type: Theme.Motion.easeOut } }

            // Whole columns only, centred: every view below and the row above share this.
            readonly property int gridColumns: Math.max(1, Math.floor(width / 100))
            readonly property int gridWidth: gridColumns * 100

            RowLayout {
                id: topRow
                // Lined up with the tile faces below: the grid is centred on whole columns and each
                // tile insets its own face by 6, so the row starts and ends on those faces.
                readonly property int faceInset: Math.round((mainColumn.width - mainColumn.gridWidth) / 2) + 6
                readonly property int searchFull: 360
                readonly property int searchLeast: 220
                // A tight row (1080p with every genre present) squeezes the search field first, then the segments.
                readonly property int searchWidth: Math.max(searchLeast, Math.min(searchFull, width - spacing * 2 - genreTabs.naturalWidth))
                readonly property int tabsWidth: Math.max(0, Math.min(genreTabs.naturalWidth, width - spacing * 2 - searchWidth))

                Layout.fillWidth: true
                Layout.leftMargin: faceInset
                Layout.rightMargin: faceInset
                spacing: 22

                Common.SegmentedControl {
                    id: genreTabs
                    Layout.preferredWidth: topRow.tabsWidth
                    theme: root.theme
                    typo: root.typo
                    labels: root.tabs
                    current: root.activeGenre === "" ? "Home" : root.activeGenre
                    controlHeight: searchField.fieldHeight
                    onSelected: (label) => root.selectGenre(label === "Home" ? "" : label)
                }

                Item { Layout.fillWidth: true }

                UI.SearchField {
                    id: searchField
                    Layout.preferredWidth: topRow.searchWidth
                    theme: root.theme
                    typo: root.typo
                    icons: root.icons
                    resultCount: filterDebounceTimer.running ? Math.max(1, root.filteredApps.length) : root.filteredApps.length
                    placeholder: "Search apps..."

                    onActivity: root.modeManager.bump()

                    onSearchTextChanged: (text) => {
                        root.searchText = text
                        filterDebounceTimer.restart()
                        root.modeManager.bump()
                        appGrid.userInteracted = false
                        appGrid.currentIndex = -1
                        homeView.reset()
                    }

                    // Entering the grid must not clobber a selection the user already moved.
                    onRequestFocusResults: (backwards) => {
                        if (root.isHome) {
                            if (homeView.total() === 0) return
                            homeView.forceActiveFocus()
                            homeView.enterFrom(backwards)
                            return
                        }
                        if (appGrid.count === 0) return
                        appGrid.forceActiveFocus()
                        appGrid.userInteracted = true
                        if (appGrid.currentIndex < 0)
                            appGrid.currentIndex = backwards ? appGrid.count - 1 : 0
                    }

                    // The grid keeps its highlight while the field has focus, so honour it over the top hit.
                    onRequestActivateSelected: () => {
                        root.applyPendingFilter()
                        if (root.isHome) {
                            root.launchApp(homeView.current ? homeView.current : root.filteredApps[0])
                            return
                        }
                        const i = appGrid.currentIndex
                        root.launchApp(i >= 0 && root.filteredApps[i]
                            ? root.filteredApps[i]
                            : root.filteredApps[0])
                    }
                }
            }

            LauncherHome {
                id: homeView
                visible: root.isHome
                Layout.fillHeight: true
                Layout.preferredWidth: mainColumn.gridWidth
                Layout.alignment: Qt.AlignHCenter

                theme: root.theme
                typo: root.typo
                favorites: root.homeFavorites
                groups: root.homeGroups
                allApps: root.homeAllApps
                tileDelegate: tileDelegate
                columns: mainColumn.gridColumns

                onLaunch: (item) => root.launchApp(item)
                onContextMenu: (item, px, py) => {
                    let p = homeView.mapToItem(launcherLayer, px, py)
                    root.openContextMenu(item, p.x, p.y)
                }
                onLeaveToSearch: {
                    if (searchField && searchField.searchFieldItem) {
                        searchField.searchFieldItem.forceActiveFocus()
                        searchField.searchFieldItem.Keys.forwardTo = null
                    }
                }
                onCloseRequested: {
                    searchField.forceActiveFocus()
                    modeManager.closeAllModes()
                }
                onActivity: modeManager.bump()
            }

            Launcher.LauncherGrid {
                id: appGrid
                visible: !root.isHome
                Layout.fillHeight: true
                Layout.preferredWidth: mainColumn.gridWidth
                Layout.alignment: Qt.AlignHCenter
                results: root.filteredApps
                delegate: tileDelegate

                onActivity: if (root.modeManager.isMode("launcher")) root.modeManager.bump()
                onLaunch: (app) => root.launchApp(app)
                onCloseRequested: {
                    searchField.forceActiveFocus()
                    root.modeManager.closeAllModes()
                }
                onUpToSearch: {
                    if (searchField && searchField.searchFieldItem) {
                        searchField.searchFieldItem.forceActiveFocus()
                    }
                }
                onLeaveToSearch: {
                    if (searchField && searchField.searchFieldItem) {
                        searchField.searchFieldItem.forceActiveFocus()
                        searchField.searchFieldItem.Keys.forwardTo = null
                    }
                }
                onMenuRequested: (app, tile) => {
                    let px = launcherLayer.width / 2
                    let py = launcherLayer.height / 2
                    if (tile) {
                        let p = tile.mapToItem(launcherLayer, tile.width * 0.7, tile.height * 0.7)
                        px = p.x
                        py = p.y
                    }
                    root.openContextMenu(app, px, py)
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    if (root.isLoading) return "Loading..."
                    if (root.appsFailed) return "Listing apps failed"
                    if (root.searchText === "" && root.activeGenre === "" && Object.keys(launcherStore.favoritesSet).length === 0) {
                        return "Right-click for options"
                    }
                    // Home lists favourites twice and adds group tiles, so count the apps themselves.
                    return (root.isHome ? root.apps.length : root.filteredApps.length) + " apps"
                }
                color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                font.pixelSize: root.typo ? root.typo.sizeSmall : 11
                opacity: 0.7
            }
        }

        Launcher.LauncherDragGhost {
            id: dragGhost
            z: 48
            visible: root.dragExec !== ""
            x: root.dragX - root.dragGrabX
            y: root.dragY - root.dragGrabY
            app: root.dragApp
            iconResolver: launcherIcons
            theme: root.theme
            typo: root.typo
        }

        MouseArea {
            id: groupDismissArea
            anchors.fill: parent
            z: 44
            enabled: root.openGroupId !== ""
            visible: enabled
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: root.closeGroup()
            onWheel: (wheel) => { wheel.accepted = true }
            onPositionChanged: modeManager.bump()
        }

        Launcher.LauncherGroupPanel {
            id: groupPanel
            z: 45
            anchors.centerIn: parent
            theme: root.theme
            typo: root.typo
            open: root.openGroupId !== ""
            group: root.shownGroup
            members: root.shownGroupMembers
            openMembers: root.openGroupMembers
            gridColumns: mainColumn.gridColumns
            tileComponent: tileDelegate
            onLaunch: (app) => root.launchApp(app)
            onNameCommitted: (name) => {
                if (root.shownGroupId !== "") launcherStore.renameGroup(root.shownGroupId, name)
            }
            onActivity: root.modeManager.bump()
        }

        MouseArea {
            id: menuDismissArea
            anchors.fill: parent
            // Above the group panel, so a click anywhere but the menu dismisses it there too.
            z: 49
            enabled: contextMenu.shown
            visible: enabled
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: contextMenu.dismiss()
            onWheel: (wheel) => { wheel.accepted = true }
            onPositionChanged: modeManager.bump()
        }

        UI.AppContextMenu {
            id: contextMenu
            z: 50
            theme: root.theme
            typo: root.typo

            onDismissed: {
                if (!modeManager.isMode("launcher")) return
                if (root.openGroupId !== "") groupPanel.grid.forceActiveFocus()
                else if (root.isHome) homeView.forceActiveFocus()
                else appGrid.forceActiveFocus()
            }

            onLaunchRequested: (app) => {
                root.launchApp(app)
            }

            onActionRequested: (app, actionExec) => {
                // Terminal= applies to the whole entry, actions included
                root.launchExec(actionExec, app && app.terminal === true)
            }

            onGroupRemovalRequested: (app, groupId) => {
                launcherStore.removeFromGroup(groupId, app.exec)
                if (root.openGroupId !== "" && launcherStore.findGroup(root.openGroupId) === null) root.closeGroup()
            }

            onFavoriteToggled: (app) => {
                if (app) launcherStore.toggleFavorite(app.exec || "")
            }

            onOpenLocationRequested: (app) => {
                let df = app ? (app.desktopFile || "") : ""
                let dir = df.substring(0, df.lastIndexOf("/"))
                if (dir.length > 0) {
                    Quickshell.execDetached(["xdg-open", dir])
                    modeManager.closeAllModes()
                }
            }

            onUninstallRequested: (app) => {
                root.startUninstall(app)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 1
        enabled: modeManager.isMode("launcher")
        visible: enabled
        hoverEnabled: true

        onClicked: {
            modeManager.closeAllModes()
        }

        onPositionChanged: {
            if (modeManager.isMode("launcher")) {
                modeManager.bump()
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
        enabled: modeManager.isMode("launcher")
        visible: enabled
        hoverEnabled: true
        onClicked: modeManager.bump()
        onPositionChanged: modeManager.bump()
    }

    // The Loader tears this down without moving focus, and saveFavoritesProcess kills its child as it goes.
    Component.onDestruction: {
        let renamed = groupPanel.nameInput.activeFocus && root.shownGroupId !== ""
            ? launcherStore.renamedGroups(root.shownGroupId, groupPanel.nameInput.text) : null
        if (renamed) Quickshell.execDetached(launcherStore.stateWriteArgv(renamed))
    }

    Component.onCompleted: {
        launcherStore.load()
        iconThemeProcess.running = true
        if (modeManager) {
            modeManager.registerMode("launcher", root)
            if (modeManager.isMode("launcher")) {
                root.loadApps()
                root.searchText = ""
                if (searchField) searchField.text = ""
                if (appGrid) {
                    appGrid.userInteracted = false
                    appGrid.currentIndex = -1
                }
                modeManager.bump()
                focusTimer.restart()
            }
        }
    }
}
