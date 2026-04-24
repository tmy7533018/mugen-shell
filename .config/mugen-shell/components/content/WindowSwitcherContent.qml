import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../ui" as UI
import "../common" as Common

FocusScope {
    id: root

    required property var modeManager
    required property var windowManager
    required property var theme
    required property var typo
    required property var settingsManager
    required property real barWidth

    // Hyprland follow_mouse=1 causes focus to snap back to cursor position,
    // so we temporarily disable it while window-switcher is open to ensure
    // reliable window selection.
    property int _followMousePrev: 1
    property bool _followMousePrevKnown: false
    property bool _followMouseDisablePending: false
    property bool _followMouseRestoring: false
    property int _followMouseRestoreTarget: 1
    property int _followMouseRestoreAttempts: 0
    readonly property int _followMouseRestoreMaxAttempts: 6

    Process {
        id: getFollowMouseProc
        running: false
        property string output: ""
        command: ["bash", "-lc", "hyprctl getoption input:follow_mouse -j 2>/dev/null || true"]

        stdout: SplitParser {
            onRead: data => {
                if (data) getFollowMouseProc.output += data
            }
        }

        onExited: () => {
            let raw = (getFollowMouseProc.output || "").trim()
            getFollowMouseProc.output = ""
            try {
                if (raw.length > 0) {
                    let j = JSON.parse(raw)
                    if (j && j.int !== undefined) {
                        root._followMousePrev = parseInt(j.int)
                        root._followMousePrevKnown = true
                    }
                }
            } catch (_e) {
                // ignore
            }

            // Disable follow_mouse only after prev value is recorded
            if (root._followMouseDisablePending && modeManager && modeManager.isMode("window-switcher")) {
                root._followMouseDisablePending = false
                root.setFollowMouse(0)
            }
        }
    }

    function setFollowMouse(value) {
        // NOTE: Preserve exit code for restore retry logic
        setFollowMouseProc.command = ["bash", "-lc", "hyprctl keyword input:follow_mouse " + value + " >/dev/null 2>&1"]
        setFollowMouseProc.running = true
    }

    Process {
        id: setFollowMouseProc
        running: false
        command: ["bash", "-lc", "true"]
        onExited: (exitCode) => {
            if (root._followMouseRestoring) {
                if (exitCode !== 0) {
                    root.scheduleFollowMouseRestoreRetry()
                    return
                }
                verifyFollowMouseProc.output = ""
                verifyFollowMouseProc.running = true
            }
        }
    }

    Process {
        id: verifyFollowMouseProc
        running: false
        property string output: ""
        command: ["bash", "-lc", "hyprctl getoption input:follow_mouse -j 2>/dev/null || true"]

        stdout: SplitParser {
            onRead: data => {
                if (data) verifyFollowMouseProc.output += data
            }
        }

        onExited: () => {
            let raw = (verifyFollowMouseProc.output || "").trim()
            verifyFollowMouseProc.output = ""
            let cur = null
            try {
                if (raw.length > 0) {
                    let j = JSON.parse(raw)
                    if (j && j.int !== undefined) {
                        cur = parseInt(j.int)
                    }
                }
            } catch (_e) {
                cur = null
            }

            if (cur !== null && cur === root._followMouseRestoreTarget) {
                root._followMouseRestoring = false
                root._followMouseRestoreAttempts = 0
                followMouseProcTimeout.stop()
                return
            }
            root.scheduleFollowMouseRestoreRetry()
        }
    }

    Timer {
        id: restoreFollowMouseTimer
        interval: 150
        running: false
        repeat: false
        onTriggered: {
            // Fall back to 1 if previous value was never captured
            root.startFollowMouseRestore(root._followMousePrevKnown ? root._followMousePrev : 1)
        }
    }

    Timer {
        id: followMouseRestoreRetryTimer
        interval: 220
        running: false
        repeat: false
        onTriggered: {
            if (!root._followMouseRestoring) return
            if (root._followMouseRestoreAttempts >= root._followMouseRestoreMaxAttempts) {
                console.warn("follow_mouse restore failed after retries. target=", root._followMouseRestoreTarget)
                root._followMouseRestoring = false
                root._followMouseRestoreAttempts = 0
                followMouseProcTimeout.stop()
                return
            }
            root._followMouseRestoreAttempts += 1
            root.setFollowMouse(root._followMouseRestoreTarget)
        }
    }

    Timer {
        id: followMouseProcTimeout
        interval: 1200
        running: false
        repeat: false
        onTriggered: {
            // Kill stuck processes to avoid deadlock
            if (getFollowMouseProc.running) getFollowMouseProc.running = false
            if (setFollowMouseProc.running) setFollowMouseProc.running = false
            if (verifyFollowMouseProc.running) verifyFollowMouseProc.running = false

            root._followMouseDisablePending = false

            // If stuck during restore phase, retry within budget
            if (root._followMouseRestoring) {
                root.scheduleFollowMouseRestoreRetry()
            }
        }
    }

    function startFollowMouseRestore(targetValue) {
        root._followMouseRestoreTarget = targetValue
        root._followMouseRestoreAttempts = 0
        root._followMouseRestoring = true
        followMouseRestoreRetryTimer.stop()
        root.setFollowMouse(root._followMouseRestoreTarget)
        followMouseProcTimeout.restart()
    }

    function scheduleFollowMouseRestoreRetry() {
        if (!root._followMouseRestoring) return
        followMouseRestoreRetryTimer.restart()
    }

    readonly property int iconTileSize: modeManager.scale(72)
    readonly property int iconTileSpacing: modeManager.scale(12)
    readonly property int innerSidePadding: 64
    readonly property int minSurfaceWidth: 200
    readonly property int maxSurfaceWidth: {
        if (barWidth && barWidth > 0) return Math.max(320, barWidth - 40)
        return 1000
    }

    readonly property int windowCount: (windowManager && windowManager.windowsModel) ? windowManager.windowsModel.count : 0
    readonly property int iconRowWidth: {
        if (windowCount <= 0) return iconTileSize
        return windowCount * iconTileSize + Math.max(0, windowCount - 1) * iconTileSpacing
    }
    readonly property int targetSurfaceWidth: {
        let w = iconRowWidth + innerSidePadding
        w = Math.max(minSurfaceWidth, w)
        w = Math.min(maxSurfaceWidth, w)
        return w
    }
    readonly property int targetListWidth: Math.max(0, targetSurfaceWidth - innerSidePadding)
    readonly property int targetOuterMargin: {
        if (!barWidth || barWidth <= 0) return 670
        let m = Math.round((barWidth - targetSurfaceWidth) / 2)
        return Math.max(10, m)
    }

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(120),
        "leftMargin": targetOuterMargin,
        "rightMargin": targetOuterMargin,
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })

    function ipcAction(action) {
        if (!windowManager) return

        if (action === "next") {
            windowManager.stepOnOpen = 1
        } else if (action === "prev") {
            windowManager.stepOnOpen = -1
        } else {
            windowManager.stepOnOpen = 0
        }

        windowManager.updateWindows()
    }

    function bumpAutoClose() {
        if (modeManager) modeManager.bump()
    }

