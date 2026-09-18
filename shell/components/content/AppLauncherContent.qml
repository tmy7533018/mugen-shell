import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../common" as Common
import "../ui" as UI
import "../../lib" as Theme

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

    property string searchText: ""

    property var favoritesSet: ({})

    // First match wins, so the identifying categories come before the ones half the
    // desktop carries: Steam is Network;FileTransfer;Game and belongs under Games.
    readonly property var genres: [
        { "label": "Games", "keys": ["Game", "ActionGame", "StrategyGame", "Emulator"] },
        { "label": "Dev", "keys": ["Development", "IDE", "Building", "Debugger", "TextEditor"] },
        { "label": "Graphics", "keys": ["Graphics", "2DGraphics", "3DGraphics", "RasterGraphics", "VectorGraphics", "Photography"] },
        { "label": "Media", "keys": ["AudioVideo", "Audio", "Video", "Player", "Recorder", "TV", "Music"] },
        { "label": "Internet", "keys": ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging", "P2P", "FileTransfer"] },
        { "label": "System", "keys": ["System", "Settings", "Monitor", "Security", "HardwareSettings", "DesktopSettings"] },
        { "label": "Utilities", "keys": ["Utility", "FileManager", "FileTools", "TerminalEmulator", "Archiving", "Calculator"] }
    ]

    property string activeGenre: ""

    function genreOf(app) {
        let cats = (app && app.categories ? app.categories : "").split(";")
        for (let g = 0; g < genres.length; g++) {
            for (let c = 0; c < cats.length; c++) {
                if (cats[c] !== "" && genres[g].keys.indexOf(cats[c]) >= 0) {
                    return genres[g].label
                }
            }
        }
        return ""
    }

    // Only genres that actually hold something: an empty chip is a dead end.
    readonly property var presentGenres: {
        let seen = {}
        for (let i = 0; i < apps.length; i++) {
            let g = genreOf(apps[i])
            if (g !== "") seen[g] = true
        }
        let out = []
        for (let g = 0; g < genres.length; g++) {
            if (seen[genres[g].label]) out.push(genres[g].label)
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

    // Groups live only on Home: a genre view or a search dissolves them into their apps.
    property var groups: []

    property var homeFavorites: []
    property var homeGroups: []
    property var homeAllApps: []

    readonly property bool isHome: activeGenre === "" && searchText.trim() === ""

    // An app may sit in any number of groups: they are ways of looking at the All band, not folders it moves into.
    function groupsOf(execKey) {
        return groups.filter(g => g.items.indexOf(execKey) >= 0)
    }

    function findGroup(id) {
        for (let g = 0; g < groups.length; g++) {
            if (groups[g].id === id) return groups[g]
        }
        return null
    }

    // Copy-on-write: QML only notices a var property when the reference changes.
    function commitGroups(next) {
        groups = next
        saveState()
        filterApps()
    }

    function createGroup(execA, execB) {
        if (!execA || !execB || execA === execB) return null
        let apps = [findApp(execA), findApp(execB)]
        let genreA = genreOf(apps[0])
        let name = genreA !== "" && genreA === genreOf(apps[1]) ? genreA : "Group"
        let group = { id: "g-" + Date.now(), name: name, items: [execA, execB] }
        commitGroups(groups.concat([group]))
        return group
    }

    function addToGroup(id, execKey) {
        if (!execKey) return
        commitGroups(groups.map(g => ({
            id: g.id, name: g.name,
            items: g.id === id && g.items.indexOf(execKey) < 0 ? g.items.concat([execKey]) : g.items
        })))
    }

    // A group is two or more apps; the last one left walks back to Home on its own.
    function removeFromGroup(id, execKey) {
        let next = groups.map(g => ({
            id: g.id, name: g.name,
            items: g.id === id ? g.items.filter(e => e !== execKey) : g.items
        })).filter(g => g.items.length > 1)
        commitGroups(next)
    }

    function renameGroup(id, name) {
        let trimmed = (name || "").trim()
        if (trimmed === "") return
        commitGroups(groups.map(g => ({ id: g.id, name: g.id === id ? trimmed : g.name, items: g.items })))
    }

    function findApp(execKey) {
        for (let i = 0; i < apps.length; i++) {
            if (apps[i].exec === execKey) return apps[i]
        }
        return null
    }

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
        let fromGroup = dragSourceView === groupGridView ? openGroupId : ""
        dragCancel()
        if (!app) return
        if (target) {
            if (target.kind === "group") addToGroup(target.id, app.exec)
            else createGroupAndOpen(target.exec, app.exec)
            return
        }
        if (fromGroup !== "" && !pointInPanel(x, y)) {
            removeFromGroup(fromGroup, app.exec)
            if (findGroup(fromGroup) === null) closeGroup()
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
        let g = createGroup(execA, execB)
        if (g) openGroup(g.id, true)
    }

    function findDropTarget(execKey) {
        if (execKey.startsWith("group:")) {
            for (let i = 0; i < homeGroups.length; i++) {
                if (homeGroups[i].exec === execKey) return homeGroups[i]
            }
            return null
        }
        return findApp(execKey)
    }

    function pointInPanel(x, y) {
        if (openGroupId === "") return false
        let p = groupPanel.mapFromItem(launcherLayer, x, y)
        return p.x >= 0 && p.y >= 0 && p.x < groupPanel.width && p.y < groupPanel.height
    }

    // Which tile is under a point in layer coordinates, across whichever view is showing.
    function tileAt(x, y) {
        if (openGroupId !== "") {
            let p = groupGridView.mapFromItem(launcherLayer, x, y)
            if (p.x < 0 || p.y < 0 || p.x >= groupGridView.width || p.y >= groupGridView.height) return null
            let i = groupGridView.indexAt(p.x, p.y + groupGridView.contentY)
            return i >= 0 && i < openGroupMembers.length ? { item: openGroupMembers[i] } : null
        }
        if (isHome) {
            let p = homeView.mapFromItem(launcherLayer, x, y)
            return homeView.tileAt(p.x, p.y)
        }
        return null
    }

    function isFavorite(execKey) {
        return execKey && favoritesSet[execKey] === true
    }

    function toggleFavorite(execKey) {
        if (!execKey) return
        let next = Object.assign({}, favoritesSet)
        if (next[execKey]) {
            delete next[execKey]
        } else {
            next[execKey] = true
        }
        favoritesSet = next
        saveState()
        filterApps()
    }

    function saveState() {
        let json = JSON.stringify({ favorites: Object.keys(favoritesSet), groups: groups })
        let escaped = json.replace(/'/g, "'\\''")
        saveFavoritesProcess.command = [
            "sh", "-c",
            "d=\"${XDG_STATE_HOME:-$HOME/.local/state}/mugen-shell\"; mkdir -p \"$d\" && printf '%s' '" + escaped + "' > \"$d/launcher.json\""
        ]
        saveFavoritesProcess.running = true
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
        let g = findGroup(openGroupId)
        return g ? g.items.map(findApp).filter(a => a !== null) : []
    }
    // What the panel draws: it keeps the last group on close so the fade-out still shows the members.
    property string shownGroupId: ""
    readonly property var shownGroup: findGroup(shownGroupId)
    readonly property var shownGroupMembers: {
        let g = findGroup(shownGroupId)
        return g ? g.items.map(findApp).filter(a => a !== null) : []
    }

    function openGroup(id, editName) {
        shownGroupId = id
        openGroupId = id
        groupNameEditing = editName === true
        groupGridView.currentIndex = -1
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
                groupNameInput.forceActiveFocus()
                groupNameInput.selectAll()
            } else {
                groupGridView.forceActiveFocus()
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
        let leavable = openGroupId !== "" ? groupsOf(app.exec || "").filter(g => g.id === openGroupId) : groupsOf(app.exec || "")
        contextMenu.openFor(app, isFavorite(app.exec || ""), leavable)
        contextMenu.x = Math.max(0, Math.min(px, launcherLayer.width - contextMenu.width))
        contextMenu.y = Math.max(0, Math.min(py, launcherLayer.height - contextMenu.height))
        modeManager.bump()
    }

    function startUninstall(app) {
        if (!app) return
        let steamMatch = (app.exec || "").match(/steam:\/\/rungameid\/(\d+)/)
        if (steamMatch) {
            Quickshell.execDetached(["steam", "steam://uninstall/" + steamMatch[1]])
            modeManager.closeAllModes()
            return
        }
        let df = app.desktopFile || ""
        if (df === "") return
        // terminal route on purpose: the user sees what gets removed and confirms in the package manager
        let holdTail = "; echo; printf 'Press Enter to close...'; read _"
        let terminal = (settingsManager && settingsManager.launcherTerminal) ? settingsManager.launcherTerminal : "kitty"
        let termPrefix = Theme.Hypr.terminalArgvPrefix(terminal)
        if (df.indexOf("flatpak/exports/share/applications/") !== -1) {
            let appId = df.split("/").pop().replace(/\.desktop$/, "")
            Quickshell.execDetached(termPrefix.concat([
                "sh", "-c",
                "flatpak uninstall \"$1\"" + holdTail, "sh", appId
            ]))
        } else {
            // user-local .desktop copies often point at packaged binaries, so use the Exec target's owner.
            let execFirst = (app.exec || "").split(" ")[0]
            let execBase = execFirst.split("/").pop()
            if (execFirst[0] !== "/" || ["env", "sh", "bash", "zsh", "python", "python3"].indexOf(execBase) !== -1) {
                execFirst = ""
            }
            Quickshell.execDetached(termPrefix.concat([
                "sh", "-c",
                "if ! command -v pacman >/dev/null 2>&1; then "
                    + "echo 'No system package manager found — on NixOS, remove the app from your Nix config instead.'; "
                    + "echo \"  Entry: $1\"; "
                    + "else "
                    + "pkg=$(pacman -Qoq -- \"$1\" 2>/dev/null); "
                    + "if [ -z \"$pkg\" ] && [ -n \"$2\" ]; then "
                    + "pkg=$(pacman -Qoq -- \"$(realpath \"$2\" 2>/dev/null || printf %s \"$2\")\" 2>/dev/null); fi; "
                    + "if [ -n \"$pkg\" ]; then echo \"Owning package: $pkg\"; echo; sudo pacman -R \"$pkg\"; "
                    + "else echo 'No package owns this app — it looks manually installed.'; "
                    + "echo \"  Entry: $1\"; "
                    + "if [ -n \"$2\" ]; then echo \"  Exec:  $2\"; fi; "
                    + "echo 'Remove those files manually to uninstall it.'; fi; fi" + holdTail,
                "sh", df, execFirst
            ]))
        }
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

    function stripDiacritics(s) {
        return s.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    }

    function appAcronym(name) {
        let words = name.split(/[\s\-_./]+/).filter(w => w.length > 0)
        if (words.length < 2) return ""
        return words.map(w => w[0]).join("")
    }

    function fuzzyScore(target, query) {
        if (query.length < 3) return 0
        if (target.length < query.length) return 0

        let qi = 0
        let firstMatch = -1
        let lastMatch = -1
        let consecutive = 0
        let maxConsecutive = 0
        let boundaryBonus = 0

        for (let ti = 0; ti < target.length && qi < query.length; ti++) {
            if (target[ti] === query[qi]) {
                if (firstMatch === -1) firstMatch = ti
                lastMatch = ti
                consecutive++
                if (consecutive > maxConsecutive) maxConsecutive = consecutive
                if (ti === 0 || /[\s\-_./]/.test(target[ti - 1])) {
                    boundaryBonus += 5
                }
                qi++
            } else {
                consecutive = 0
            }
        }

        if (qi < query.length) return 0

        let span = lastMatch - firstMatch + 1
        if (span > query.length * 3) return 0

        return query.length * 10 + maxConsecutive * 5 + boundaryBonus - (span - query.length) * 2
    }

    function scoreApp(app, search) {
        if (!app || !app.name) return 0

        let q = stripDiacritics(search)
        let nameLower = stripDiacritics(app.name.toLowerCase())

        let base = 0
        if (nameLower === q) {
            base = 1000
        } else if (nameLower.startsWith(q)) {
            base = 500
        } else {
            let nameIdx = nameLower.indexOf(q)
            if (nameIdx >= 0) {
                base = 300 - Math.min(nameIdx, 100)
            } else if (appAcronym(nameLower) === q) {
                base = 250
            } else if (stripDiacritics((app.exec || "").toLowerCase()).includes(q)) {
                base = 150
            } else if (stripDiacritics((app.wmClass || "").toLowerCase()).includes(q)) {
                base = 120
            } else if (app.wmClassAliases && app.wmClassAliases.some(a => stripDiacritics(a.toLowerCase()).includes(q))) {
                base = 100
            } else if (stripDiacritics((app.keywords || "").toLowerCase()).includes(q)) {
                base = 80
            } else if (stripDiacritics((app.categories || "").toLowerCase()).includes(q)) {
                base = 50
            } else {
                let fz = fuzzyScore(nameLower, q)
                if (fz > 0) base = Math.min(40, fz)
            }
        }

        if (base > 0 && isFavorite(app.exec)) base += 200
        return base
    }

    function filterApps() {
        // trim: a trailing space would fail the substring tiers and drop real hits
        let search = searchText.trim().toLowerCase()
        // The chip narrows the pool the search then ranks, so the two compose.
        let pool = []
        for (let i = 0; i < apps.length; i++) {
            if (activeGenre === "" || genreOf(apps[i]) === activeGenre) {
                pool.push(apps[i])
            }
        }
        if (search === "") {
            let byName = (a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase())
            let favs = pool.filter(a => isFavorite(a.exec)).sort(byName)
            if (activeGenre !== "") {
                filteredApps = favs.concat(pool.filter(a => !isFavorite(a.exec)).sort(byName))
                return
            }
            let groupTiles = []
            for (let g = 0; g < groups.length; g++) {
                let members = groups[g].items.map(findApp).filter(a => a !== null)
                if (members.length < 2) continue
                groupTiles.push({ kind: "group", id: groups[g].id, name: groups[g].name,
                                  exec: "group:" + groups[g].id, members: members })
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

        stdout: SplitParser {
            onRead: data => {
                appsProcess.output += data
            }
        }

        onExited: () => {
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
        }
    }

    Process {
        id: loadFavoritesProcess
        command: ["sh", "-c", "f=\"${XDG_STATE_HOME:-$HOME/.local/state}/mugen-shell/launcher.json\"; [ -f \"$f\" ] && cat \"$f\" || printf '{}'"]
        running: false

        property string output: ""

        stdout: SplitParser {
            onRead: data => {
                loadFavoritesProcess.output += data
            }
        }

        onExited: () => {
            try {
                let parsed = JSON.parse(loadFavoritesProcess.output || "{}")
                let favs = Array.isArray(parsed.favorites) ? parsed.favorites : []
                let set = {}
                for (let i = 0; i < favs.length; i++) set[favs[i]] = true
                root.favoritesSet = set
                let gs = Array.isArray(parsed.groups) ? parsed.groups : []
                root.groups = gs.filter(g => g && typeof g.id === "string" && Array.isArray(g.items))
                    .map(g => ({ id: g.id, name: String(g.name || "Group"), items: g.items.filter(e => typeof e === "string") }))
                if (root.appsLoaded) root.filterApps()
            } catch (e) {
            }
            loadFavoritesProcess.output = ""
        }
    }

    Process {
        id: saveFavoritesProcess
        command: ["true"]
        running: false
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
                isFavorite: root.isFavorite(delegateWrapper.wrapperModelData ? delegateWrapper.wrapperModelData.exec : "")
                    && delegateWrapper.GridView.view
                    && (delegateWrapper.GridView.view.sectionIndex === 0 || delegateWrapper.GridView.view === appGrid)
                dragEnabled: {
                    let view = delegateWrapper.GridView.view
                    return view ? (view.sectionIndex !== undefined || view === groupGridView) : false
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
            ? [groupGridView]
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

                Layout.fillWidth: true
                Layout.leftMargin: faceInset
                Layout.rightMargin: faceInset
                spacing: 22

                Common.SegmentedControl {
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
                    Layout.preferredWidth: 360
                    theme: root.theme
                    typo: root.typo
                    icons: root.icons
                    resultCount: root.filteredApps.length
                    placeholder: "Search apps..."

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

            GridView {
                id: appGrid
                visible: !root.isHome
                Layout.fillHeight: true
                Layout.preferredWidth: mainColumn.gridWidth
                Layout.alignment: Qt.AlignHCenter

                cellWidth: 100
                cellHeight: 110
                clip: true

                cacheBuffer: 200
                reuseItems: true

                model: root.filteredApps

                currentIndex: -1

                // blocks GridView auto-select 0 until first hover/key
                property bool userInteracted: false

                onCountChanged: {
                    if (!userInteracted && currentIndex !== -1) {
                        currentIndex = -1
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
                    if (modeManager.isMode("launcher")) {
                        modeManager.bump()
                    }
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (currentIndex >= 0 && root.filteredApps[currentIndex]) {
                            root.launchApp(root.filteredApps[currentIndex])
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        searchField.forceActiveFocus()
                        modeManager.closeAllModes()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        if (currentIndex > 0) {
                            currentIndex--
                            positionViewAtIndex(currentIndex, GridView.Visible)
                        } else {
                            currentIndex = count - 1
                            positionViewAtIndex(currentIndex, GridView.Visible)
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                        if (currentIndex < count - 1) {
                            currentIndex++
                            positionViewAtIndex(currentIndex, GridView.Visible)
                        } else {
                            currentIndex = 0
                            positionViewAtIndex(currentIndex, GridView.Visible)
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        if (currentIndex >= Math.floor(width / cellWidth)) {
                            currentIndex -= Math.floor(width / cellWidth)
                            positionViewAtIndex(currentIndex, GridView.Visible)
                        } else {
                            if (searchField && searchField.searchFieldItem) {
                                searchField.searchFieldItem.forceActiveFocus()
                            }
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        let colsPerRow = Math.floor(width / cellWidth)
                        if (colsPerRow > 0 && currentIndex < count - colsPerRow) {
                            currentIndex += colsPerRow
                            positionViewAtIndex(currentIndex, GridView.Visible)
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Menu
                               || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
                        if (currentIndex >= 0 && root.filteredApps[currentIndex]) {
                            let item = appGrid.itemAtIndex(currentIndex)
                            let px = launcherLayer.width / 2
                            let py = launcherLayer.height / 2
                            if (item) {
                                let p = item.mapToItem(launcherLayer, item.width * 0.7, item.height * 0.7)
                                px = p.x
                                py = p.y
                            }
                            root.openContextMenu(root.filteredApps[currentIndex], px, py)
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        if (event.modifiers & Qt.ShiftModifier || event.key === Qt.Key_Backtab) {
                            if (currentIndex > 0) {
                                currentIndex--
                                positionViewAtIndex(currentIndex, GridView.Visible)
                            } else {
                                currentIndex = count - 1
                                positionViewAtIndex(currentIndex, GridView.Visible)
                            }
                        } else {
                            if (currentIndex < count - 1) {
                                currentIndex++
                                positionViewAtIndex(currentIndex, GridView.Visible)
                            } else {
                                currentIndex = 0
                                positionViewAtIndex(currentIndex, GridView.Visible)
                            }
                        }
                        event.accepted = true
                    } else if (appGrid.isModifierKey(event.key)) {
                        // A bare Shift keydown is not typing: handing focus over here sent Shift+Tab to the field.
                        event.accepted = false
                    } else {
                        if (searchField && searchField.searchFieldItem) {
                            searchField.searchFieldItem.forceActiveFocus()
                            searchField.searchFieldItem.Keys.forwardTo = null
                        }
                        event.accepted = false
                    }
                }

                delegate: tileDelegate
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    if (root.isLoading) return "Loading..."
                    if (root.searchText === "" && Object.keys(root.favoritesSet).length === 0) {
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

        Item {
            id: dragGhost
            z: 48
            visible: root.dragExec !== ""
            x: root.dragX - root.dragGrabX
            y: root.dragY - root.dragGrabY
            width: 88
            height: 98
            rotation: -3
            scale: 1.06
            transformOrigin: Item.Center

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 10
                radius: 15
                color: Qt.rgba(0, 0, 0, 0.45)
            }

            Rectangle {
                anchors.fill: parent
                radius: 15
                color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.18)

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 40
                        height: 40
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        sourceSize: Qt.size(96, 96)
                        source: {
                            if (!root.dragApp || !root.dragApp.icon) return ""
                            let paths = launcherIcons.resolveIconPath(root.dragApp.icon)
                            return paths && paths.length > 0 ? "file://" + paths[0] : ""
                        }
                    }

                    Text {
                        width: 76
                        text: root.dragApp ? root.dragApp.name : ""
                        color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                        font.pixelSize: root.typo ? root.typo.sizeSmall : 11
                        font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
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

        Rectangle {
            id: groupPanel
            z: 45
            readonly property bool open: root.openGroupId !== ""
            opacity: open ? 1.0 : 0.0
            scale: open ? 1.0 : 0.94
            visible: opacity > 0.01
            anchors.centerIn: parent
            Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast; easing.type: Theme.Motion.easeOut } }
            Behavior on scale { NumberAnimation { duration: Theme.Motion.fast; easing.type: Theme.Motion.easeOut } }

            readonly property int columns: Math.max(2, Math.min(mainColumn.gridColumns - 2, root.shownGroupMembers.length))
            readonly property int rows: Math.max(1, Math.ceil(root.shownGroupMembers.length / columns))

            width: columns * 100 + 48
            height: 26 + 40 + 14 + rows * 110 + 20
            radius: 24
            color: root.theme ? root.theme.popupFace : Qt.rgba(13 / 255, 8 / 255, 26 / 255, 0.92)
            border.width: 1
            border.color: root.theme ? root.theme.surfaceBorder : Qt.rgba(0.70, 0.65, 0.90, 0.3)

            // Swallow clicks so they do not fall through to the dismiss area.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: (mouse) => { mouse.accepted = true }
                onWheel: (wheel) => { wheel.accepted = true }
            }

            Item {
                id: groupNameRow
                anchors.top: parent.top
                anchors.topMargin: 26
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(groupNameInput.contentWidth, 40) + 20
                height: 40

                TextInput {
                    id: groupNameInput
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -3
                    text: root.shownGroup ? root.shownGroup.name : ""
                    font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
                    font.pixelSize: 20
                    color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    selectionColor: root.theme ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.35) : Qt.rgba(0.65, 0.55, 0.85, 0.35)
                    selectedTextColor: color
                    horizontalAlignment: TextInput.AlignHCenter
                    activeFocusOnPress: true
                    selectByMouse: true

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Escape) {
                            groupGridView.forceActiveFocus()
                            event.accepted = true
                        }
                    }
                    // Whatever is in the field when it loses focus is the name; there is no cancel.
                    onActiveFocusChanged: {
                        if (!activeFocus && root.openGroupId !== "") root.renameGroup(root.openGroupId, text)
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: 2
                    radius: 1
                    color: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 1.0)
                    opacity: groupNameInput.activeFocus ? 0.75 : (groupNameHover.hovered ? 0.3 : 0.0)

                    Behavior on opacity { NumberAnimation { duration: Theme.Motion.micro } }
                }

                HoverHandler { id: groupNameHover }
            }

            GridView {
                id: groupGridView
                anchors.top: groupNameRow.bottom
                anchors.topMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                width: groupPanel.columns * 100
                height: groupPanel.rows * 110
                interactive: false
                cellWidth: 100
                cellHeight: 110
                model: root.shownGroupMembers
                delegate: tileDelegate
                currentIndex: -1
                highlight: null
                highlightFollowsCurrentItem: false
                property bool userInteracted: false

                // GridView selects 0 whenever its model changes; nothing is chosen until hover or a key.
                onCountChanged: {
                    if (!userInteracted && currentIndex !== -1) currentIndex = -1
                }

                Keys.onPressed: (event) => {
                    modeManager.bump()
                    let cols = groupPanel.columns
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (currentIndex >= 0 && root.openGroupMembers[currentIndex]) root.launchApp(root.openGroupMembers[currentIndex])
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Backtab) {
                        currentIndex = count === 0 ? -1 : (currentIndex - 1 + count) % count
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab) {
                        currentIndex = count === 0 ? -1 : (currentIndex + 1) % count
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        if (currentIndex < 0) currentIndex = 0
                        else if (currentIndex + cols < count) currentIndex += cols
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        if (currentIndex >= cols) currentIndex -= cols
                        else groupNameInput.forceActiveFocus()
                        event.accepted = true
                    }
                }
            }
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
                if (root.openGroupId !== "") groupGridView.forceActiveFocus()
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
                removeFromGroup(groupId, app.exec)
                if (root.openGroupId !== "" && findGroup(root.openGroupId) === null) root.closeGroup()
            }

            onFavoriteToggled: (app) => {
                if (app) root.toggleFavorite(app.exec || "")
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

    Component.onCompleted: {
        loadFavoritesProcess.running = true
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
