import QtQuick
import "../../lib" as Theme

FocusScope {
    id: menuRoot

    property var theme
    property var typo

    property var app: null
    property var menuItems: []
    property int currentIndex: -1
    property bool shown: false

    signal launchRequested(var app)
    signal actionRequested(var app, string actionExec)
    signal favoriteToggled(var app)
    signal openLocationRequested(var app)
    signal uninstallRequested(var app)
    signal dismissed()

    readonly property int itemHeight: 34
    readonly property int sepHeight: 9
    readonly property int menuPadding: 6
    readonly property color dangerColor: Qt.rgba(0.95, 0.55, 0.62, 1.0)

    width: 240
    height: {
        let h = menuPadding * 2
        for (let i = 0; i < menuItems.length; i++) {
            h += menuItems[i].kind === "sep" ? sepHeight : itemHeight
        }
        return h
    }

    opacity: 0
    scale: 0.96
    transformOrigin: Item.TopLeft
    visible: opacity > 0.01

    states: State {
        name: "open"
        when: menuRoot.shown
        PropertyChanges { target: menuRoot; opacity: 1.0; scale: 1.0 }
    }

    transitions: [
        Transition {
            to: "open"
            NumberAnimation {
                properties: "opacity,scale"
                duration: Theme.Motion.fast
                easing.type: Easing.OutCubic
            }
        },
        Transition {
            from: "open"
            NumberAnimation {
                properties: "opacity,scale"
                duration: Theme.Motion.micro
                easing.type: Easing.OutCubic
            }
        }
    ]

    function openFor(appData, isFav) {
        app = appData
        menuItems = buildItems(appData, isFav)
        currentIndex = -1
        shown = true
        menuRoot.forceActiveFocus()
    }

    function dismiss() {
        if (!shown) return
        shown = false
        dismissed()
    }

    function buildItems(a, fav) {
        let list = [{ kind: "open", label: "Open" }]
        let acts = (a && a.actions) ? a.actions : []
        for (let i = 0; i < acts.length; i++) {
            list.push({ kind: "action", label: acts[i].name, exec: acts[i].exec })
        }
        list.push({ kind: "sep" })
        list.push({ kind: "favorite", label: fav ? "Remove from Favorites" : "Add to Favorites" })
        if (a && a.desktopFile) {
            list.push({ kind: "location", label: "Open File Location" })
            list.push({ kind: "sep" })
            list.push({ kind: "uninstall", label: "Uninstall", danger: true })
        }
        return list
    }

    function activate(idx) {
        let it = menuItems[idx]
        if (!it || it.kind === "sep") return
        let a = app
        dismiss()
        if (it.kind === "open") {
            launchRequested(a)
        } else if (it.kind === "action") {
            actionRequested(a, it.exec || "")
        } else if (it.kind === "favorite") {
            favoriteToggled(a)
        } else if (it.kind === "location") {
            openLocationRequested(a)
        } else if (it.kind === "uninstall") {
            uninstallRequested(a)
        }
    }

    function moveSelection(step) {
        if (menuItems.length === 0) return
        let idx = currentIndex
        for (let n = 0; n < menuItems.length; n++) {
            idx = (idx + step + menuItems.length) % menuItems.length
            if (menuItems[idx].kind !== "sep") {
                currentIndex = idx
                return
            }
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Down || event.key === Qt.Key_J || event.key === Qt.Key_Tab) {
            moveSelection(1)
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K || event.key === Qt.Key_Backtab) {
            moveSelection(-1)
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (currentIndex >= 0) activate(currentIndex)
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Menu) {
            dismiss()
        }
        // swallow everything else so keystrokes don't leak into the search field
        event.accepted = true
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.Motion.radiusCard
        // dark scrim in both modes: the menu sits over unblurred app icons,
        // where light mode's clear-glass surfaces would be unreadable
        color: menuRoot.theme && menuRoot.theme.themeMode === "light"
            ? Qt.rgba(0.12, 0.10, 0.18, 0.62)
            : Qt.rgba(0.05, 0.03, 0.10, 0.85)
        border.width: 1
        border.color: menuRoot.theme ? menuRoot.theme.surfaceBorder : Qt.rgba(0.70, 0.65, 0.90, 0.3)
    }

    Column {
        anchors.fill: parent
        anchors.margins: menuRoot.menuPadding

        Repeater {
            model: menuRoot.menuItems

            delegate: Item {
                id: entry

                required property var modelData
                required property int index

                readonly property bool isSep: modelData.kind === "sep"
                readonly property bool isDanger: modelData.danger === true

                width: parent.width
                height: isSep ? menuRoot.sepHeight : menuRoot.itemHeight

                Rectangle {
                    visible: entry.isSep
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 8
                    height: 1
                    color: menuRoot.theme ? menuRoot.theme.surfaceBorder : Qt.rgba(0.70, 0.65, 0.90, 0.3)
                    opacity: 0.5
                }

                Rectangle {
                    visible: !entry.isSep && entry.index === menuRoot.currentIndex
                    anchors.fill: parent
                    radius: Theme.Motion.radiusSmall
                    color: entry.isDanger
                        ? Qt.rgba(0.90, 0.45, 0.55, 0.22)
                        : (menuRoot.theme
                            ? Qt.rgba(menuRoot.theme.accent.r, menuRoot.theme.accent.g, menuRoot.theme.accent.b, 0.22)
                            : Qt.rgba(0.65, 0.55, 0.85, 0.22))
                }

                Text {
                    visible: !entry.isSep
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry.modelData.label || ""
                    elide: Text.ElideRight
                    color: entry.isDanger
                        ? menuRoot.dangerColor
                        : (menuRoot.theme ? menuRoot.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))
                    font.pixelSize: menuRoot.typo ? menuRoot.typo.sizeNormal : 13
                    font.family: menuRoot.typo ? menuRoot.typo.fontFamily : "M PLUS 2"
                }

                MouseArea {
                    enabled: !entry.isSep && menuRoot.shown
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: menuRoot.currentIndex = entry.index
                    onClicked: menuRoot.activate(entry.index)
                }
            }
        }
    }
}