// Periodically sync window list while visible as insurance against missed IPC events
    Timer {
        id: liveRefreshTimer
        interval: 700
        running: modeManager && modeManager.isMode("window-switcher")
        repeat: true
        onTriggered: {
            if (windowManager) windowManager.updateWindows()
        }
    }

    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("window-switcher", root)
        }
        loadAppCache()
    }

    // Reuse icon cache from list-apps.py (GTK/Gio-resolved icon paths)
    property var appCache: []
    property var classToIconCache: ({})
    property bool appCacheLoaded: false

    function cacheFilePath() {
        let cacheHome = Quickshell.env("XDG_CACHE_HOME")
        let home = Quickshell.env("HOME")
        if (!cacheHome || cacheHome === "") {
            cacheHome = (home && home !== "") ? (home + "/.cache") : "/tmp"
        }
        return cacheHome + "/mugen-shell/apps.json"
    }

    function loadAppCache() {
        appCacheReader.output = ""
        appCacheReader.command = ["bash", "-c", "cat '" + cacheFilePath() + "' 2>/dev/null || true"]
        appCacheReader.running = true
    }

    function ensureAppCacheGenerated() {
        if (!appCacheGenerator.running) {
            appCacheGenerator.running = true
        }
    }

    function normalize(s) {
        return (s || "").toString().toLowerCase().trim()
    }

    function basenameFromExec(execStr) {
        let s = (execStr || "").toString().trim()
        if (s === "") return ""
        let first = s.split(/\s+/)[0]
        let parts = first.split("/")
        return normalize(parts[parts.length - 1])
    }

    function resolveIconForClass(className) {
        let key = normalize(className)
        if (key === "") return ""

        // Skip caching if appCache hasn't loaded yet; will re-resolve after load
        if (!appCacheLoaded || appCache.length === 0) {
            return ""
        }

        if (classToIconCache.hasOwnProperty(key)) {
            return classToIconCache[key] || ""
        }

        for (let i = 0; i < appCache.length; i++) {
            let app = appCache[i]
            if (!app) continue
            let wmClass = normalize(app.wmClass || "")
            if (wmClass !== "" && wmClass === key) {
                let iconPath = (app.icon || "").toString()
                if (iconPath !== "") {
                    let newCache = Object.assign({}, classToIconCache)
                    newCache[key] = iconPath
                    classToIconCache = newCache
                    return iconPath
                }
            }

            let aliases = app.wmClassAliases || []
            for (let j = 0; j < aliases.length; j++) {
                let alias = normalize(aliases[j] || "")
                if (alias !== "" && alias === key) {
                    let iconPath = (app.icon || "").toString()
                    if (iconPath !== "") {
                        let newCache = Object.assign({}, classToIconCache)
                        newCache[key] = iconPath
                        classToIconCache = newCache
                        return iconPath
                    }
                }
            }
        }

        // 1.5. Proton/Wine games: .exe class names need fuzzy matching against wmClassAliases
        if (key.endsWith(".exe")) {
            let cleanKey = key.replace(/\.exe$/, "")
                .replace(/-win64-shipping$/, "")
                .replace(/-win32-shipping$/, "")
                .replace(/[-_]/g, "")
                .toLowerCase()

            if (cleanKey.length >= 4) {
                for (let i = 0; i < appCache.length; i++) {
                    let app = appCache[i]
                    if (!app) continue
                    let iconPath = (app.icon || "").toString()
                    if (iconPath === "") continue

                    let aliases = app.wmClassAliases || []
                    for (let j = 0; j < aliases.length; j++) {
                        let alias = (aliases[j] || "").replace(/[-_]/g, "").toLowerCase()
                        if (alias !== "" && (alias === cleanKey || alias.includes(cleanKey) || cleanKey.includes(alias))) {
                            let newCache = Object.assign({}, classToIconCache)
                            newCache[key] = iconPath
                            classToIconCache = newCache
                            return iconPath
                        }
                    }
                }
            }
        }

        if (key.startsWith("steam_app_")) {
            let appId = key.replace("steam_app_", "")
            if (appId !== "") {
                let home = Quickshell.env("HOME") || ""
                if (home !== "") {
                    let iconPath = home + "/.local/share/icons/hicolor/256x256/apps/steam_icon_" + appId + ".png"
                    let newCache = Object.assign({}, classToIconCache)
                    newCache[key] = iconPath
                    classToIconCache = newCache
                    return iconPath
                }
            }
        }

        for (let i = 0; i < appCache.length; i++) {
            let app = appCache[i]
            if (!app) continue
            let iconPath = (app.icon || "").toString()
            if (iconPath === "") continue

            let execBase = basenameFromExec(app.exec)
            if (execBase !== "" && execBase === key) {
                let newCache = Object.assign({}, classToIconCache)
                newCache[key] = iconPath
                classToIconCache = newCache
                return iconPath
            }
        }

        for (let i = 0; i < appCache.length; i++) {
            let app = appCache[i]
            if (!app) continue
            let iconPath = (app.icon || "").toString()
            if (iconPath === "") continue

            let appName = normalize(app.name)
            if (appName !== "" && appName === key) {
                let newCache = Object.assign({}, classToIconCache)
                newCache[key] = iconPath
                classToIconCache = newCache
                return iconPath
            }
        }

        // Cache empty result to avoid repeated lookups
        let newCache = Object.assign({}, classToIconCache)
        newCache[key] = ""
        classToIconCache = newCache
        return ""
    }

    Process {
        id: appCacheReader
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => {
                if (data) appCacheReader.output += data
            }
        }

        onExited: () => {
            let raw = (appCacheReader.output || "").trim()
            appCacheReader.output = ""

            if (!raw || raw.length === 0) {
                root.appCache = []
                root.classToIconCache = ({})
                root.ensureAppCacheGenerated()
                return
            }

            try {
                let parsed = JSON.parse(raw)
                if (Array.isArray(parsed)) {
                    root.appCache = parsed
                    // Clear icon caches to force re-resolution with new app data
                    root.classToIconCache = ({})
                    if (windowManager) windowManager.iconCache = ({})
                    root.appCacheLoaded = true
                    if (modeManager && modeManager.isMode("window-switcher")) {
                        Qt.callLater(() => preResolveIcons())
                    }
                } else {
                    root.appCache = []
                    root.classToIconCache = ({})
                    root.appCacheLoaded = false
                }
            } catch (e) {
                root.appCache = []
                root.classToIconCache = ({})
                root.appCacheLoaded = false
            }
        }
    }

    Process {
        id: appCacheGenerator
        command: ["python3", Quickshell.shellDir + "/scripts/list-apps.py"]
        running: false

        onExited: () => {
            root.loadAppCache()
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (!modeManager) return

            if (modeManager.isMode("window-switcher")) {
                windowManager.isActive = true
                windowManager.stepOnOpen = 0
                windowManager.selectionLocked = true

                // NOTE: Show UI immediately even before windows are fetched to avoid empty bar flash
                switcherLayer.iconsReady = true

                root._followMouseRestoring = false
                root._followMouseRestoreAttempts = 0
                followMouseRestoreRetryTimer.stop()

                root._followMouseDisablePending = true
                getFollowMouseProc.output = ""
                getFollowMouseProc.running = true
                followMouseProcTimeout.restart()

                if (windowManager.dataReady) {
                    windowManager.resetToActiveWindow()
                    preResolveIcons()
                    switcherLayer.iconsReady = true
                }
                // Always fetch latest windows on open to avoid stale data from quickshell startup
                windowManager.updateWindows()

                Qt.callLater(() => {
                    switcherLayer.forceActiveFocus()
                })

            } else {
                windowManager.isActive = false
                windowManager.selectionLocked = false
                // Delay restore to avoid immediate refocus race
                restoreFollowMouseTimer.restart()
                switcherLayer.iconsReady = false
                followMouseProcTimeout.stop()
            }
        }
    }

    Connections {
        target: windowManager
        function onWindowsChanged() {
            preResolveIcons()

            if (modeManager && modeManager.isMode("window-switcher") && !switcherLayer.iconsReady) {
                switcherLayer.iconsReady = true
            }
        }
    }

    function preResolveIcons() {
        if (!windowManager || !windowManager.windowsModel) return
        let cache = (windowManager.iconCache && typeof windowManager.iconCache === "object") ? windowManager.iconCache : ({})
        let newCache = Object.assign({}, cache)
        let changed = false
        for (let i = 0; i < windowManager.windowsModel.count; i++) {
            let win = windowManager.windowsModel.get(i)
            if (!win || !win.appClass) continue
            let key = normalize(win.appClass)
            if (key === "") continue
            if (!newCache.hasOwnProperty(key)) {
                let iconPath = resolveIconForClass(win.appClass)
                newCache[key] = iconPath || ""
                changed = true
            }
        }
        // Must reassign (not mutate in-place) to trigger property change notification
        if (changed) {
            windowManager.iconCache = newCache
        }
    }

    function getCachedIconPath(className) {
        if (!className) return ""
        let key = normalize(className)
        if (windowManager && windowManager.iconCache && windowManager.iconCache.hasOwnProperty(key)) {
            return windowManager.iconCache[key] || ""
        }
        return resolveIconForClass(className) || ""
    }

    MouseArea {
        anchors.fill: parent
        z: 1
        enabled: modeManager && modeManager.isMode("window-switcher")
        visible: enabled
        hoverEnabled: true

        onPositionChanged: {
            root.bumpAutoClose()
        }

        onClicked: {
            if (modeManager) modeManager.closeAllModes()
            Hyprland.dispatch("submap reset")
        }
    }

    Item {
        id: switcherLayer
        anchors.fill: parent
        anchors.leftMargin: modeManager.scale(32)
        anchors.rightMargin: modeManager.scale(32)
        anchors.topMargin: 6
        anchors.bottomMargin: modeManager.currentBarSize.bottomMargin
        z: 2

        opacity: 0
        visible: opacity > 0.01

        property bool iconsReady: false

        states: [
            State {
                name: "visible"
                when: modeManager && modeManager.isMode("window-switcher") && switcherLayer.iconsReady
                PropertyChanges { target: switcherLayer; opacity: 1.0 }
            }
        ]

        transitions: [
            Transition {
                from: "visible"
                to: ""
                NumberAnimation {
                    property: "opacity"
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    // Wait for bar expand animation before fading in
                    PauseAnimation { duration: 300 }
                    NumberAnimation {
                        property: "opacity"
                        duration: 400
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        ]

        focus: modeManager && modeManager.isMode("window-switcher")

        Keys.onPressed: (event) => {
            if (!modeManager || !modeManager.isMode("window-switcher")) {
                event.accepted = false
                return
            }

            if (event.key === Qt.Key_Tab) {
                root.bumpAutoClose()
                if (event.modifiers & Qt.ShiftModifier) {
                    windowManager.selectPrevious()
                } else {
                    windowManager.selectNext()
                }
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Left) {
                root.bumpAutoClose()
                windowManager.selectPrevious()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Right) {
                root.bumpAutoClose()
                windowManager.selectNext()
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Escape) {
                root.bumpAutoClose()
                modeManager.closeAllModes()
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.bumpAutoClose()
                windowManager.focusSelected()
                modeManager.closeAllModes()
                event.accepted = true
                return
            }

            event.accepted = false
        }

        ListView {
            id: iconList
            anchors.centerIn: parent
            height: modeManager.scale(72)
            width: root.targetListWidth
            visible: !(windowManager && windowManager.dataReady && root.windowCount === 0)
            enabled: visible

            orientation: ListView.Horizontal
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            spacing: root.iconTileSpacing
            model: windowManager ? windowManager.windowsModel : null

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 420; easing.type: Easing.InOutCubic }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0.0; duration: 320; easing.type: Easing.InOutCubic }
            }
            displaced: Transition {
                NumberAnimation { properties: "x"; duration: 320; easing.type: Easing.InOutCubic }
            }

            readonly property real centerInset: Math.max(0, (width - contentWidth) / 2)
            leftMargin: centerInset
            rightMargin: centerInset

            onCountChanged: {
                if (count > 0 && windowManager) {
                    positionViewAtIndex(windowManager.selectedIndex, ListView.Contain)
                }
            }

            Connections {
                target: windowManager
                function onSelectedIndexChanged() {
                    if (iconList.count > 0) {
                        iconList.positionViewAtIndex(windowManager.selectedIndex, ListView.Contain)
                    }
                }
            }

            delegate: Item {
                id: iconDelegate
                width: root.iconTileSize
                height: root.iconTileSize

                readonly property bool isSelected: windowManager && index === windowManager.selectedIndex
                readonly property string className: (model && model.appClass) ? model.appClass : ""
                readonly property string iconName: className ? className.toLowerCase() : ""
                onClassNameChanged: {
                    if (iconCell) iconCell.refreshIcon()
                }
                // Skip per-icon fade: delegates get recreated on update causing flicker

                property bool hovered: false

                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    color: "transparent"
                    border.width: (iconDelegate.isSelected || iconDelegate.hovered) ? 2 : 0
                    border.color: iconDelegate.isSelected
                        ? (theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 0.9))
                        : (theme ? Qt.rgba(theme.textFaint.r, theme.textFaint.g, theme.textFaint.b, 0.35) : Qt.rgba(1, 1, 1, 0.12))
                    Behavior on border.width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }

                Item {
                    id: iconCell
                    anchors.centerIn: parent
                    width: 40
                    height: 40

                    // NOTE: Using event-driven updates instead of binding to avoid
                    // Binding loop with cache-updating resolve functions.
                    property string iconPath: ""

                    function refreshIcon() {
                        iconPath = root.getCachedIconPath(className)
                    }

                    function markIconBad() {
                        // Cache empty path to prevent repeated WARN spam for this class
                        let key = root.normalize(className)
                        if (key !== "" && root.classToIconCache) {
                            let newCache = Object.assign({}, root.classToIconCache)
                            newCache[key] = ""
                            root.classToIconCache = newCache
                        }
                        if (key !== "" && windowManager && windowManager.iconCache) {
                            let newCache2 = Object.assign({}, windowManager.iconCache)
                            newCache2[key] = ""
                            windowManager.iconCache = newCache2
                        }
                        refreshIcon()
                    }

                    Image {
                        id: appIcon
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        source: iconCell.iconPath ? (iconCell.iconPath.startsWith("file://") ? iconCell.iconPath : "file://" + iconCell.iconPath) : ""
                        asynchronous: true
                        cache: true

                        sourceSize.width: 80
                        sourceSize.height: 80

                        onStatusChanged: {
                            if (status === Image.Error) {
                                Qt.callLater(() => {
                                    iconCell.markIconBad()
                                })
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: appIcon.source === "" || appIcon.status === Image.Error
                        text: className && className.length > 0 ? className.charAt(0).toUpperCase() : "?"
                        color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                        font.family: typo ? typo.clockStyle.family : "M PLUS 2"
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        opacity: 0.95
                    }

                    Component.onCompleted: refreshIcon()

                    Connections {
                        target: windowManager
                        function onWindowsChanged() { iconCell.refreshIcon() }
                        function onIconCacheChanged() { iconCell.refreshIcon() }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        if (!windowManager) return
                        windowManager.selectedIndex = index
                        windowManager.focusSelected()
                        if (modeManager) modeManager.closeAllModes()
                    }
                    onEntered: iconDelegate.hovered = true
                    onExited: iconDelegate.hovered = false
                }
            }
        }

        Item {
            anchors.centerIn: parent
            height: modeManager.scale(72)
            width: root.targetListWidth
            visible: windowManager && windowManager.dataReady && root.windowCount === 0

            Common.GlowText {
                anchors.centerIn: parent
                text: "No windows"
                color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70)
                font.pixelSize: 18
                font.weight: Font.Light
                opacity: 0.5
                width: parent ? parent.width : 260
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                maximumLineCount: 1
                horizontalAlignment: Text.AlignHCenter

                glowColor: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.30) : Qt.rgba(0.65, 0.55, 0.85, 0.30)
                glowRadius: 6
                glowSpread: 0.25
                glowSamples: 13
                enableGlow: true
            }
        }
    }

    Component.onDestruction: {
        // Best-effort restore on abnormal exit/reload so follow_mouse doesn't stay disabled
        root.startFollowMouseRestore(root._followMousePrevKnown ? root._followMousePrev : 1)
    }
}
