import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

QtObject {
    id: manager

    property var windows: ([])
    property ListModel windowsModel: ListModel {}
    property int selectedIndex: 0
    property bool isActive: false

    // While window-switcher is visible, don't auto-reset selection to active window
    property bool selectionLocked: false

    // Deferred step to apply after clients are fetched on IPC trigger
    // 0: none, +1: next, -1: previous
    property int stepOnOpen: 0

    property var iconCache: ({})

    property bool dataReady: false

    property bool pollingFallbackEnabled: true

    // If updateWindows() is called while windowsProc is running, re-run after it exits
    property bool pendingRefresh: false

    property var backgroundApps: []
    property var desktopEntries: ({})

    property var pendingWindowList: null
    property bool windowsProcReady: false
    property bool dbusServicesReady: false
    property bool desktopEntriesReady: false

    property var excludedCategories: [
        "TerminalEmulator",
        "System",
        "Settings",
        "DesktopSettings",
        "Monitor",
        "Debugger"
    ]

    property var allowedBackgroundCategories: [
        "Game",
        "AudioVideo",
        "Audio",
        "Video",
        "Network",
        "Chat",
        "InstantMessaging"
    ]

    property Timer backgroundAppsTimeout: Timer {
        interval: 800
        running: false
        repeat: false
        onTriggered: {
            manager.dbusServicesReady = true
            manager.desktopEntriesReady = true
            manager.applyWindowsIfReady()
        }
    }

    function updateWindows() {
        if (windowsProc.running) {
            pendingRefresh = true
            return
        }
        pendingWindowList = null
        windowsProcReady = false
        windowsProc.output = ""
        windowsProc.running = true
        windowsProcTimeout.restart()

        if (!dbusServicesProc.running) {
            dbusServicesReady = false
            desktopEntriesReady = false
            dbusServicesProc.lines = []
            desktopEntriesProc.lines = []
            dbusServicesProc.running = true
            desktopEntriesProc.running = true
            backgroundAppsTimeout.restart()
        }
    }

    property Timer refreshDebounce: Timer {
        interval: 80
        running: false
        repeat: false
        onTriggered: manager.updateWindows()
    }

    property Process eventProc: Process {
        id: eventProc
        running: false
        property string buf: ""

        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                eventProc.buf += data
                let lines = eventProc.buf.split("\n")
                eventProc.buf = lines.pop()
                for (let i = 0; i < lines.length; i++) {
                    let line = (lines[i] || "").trim()
                    if (line === "") continue
                    if (line.indexOf(">>") !== -1) {
                        refreshDebounce.restart()
                    }
                }
            }
        }

        stderr: SplitParser {
            onRead: _data => {}
        }

        onExited: () => {
            if (pollingFallbackEnabled) {
                pollingTimer.running = true
            }
        }
    }

    property Timer pollingTimer: Timer {
        interval: 2000
        running: false
        repeat: true
        onTriggered: manager.updateWindows()
    }

    Component.onCompleted: {
        eventProc.command = [
            "bash",
            "-lc",
            "python3 \"$HOME/.config/quickshell/mugen-shell/scripts/hyprland_ipc_monitor.py\" 2>/dev/null || " +
            "python3 \"$HOME/.config/mugen-shell/scripts/hyprland_ipc_monitor.py\" 2>/dev/null"
        ]
        eventProc.running = true
        updateWindows()
    }

    function clampSelectedIndex() {
        if (windowsModel.count <= 0) {
            selectedIndex = 0
            return
        }
        if (selectedIndex < 0) selectedIndex = 0
        if (selectedIndex >= windowsModel.count) selectedIndex = windowsModel.count - 1
    }

    function selectNext() {
        if (windowsModel.count === 0) return
        selectedIndex = (selectedIndex + 1) % windowsModel.count
    }

    function selectPrevious() {
        if (windowsModel.count === 0) return
        selectedIndex = (selectedIndex - 1 + windowsModel.count) % windowsModel.count
    }

    function resetToActiveWindow() {
        if (!Hyprland.focusedMonitor || !Hyprland.focusedMonitor.activeWindow) {
            selectedIndex = 0
            return
        }
        let activeAddress = Hyprland.focusedMonitor.activeWindow.address
        for (let i = 0; i < windowsModel.count; i++) {
            let it = windowsModel.get(i)
            if (it && it.address === activeAddress) {
                selectedIndex = i
                return
            }
        }
        selectedIndex = 0
    }

    function clampSelectionToModel() {
        if (windowsModel.count <= 0) {
            selectedIndex = 0
            return
        }
        if (selectedIndex < 0) selectedIndex = 0
        if (selectedIndex >= windowsModel.count) selectedIndex = windowsModel.count - 1
    }

    function focusSelected() {
        if (windowsModel.count === 0) return
        clampSelectedIndex()
        let win = windowsModel.get(selectedIndex)
        if (!win || !win.address) return

        if (win.address.startsWith("dbus:")) {
            let appClass = win.appClass || ""
            if (appClass === "") return

            Hyprland.dispatch("focuswindow class:" + appClass)

            Qt.callLater(() => {
                let focused = Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWindow
                if (!focused || focused.class !== appClass) {
                    let desktopEntry = manager.findDesktopEntry(appClass.toLowerCase(), appClass)
                    if (desktopEntry && desktopEntry.exec !== "") {
                        Hyprland.dispatch("exec " + desktopEntry.exec)
                    }
                }
            })
        } else {
            Hyprland.dispatch("focuswindow address:" + win.address)
        }
    }

    function applyWindowsList(newList) {
        let wanted = ({})
        for (let i = 0; i < newList.length; i++) wanted[newList[i].address] = true

        for (let i = windowsModel.count - 1; i >= 0; i--) {
            let addr = windowsModel.get(i).address
            if (!wanted[addr]) windowsModel.remove(i)
        }

        let indexOf = ({})
        for (let i = 0; i < windowsModel.count; i++) indexOf[windowsModel.get(i).address] = i

        for (let target = 0; target < newList.length; target++) {
            let addr = newList[target].address
            if (indexOf.hasOwnProperty(addr)) {
                let cur = indexOf[addr]
                if (cur !== target) {
                    windowsModel.move(cur, target, 1)
                    indexOf = ({})
                    for (let k = 0; k < windowsModel.count; k++) indexOf[windowsModel.get(k).address] = k
                }
            } else {
                windowsModel.insert(target, newList[target])
                indexOf = ({})
                for (let k = 0; k < windowsModel.count; k++) indexOf[windowsModel.get(k).address] = k
            }
        }

        for (let i = 0; i < newList.length && i < windowsModel.count; i++) {
            let it = newList[i]
            windowsModel.setProperty(i, "title", it.title)
            windowsModel.setProperty(i, "appClass", it.appClass)
            windowsModel.setProperty(i, "workspaceId", it.workspaceId)
        }

        let arr = []
        for (let i = 0; i < windowsModel.count; i++) {
            let it = windowsModel.get(i)
            arr.push({
                address: it.address,
                title: it.title,
                class: it.appClass,
                workspaceId: it.workspaceId
            })
        }
        windows = arr
    }

    property Process windowsProc: Process {
        id: windowsProc
        command: ["bash", "-c", "hyprctl clients -j"]
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => {
                if (data) windowsProc.output += data
            }
        }

        stderr: SplitParser {
            onRead: data => {}
        }

        onExited: () => {
            windowsProcTimeout.stop()
            let parsed = []
            try {
                parsed = JSON.parse(windowsProc.output || "[]")
            } catch (e) {
                parsed = []
            }

            let list = []
            for (let i = 0; i < parsed.length; i++) {
                let c = parsed[i]
                if (!c) continue
                if (c.class === "quickshell") continue

                list.push({
                    address: c.address,
                    title: c.title || "",
                    appClass: c.class || "",
                    workspaceId: (c.workspace && c.workspace.id !== undefined) ? c.workspace.id : -1
                })
            }

            manager.pendingWindowList = list
            manager.windowsProcReady = true
            manager.applyWindowsIfReady()
            windowsProc.output = ""

            if (manager.pendingRefresh) {
                manager.pendingRefresh = false
                Qt.callLater(() => manager.updateWindows())
            }
        }
    }

    property Process dbusServicesProc: Process {
        id: dbusServicesProc
        command: ["bash", "-c", `
            if ! command -v busctl >/dev/null 2>&1; then
                exit 0
            fi

            busctl --user list --no-pager 2>/dev/null | awk 'NR>1 && !/^:/ {print $1}' | while read service; do
                if echo "$service" | grep -qE 'StatusNotifierItem'; then
                    echo "$service" | sed 's/.*StatusNotifierItem-//' | sed 's/\..*//' | tr '[:upper:]' '[:lower:]'
                elif echo "$service" | grep -q 'org.mpris.MediaPlayer2.'; then
                    echo "$service" | sed 's/org.mpris.MediaPlayer2.//' | tr '[:upper:]' '[:lower:]'
                elif echo "$service" | grep -vqE '^org\.(freedesktop|a11y|gtk|gnome\.SessionManager)'; then
                    echo "$service" | sed 's/^org\.//' | sed 's/^kde\.//' | awk -F. '{print $NF}' | tr '[:upper:]' '[:lower:]'
                fi
            done | grep -v '^$' | grep -vE '^(steamwebhelper|steam-runtime|gamemoded|gamemode|instance[0-9]+)$' | sort -u

            # Fallback: check processes for known apps that may not expose D-Bus services
            if pgrep -x "Discord" >/dev/null || pgrep -f "com.discordapp.Discord" >/dev/null; then echo "process:discord"; fi
            if pgrep -x "slack" >/dev/null || pgrep -f "com.slack.Slack" >/dev/null; then echo "process:slack"; fi
            if pgrep -x "spotify" >/dev/null || pgrep -f "com.spotify.Client" >/dev/null; then echo "process:spotify"; fi
        `]
        running: false
        property var lines: []

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let line = (data || "").trim()
                if (line !== "") {
                    dbusServicesProc.lines.push(line)
                }
            }
        }

        stderr: SplitParser {
            onRead: _data => {}
        }

        onExited: (exitCode) => {
            manager.dbusServicesReady = true
            manager.applyWindowsIfReady()
        }
    }

    property Process desktopEntriesProc: Process {
        id: desktopEntriesProc
        command: ["bash", "-c", `
            for dir in /usr/share/applications ~/.local/share/applications /var/lib/flatpak/exports/share/applications ~/.local/share/flatpak/exports/share/applications; do
                [ -d "$dir" ] || continue
                for f in "$dir"/*.desktop; do
                    [ -f "$f" ] || continue

                    no_display=$(grep -m1 '^NoDisplay=' "$f" 2>/dev/null | cut -d= -f2- | tr -d '[:space:]')
                    [ "$no_display" = "true" ] && continue

                    type=$(grep -m1 '^Type=' "$f" 2>/dev/null | cut -d= -f2- | tr -d '[:space:]')
                    [ -n "$type" ] && [ "$type" != "Application" ] && continue

                    id=$(basename "$f" .desktop)
                    name=$(grep -m1 '^Name=' "$f" 2>/dev/null | cut -d= -f2- || echo "")
                    icon=$(grep -m1 '^Icon=' "$f" 2>/dev/null | cut -d= -f2- || echo "")
                    wm_class=$(grep -m1 '^StartupWMClass=' "$f" 2>/dev/null | cut -d= -f2- || echo "")
                    exec=$(grep -m1 '^Exec=' "$f" 2>/dev/null | cut -d= -f2- | sed 's/%[a-zA-Z]//g' | sed 's/^ *//;s/ *$//' || echo "")
                    dbus=$(grep -m1 '^X-GNOME-DBusName=' "$f" 2>/dev/null | cut -d= -f2- || echo "")
                    categories=$(grep -m1 '^Categories=' "$f" 2>/dev/null | cut -d= -f2- || echo "")

                    [ -n "$name" ] && echo "$id|$name|$icon|$wm_class|$exec|$dbus|$categories"
                done
            done
        `]
        running: false
        property var lines: []

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let line = (data || "").trim()
                if (line !== "") {
                    desktopEntriesProc.lines.push(line)
                }
            }
        }

        stderr: SplitParser {
            onRead: _data => {}
        }

        onExited: (exitCode) => {
            let entries = {}
            if (exitCode === 0 && desktopEntriesProc.lines.length > 0) {
                for (let i = 0; i < desktopEntriesProc.lines.length; i++) {
                    let line = desktopEntriesProc.lines[i]
                    if (!line || line === "") continue
                    let parts = line.split("|")
                    if (parts.length >= 7) {
                        let id = parts[0].trim()
                        let name = parts[1].trim()
                        let icon = parts[2].trim()
                        let wmClass = parts[3].trim()
                        let exec = parts[4].trim()
                        let dbus = parts[5].trim()
                        let categories = parts[6].trim()

                        let shouldExclude = false
                        if (categories !== "") {
                            let cats = categories.split(";")
                            for (let j = 0; j < cats.length; j++) {
                                for (let k = 0; k < manager.excludedCategories.length; k++) {
                                    if (cats[j] === manager.excludedCategories[k]) {
                                        shouldExclude = true
                                        break
                                    }
                                }
                                if (shouldExclude) break
                            }
                        }

                        if (shouldExclude) continue

                        let execBase = exec.split("/").pop().split(" ")[0].toLowerCase()

                        let keys = []
                        if (wmClass !== "") keys.push(wmClass.toLowerCase())
                        if (id !== "") keys.push(id.toLowerCase())
                        if (execBase !== "") keys.push(execBase)
                        if (dbus !== "") keys.push(dbus.toLowerCase())

                        for (let j = 0; j < keys.length; j++) {
                            let key = keys[j]
                            if (key !== "" && !entries[key]) {
                                entries[key] = {
                                    id: id,
                                    name: name,
                                    icon: icon,
                                    wmClass: wmClass,
                                    exec: exec,
                                    execBase: execBase,
                                    dbus: dbus,
                                    categories: categories
                                }
                            }
                        }
                    }
                }
            }

            manager.desktopEntries = entries
            manager.desktopEntriesReady = true
            manager.applyWindowsIfReady()
        }
    }

    function applyWindowsIfReady() {
        if (!pendingWindowList || !windowsProcReady) return
        if (!dbusServicesReady || !desktopEntriesReady) return

        let list = pendingWindowList
        manager.smartMergeApps(list)

        manager.applyWindowsList(list)
        manager.dataReady = true
        if (!manager.selectionLocked) {
            manager.resetToActiveWindow()
        } else {
            manager.clampSelectionToModel()
        }

        if (manager.stepOnOpen === 1) {
            manager.selectNext()
        } else if (manager.stepOnOpen === -1) {
            manager.selectPrevious()
        }
        if (manager.stepOnOpen !== 0) {
            manager.focusSelected()
        }
        manager.stepOnOpen = 0

        pendingWindowList = null
        windowsProcReady = false
        dbusServicesReady = false
        desktopEntriesReady = false
    }

    function findDesktopEntry(serviceName, appClass) {
        if (!serviceName || serviceName === "") return null

        let serviceLower = serviceName.toLowerCase()
        let appClassLower = (appClass || "").toLowerCase()

        let candidates = [
            appClassLower,
            serviceLower,
            serviceName.split('.').pop().toLowerCase()
        ]

        for (let i = 0; i < candidates.length; i++) {
            if (candidates[i] && manager.desktopEntries[candidates[i]]) {
                return manager.desktopEntries[candidates[i]]
            }
        }

        let serviceNormalized = serviceLower.replace(/[-_]/g, '')
        let appNormalized = appClassLower.replace(/[-_]/g, '')

        for (let key in manager.desktopEntries) {
            let keyNormalized = key.replace(/[-_]/g, '')

            if (keyNormalized === serviceNormalized ||
                keyNormalized === appNormalized ||
                (serviceNormalized && serviceNormalized.includes(keyNormalized)) ||
                (keyNormalized && keyNormalized.includes(serviceNormalized))) {
                return manager.desktopEntries[key]
            }
        }

        return null
    }

    function resolveSteamGameIcon(appClass) {
        if (!appClass || appClass === "") return ""

        let classLower = appClass.toLowerCase()
        if (!classLower.startsWith("steam_app_")) return ""

        let appId = classLower.replace("steam_app_", "")
        if (appId === "") return ""

        let home = Quickshell.env("HOME") || ""
        if (home === "") return ""

        let basePath = home + "/.local/share/Steam/appcache/librarycache/" + appId

        // Cannot do actual file search from QML; fall back to normal icon resolution
        return ""
    }

    function guessAppClassFromDBus(serviceName) {
        if (!serviceName || serviceName === "") return ""

        // Map Steam helper to Steam class so the icon shows when the window is closed
        // and deduplicates when the window is open
        if (serviceName.toLowerCase() === "launchalongsidesteam") {
            return "Steam"
        }

        if (serviceName.startsWith("process:")) {
             let name = serviceName.substring(8)
             return name.charAt(0).toUpperCase() + name.slice(1).toLowerCase()
        }

        let desktopEntry = manager.findDesktopEntry(serviceName, "")
        if (desktopEntry && desktopEntry.wmClass !== "") {
            return desktopEntry.wmClass
        }

        let parts = serviceName.split(/[-._]/)
        let result = ""
        for (let i = 0; i < parts.length; i++) {
            let part = parts[i]
            if (part.length > 0) {
                result += part.charAt(0).toUpperCase() + part.slice(1).toLowerCase()
            }
        }
        return result || serviceName.charAt(0).toUpperCase() + serviceName.slice(1).toLowerCase()
    }

    function smartMergeApps(windowList) {
        let existingKeys = {}

        for (let i = 0; i < windowList.length; i++) {
            let appClass = (windowList[i].appClass || "").toLowerCase()
            if (appClass === "") continue

            existingKeys[appClass] = true

            let desktopEntry = manager.desktopEntries[appClass]
            if (desktopEntry) {
                if (desktopEntry.id) existingKeys[desktopEntry.id.toLowerCase()] = true
                if (desktopEntry.execBase) existingKeys[desktopEntry.execBase] = true
                if (desktopEntry.dbus) existingKeys[desktopEntry.dbus.toLowerCase()] = true
            }

            existingKeys[appClass.replace(/[-_]/g, '')] = true
        }

        if (dbusServicesProc.lines && dbusServicesProc.lines.length > 0) {
            for (let i = 0; i < dbusServicesProc.lines.length; i++) {
                let serviceName = dbusServicesProc.lines[i]
                if (!serviceName || serviceName === "") continue

                if (serviceName.startsWith("process:")) {
                    let appName = serviceName.split(":")[1]
                    let serviceLower = appName.toLowerCase()

                    if (existingKeys[serviceLower]) continue

                    let appClass = manager.guessAppClassFromDBus(serviceName)
                    let appClassLower = appClass.toLowerCase()

                    let desktopEntry = manager.findDesktopEntry(appName, appClass)
                    if (desktopEntry) {
                         let title = desktopEntry.name || appClass
                         windowList.push({
                            address: "dbus:" + appClassLower,
                            title: title,
                            appClass: appClass,
                            workspaceId: -1
                        })
                        existingKeys[appClassLower] = true
                    }
                    continue
                }

                let serviceLower = serviceName.toLowerCase()
                let serviceNormalized = serviceLower.replace(/[-_]/g, '')

                if (existingKeys[serviceLower] || existingKeys[serviceNormalized]) {
                    continue
                }

                let appClass = manager.guessAppClassFromDBus(serviceName)
                let appClassLower = appClass.toLowerCase()

                if (appClassLower === "" || existingKeys[appClassLower]) continue

                let desktopEntry = manager.findDesktopEntry(serviceName, appClass)

                // Not in desktopEntries = already filtered out by category exclusion
                if (!desktopEntry) continue

                let isAllowedBackground = false
                if (desktopEntry.categories && desktopEntry.categories !== "") {
                    let cats = desktopEntry.categories.split(";")
                    for (let j = 0; j < cats.length; j++) {
                        for (let k = 0; k < manager.allowedBackgroundCategories.length; k++) {
                            if (cats[j] === manager.allowedBackgroundCategories[k]) {
                                isAllowedBackground = true
                                break
                            }
                        }
                        if (isAllowedBackground) break
                    }
                }

                if (!isAllowedBackground) continue

                let title = appClass
                if (desktopEntry && desktopEntry.name !== "") {
                    title = desktopEntry.name
                }

                windowList.push({
                    address: "dbus:" + appClassLower,
                    title: title,
                    appClass: appClass,
                    workspaceId: -1
                })
                existingKeys[appClassLower] = true
            }
        }
    }

    property Timer windowsProcTimeout: Timer {
        interval: 1200
        running: false
        repeat: false
        onTriggered: {
            if (windowsProc.running) {
                windowsProc.running = false
            }
            windowsProc.output = ""
            pendingRefresh = false
        }
    }
}
