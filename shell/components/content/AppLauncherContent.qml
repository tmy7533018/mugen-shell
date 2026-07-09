import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../ui" as UI
import "../../lib" as Theme

FocusScope {
    id: root

    required property var modeManager
    property var theme
    property var typo
    property var icons

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(520),
        "leftMargin": modeManager.scale(450),
        "rightMargin": modeManager.scale(450),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })

    property var apps: []
    property string lastAppsJson: ""
    property var filteredApps: []
    property var runningApps: []
    property bool appsLoaded: false
    property bool isLoading: false

    property string searchText: ""

    property var favoritesSet: ({})

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
        saveFavorites()
        filterApps()
    }

    function saveFavorites() {
        let list = Object.keys(favoritesSet)
        let json = JSON.stringify({ favorites: list })
        let escaped = json.replace(/'/g, "'\\''")
        saveFavoritesProcess.command = [
            "sh", "-c",
            "d=\"${XDG_STATE_HOME:-$HOME/.local/state}/mugen-shell\"; mkdir -p \"$d\" && printf '%s' '" + escaped + "' > \"$d/launcher.json\""
        ]
        saveFavoritesProcess.running = true
    }

    function launchExec(execCmd, inTerminal) {
        if (!execCmd) return
        Theme.Hypr.exec(inTerminal ? "kitty " + execCmd : execCmd)
        modeManager.closeAllModes()
    }

    function launchApp(app) {
        if (!app) return
        launchExec(app.exec || "", app.terminal === true)
    }

    function openContextMenu(app, px, py) {
        if (!app) return
        contextMenu.openFor(app, isFavorite(app.exec || ""))
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
        // terminal route on purpose: the user sees exactly what gets removed
        // (deps included) and confirms in the package manager itself
        let holdTail = "; echo; printf 'Press Enter to close...'; read _"
        if (df.indexOf("flatpak/exports/share/applications/") !== -1) {
            let appId = df.split("/").pop().replace(/\.desktop$/, "")
            Quickshell.execDetached([
                "kitty", "--title", "Uninstall " + app.name, "sh", "-c",
                "flatpak uninstall \"$1\"" + holdTail, "sh", appId
            ])
        } else {
            // user-local .desktop copies often point at packaged binaries, so try
            // the Exec target's owner before giving up; interpreters are excluded
            // so an "env FOO=1 app" line can never resolve to coreutils
            let execFirst = (app.exec || "").split(" ")[0]
            let execBase = execFirst.split("/").pop()
            if (execFirst[0] !== "/" || ["env", "sh", "bash", "zsh", "python", "python3"].indexOf(execBase) !== -1) {
                execFirst = ""
            }
            Quickshell.execDetached([
                "kitty", "--title", "Uninstall " + app.name, "sh", "-c",
                "pkg=$(pacman -Qoq -- \"$1\" 2>/dev/null); "
                    + "if [ -z \"$pkg\" ] && [ -n \"$2\" ]; then "
                    + "pkg=$(pacman -Qoq -- \"$(realpath \"$2\" 2>/dev/null || printf %s \"$2\")\" 2>/dev/null); fi; "
                    + "if [ -n \"$pkg\" ]; then echo \"Owning package: $pkg\"; echo; sudo pacman -R \"$pkg\"; "
                    + "else echo 'No package owns this app — it looks manually installed.'; "
                    + "echo \"  Entry: $1\"; "
                    + "if [ -n \"$2\" ]; then echo \"  Exec:  $2\"; fi; "
                    + "echo 'Remove those files manually to uninstall it.'; fi" + holdTail,
                "sh", df, execFirst
            ])
        }
        modeManager.closeAllModes()
    }

    function preloadApps() {
        if (!appsLoaded && !isLoading) {
            isLoading = true
            iconThemeProcess.running = true
            appsProcess.running = true
        }
    }

    function loadApps() {
        if (appsLoaded) {
            filterApps()
        } else if (!isLoading) {
            isLoading = true
        }
        // always re-run in the background so installs/removals show up
        // without a shell restart; the model is only swapped when it changed
        if (!appsProcess.running) {
            appsProcess.running = true
        }
    }

    function loadRunningApps() {
        runningAppsDebounceTimer.restart()
    }

    Timer {
        id: runningAppsDebounceTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (!runningAppsProcess.running) {
                runningAppsProcess.running = true
            }
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
        if (search === "") {
            let favs = []
            let rest = []
            for (let i = 0; i < apps.length; i++) {
                if (isFavorite(apps[i].exec)) {
                    favs.push(apps[i])
                } else {
                    rest.push(apps[i])
                }
            }
            filteredApps = favs.concat(rest)
            return
        }
        let scored = []
        for (let i = 0; i < apps.length; i++) {
            let s = scoreApp(apps[i], search)
            if (s > 0) scored.push({ app: apps[i], score: s })
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

    // Derived, not mutated inside isAppRunning(): a binding that both reads and
    // writes the cache is what Qt flags as a loop.
    readonly property var _runningSet: {
        let set = ({})
        for (let i = 0; i < runningApps.length; i++) {
            set[runningApps[i].toLowerCase()] = true
        }
        return set
    }

    function isAppRunning(appName) {
        let name = appName.toLowerCase()
        if (_runningSet[name]) {
            return true
        }
        for (let key in _runningSet) {
            if (key.includes(name) || name.includes(key)) {
                return true
            }
        }
        return false
    }

    Theme.IconResolver {
        id: iconResolver
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
        command: ["bash", "-c", "grep '^gtk-icon-theme-name' ~/.config/gtk-3.0/settings.ini 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo 'hicolor'"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                let theme = data.trim()
                if (theme.length > 0) {
                    iconResolver.iconTheme = theme
                }
            }
        }
    }

    Process {
        id: runningAppsProcess
        command: ["bash", "-c", "hyprctl clients -j | jq -r '.[].class'"]
        running: false

        property var classes: []

        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0) {
                    runningAppsProcess.classes.push(trimmed)
                }
            }
        }

        onExited: () => {
            root.runningApps = runningAppsProcess.classes
            runningAppsProcess.classes = []
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            contextMenu.shown = false
            if (modeManager.isMode("launcher")) {
                root.loadApps()
                root.loadRunningApps()
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

    // wait for PanelWindow.forceActiveFocus()
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

        Keys.forwardTo: [searchField ? searchField.searchFieldItem : null, appGrid]

        Keys.onPressed: (event) => {
            if (modeManager.isMode("launcher")) {
                modeManager.bump()
            }
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
            }
        }

        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            spacing: 16

            UI.AppSearchField {
                id: searchField
                theme: root.theme
                typo: root.typo
                icons: root.icons
                filteredApps: root.filteredApps
                modeManager: root.modeManager

                onSearchTextChanged: (text) => {
                    root.searchText = text
                    filterDebounceTimer.restart()
                    modeManager.bump()
                    appGrid.userInteracted = false
                    appGrid.currentIndex = -1
                }

                onRequestFocusGrid: () => {
                    if (appGrid.count > 0) {
                        appGrid.forceActiveFocus()
                        appGrid.userInteracted = true
                        appGrid.currentIndex = 0
                    }
                }

                onRequestLaunchApp: (app) => {
                    root.launchApp(app)
                }
            }

            GridView {
                id: appGrid
                Layout.fillHeight: true
                Layout.preferredWidth: {
                    let cols = Math.floor(mainColumn.width / 100)
                    return cols > 0 ? cols * 100 : 100
                }
                Layout.alignment: Qt.AlignHCenter

                cellWidth: 100
                cellHeight: 100
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
                    } else {
                        if (searchField && searchField.searchFieldItem) {
                            searchField.searchFieldItem.forceActiveFocus()
                            searchField.searchFieldItem.Keys.forwardTo = null
                        }
                        event.accepted = false
                    }
                }

                delegate: Item {
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
                        iconResolver: root.iconResolver
                        isAppRunning: root.isAppRunning
                        modeManager: root.modeManager
                        isFavorite: root.isFavorite(delegateWrapper.wrapperModelData ? delegateWrapper.wrapperModelData.exec : "")

                        onLaunchApp: (app) => {
                            root.launchApp(app)
                        }

                        onResetAutoCloseTimer: () => {
                            modeManager.bump()
                        }

                        onContextMenuRequested: (app, px, py) => {
                            let p = delegateItem.mapToItem(launcherLayer, px, py)
                            root.openContextMenu(app, p.x, p.y)
                        }

                        onEntered: {
                            // mouse takes selection; avoids kb + hover both highlighting
                            if (delegateWrapper.GridView.view) {
                                delegateWrapper.GridView.view.userInteracted = true
                                delegateWrapper.GridView.view.currentIndex = index
                            }
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    if (root.isLoading) return "Loading..."
                    if (root.searchText === "" && Object.keys(root.favoritesSet).length === 0) {
                        return "Right-click for options"
                    }
                    return root.filteredApps.length + " apps"
                }
                color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                font.pixelSize: root.typo ? root.typo.sizeSmall : 11
                opacity: 0.7
            }
        }

        MouseArea {
            id: menuDismissArea
            anchors.fill: parent
            z: 40
            enabled: contextMenu.shown
            visible: enabled
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: contextMenu.dismiss()
            // keep the grid from scrolling away under the open menu
            onWheel: (wheel) => { wheel.accepted = true }
            onPositionChanged: modeManager.bump()
        }

        UI.AppContextMenu {
            id: contextMenu
            z: 50
            theme: root.theme
            typo: root.typo

            onDismissed: {
                if (modeManager.isMode("launcher")) {
                    appGrid.forceActiveFocus()
                }
            }

            onLaunchRequested: (app) => {
                root.launchApp(app)
            }

            onActionRequested: (app, actionExec) => {
                // Terminal= applies to the whole entry, actions included
                root.launchExec(actionExec, app && app.terminal === true)
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

    Component.onCompleted: {
        loadFavoritesProcess.running = true
        if (modeManager) {
            modeManager.registerMode("launcher", root)
            if (modeManager.isMode("launcher")) {
                root.loadApps()
                root.loadRunningApps()
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
