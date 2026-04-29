import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../ui" as UI
import "../lib" as Theme

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
    property var filteredApps: []
    property var runningApps: []
    property bool appsLoaded: false
    property bool isLoading: false

    property string searchText: ""

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
            return
        }

        if (!isLoading) {
            isLoading = true
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

    function filterApps() {
        if (searchText === "") {
            filteredApps = apps
        } else {
            let search = searchText.toLowerCase()
            // short = prefix (fast), long = substring
            if (search.length <= 2) {
                filteredApps = apps.filter(app =>
                    app.name.toLowerCase().startsWith(search)
                )
            } else {
                filteredApps = apps.filter(app =>
                    app.name.toLowerCase().includes(search)
                )
            }
        }
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

    property var _runningAppsCache: ({})
    property var _lastRunningAppsHash: ""

    function isAppRunning(appName) {
        let currentHash = runningApps.join("|")
        if (_lastRunningAppsHash !== currentHash) {
            _runningAppsCache = {}
            for (let i = 0; i < runningApps.length; i++) {
                let running = runningApps[i].toLowerCase()
                _runningAppsCache[running] = true
            }
            _lastRunningAppsHash = currentHash
        }

        let name = appName.toLowerCase()
        if (_runningAppsCache[name]) {
            return true
        }
        for (let key in _runningAppsCache) {
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
                if (!appsProcess.output || appsProcess.output.trim().length === 0) {
                    root.isLoading = false
                    appsProcess.output = ""
                    return
                }

                let parsed = JSON.parse(appsProcess.output)

                if (!Array.isArray(parsed)) {
                    root.isLoading = false
                    appsProcess.output = ""
                    return
                }

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
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: 300 }
                    NumberAnimation {
                        property: "opacity"
                        duration: 400
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
                    if (app && app.exec) {
                        Hyprland.dispatch("exec " + app.exec)
                        modeManager.closeAllModes()
                    }
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
                            let app = root.filteredApps[currentIndex]
                            if (app && app.exec) {
                                Hyprland.dispatch("exec " + app.exec)
                                modeManager.closeAllModes()
                            }
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        searchField.forceActiveFocus()
                        modeManager.closeAllModes()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        if (currentIndex > 0) {
                            currentIndex--
                            positionViewAtIndex(currentIndex, GridView.Visible)
                        } else {
                            currentIndex = count - 1
                            positionViewAtIndex(currentIndex, GridView.Visible)
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right) {
                        if (currentIndex < count - 1) {
                            currentIndex++
                            positionViewAtIndex(currentIndex, GridView.Visible)
                        } else {
                            currentIndex = 0
                            positionViewAtIndex(currentIndex, GridView.Visible)
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        if (currentIndex >= Math.floor(width / cellWidth)) {
                            currentIndex -= Math.floor(width / cellWidth)
                            positionViewAtIndex(currentIndex, GridView.Visible)
                        } else {
                            if (searchField && searchField.searchFieldItem) {
                                searchField.searchFieldItem.forceActiveFocus()
                            }
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        let colsPerRow = Math.floor(width / cellWidth)
                        if (colsPerRow > 0 && currentIndex < count - colsPerRow) {
                            currentIndex += colsPerRow
                            positionViewAtIndex(currentIndex, GridView.Visible)
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

                    // modelData passthrough for custom components
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

                        onLaunchApp: (app) => {
                            if (app && app.exec) {
                                Hyprland.dispatch("exec " + app.exec)
                                modeManager.closeAllModes()
                            }
                        }

                        onResetAutoCloseTimer: () => {
                            modeManager.bump()
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
                text: root.isLoading ? "読み込み中..." : (root.filteredApps.length + " 個のアプリ")
                color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                font.pixelSize: root.typo ? root.typo.sizeSmall : 11
                opacity: 0.7
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
