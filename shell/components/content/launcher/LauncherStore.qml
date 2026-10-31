import QtQuick
import Quickshell.Io
import "../../../lib" as Theme

QtObject {
    id: store

    property var apps: []
    property var favoritesSet: ({})

    // Groups live only on Home: a genre view or a search dissolves them into their apps.
    property var groups: []

    signal committed()
    signal loaded()

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
        store.committed()
    }

    function createGroup(execA, execB) {
        if (!execA || !execB || execA === execB) return null
        let apps = [findApp(execA), findApp(execB)]
        let genreA = Theme.LauncherSearch.genreOf(apps[0])
        let name = genreA !== "" && genreA === Theme.LauncherSearch.genreOf(apps[1]) ? genreA : "Group"
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

    function renamedGroups(id, name) {
        let trimmed = (name || "").trim()
        if (trimmed === "") return null
        return groups.map(g => ({ id: g.id, name: g.id === id ? trimmed : g.name, items: g.items }))
    }

    function renameGroup(id, name) {
        let next = renamedGroups(id, name)
        if (next) commitGroups(next)
    }

    function findApp(execKey) {
        for (let i = 0; i < apps.length; i++) {
            if (apps[i].exec === execKey) return apps[i]
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
        store.committed()
    }

    function stateWriteArgv(groupList) {
        let json = JSON.stringify({ favorites: Object.keys(favoritesSet), groups: groupList })
        return Theme.JsonStore.atomicWriteArgv(
            Theme.Paths.stateDir, Theme.Paths.stateDir + "/launcher.json", json)
    }

    function saveState() {
        saveFavoritesProcess.command = stateWriteArgv(groups)
        saveFavoritesProcess.running = true
    }

    function load() {
        loadFavoritesProcess.running = true
    }

    property Process loadFavoritesProcess: Process {
        id: loadProcess
        command: ["sh", "-c", "f=\"${XDG_STATE_HOME:-$HOME/.local/state}/mugen-shell/launcher.json\"; [ -f \"$f\" ] && cat \"$f\" || printf '{}'"]
        running: false

        property string output: ""

        stdout: SplitParser {
            onRead: data => {
                loadProcess.output += data
            }
        }

        onExited: () => {
            try {
                let parsed = JSON.parse(loadProcess.output || "{}")
                let favs = Array.isArray(parsed.favorites) ? parsed.favorites : []
                let set = {}
                for (let i = 0; i < favs.length; i++) set[favs[i]] = true
                store.favoritesSet = set
                let gs = Array.isArray(parsed.groups) ? parsed.groups : []
                store.groups = gs.filter(g => g && typeof g.id === "string" && Array.isArray(g.items))
                    .map(g => ({ id: g.id, name: String(g.name || "Group"), items: g.items.filter(e => typeof e === "string") }))
                store.loaded()
            } catch (e) {
            }
            loadProcess.output = ""
        }
    }

    property Process saveFavoritesProcess: Process {
        command: ["true"]
        running: false
    }
}
