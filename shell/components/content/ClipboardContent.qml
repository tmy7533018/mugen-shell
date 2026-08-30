pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import "../ui" as UI
import "../common" as Common
import "../../lib" as Theme

FocusScope {
    id: root
    
    required property var modeManager
    required property var clipboardManager
    property var theme
    property var icons
    
    readonly property var requiredBarSize: ({
        "height": modeManager.scale(480),
        "leftMargin": modeManager.scale(700),
        "rightMargin": modeManager.scale(700),
        "topMargin": modeManager.normalBarSize.topMargin,
        "bottomMargin": modeManager.normalBarSize.bottomMargin
    })
    
    property var history: clipboardManager ? clipboardManager.history : []
    property int currentIndex: -1

    // cliphist wipe cannot be undone, so the button arms first (same shape as ResetSection).
    property bool clearArmed: false
    readonly property color danger: theme ? theme.danger : Qt.rgba(0.95, 0.55, 0.65, 1.0)

    Timer {
        id: disarmTimer
        interval: 5000
        onTriggered: root.clearArmed = false
    }

    // A JS-array model resets the whole view on reload, so park hover and scroll until it lands.
    property bool suppressHover: false
    property real pendingContentY: -1
    onHistoryChanged: {
        suppressHover = false
        if (pendingContentY < 0) return
        const y = pendingContentY
        pendingContentY = -1
        Qt.callLater(() => {
            clipboardList.contentY = Math.min(y,
                Math.max(0, clipboardList.contentHeight - clipboardList.height))
        })
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("clipboard")) {
                clipboardManager.loadHistory()
                currentIndex = -1
                focusTimer.restart()
            } else {
                currentIndex = -1
                root.clearArmed = false
                searchField.text = ""
            }
        }
    }


    Timer {
        id: focusTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (searchField.searchFieldItem) {
                searchField.searchFieldItem.forceActiveFocus()
            }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        z: 1.5
        enabled: modeManager.isMode("clipboard")
        visible: enabled
        hoverEnabled: true
        
        onClicked: {
            modeManager.closeAllModes()
        }
        
        onPositionChanged: {
            if (modeManager.isMode("clipboard")) {
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
        enabled: modeManager.isMode("clipboard")
        visible: enabled
        hoverEnabled: true
        onClicked: modeManager.bump()
        onPositionChanged: modeManager.bump()
    }

    Item {
        id: clipboardLayer
        anchors.fill: parent
        anchors.leftMargin: modeManager.scale(32)
        anchors.rightMargin: modeManager.scale(32)
        z: 2
        
        focus: modeManager.isMode("clipboard")
        
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (currentIndex >= 0 && currentIndex < history.length) {
                    let item = history[currentIndex]
                    clipboardManager.selectItem(item.id)
                    modeManager.closeAllModes()
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                if (currentIndex < 0 && history.length > 0) {
                    currentIndex = 0
                } else if (currentIndex < history.length - 1) {
                    currentIndex++
                } else {
                    currentIndex = 0
                }
                clipboardList.positionViewAtIndex(currentIndex, ListView.Contain)
                event.accepted = true
                modeManager.bump()
            } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_Backtab && event.modifiers & Qt.ShiftModifier)) {
                if (currentIndex < 0 && history.length > 0) {
                    currentIndex = history.length - 1
                } else if (currentIndex > 0) {
                    currentIndex--
                } else {
                    currentIndex = history.length - 1
                }
                clipboardList.positionViewAtIndex(currentIndex, ListView.Contain)
                event.accepted = true
                modeManager.bump()
            } else if (event.key === Qt.Key_Home) {
                if (history.length > 0) {
                    currentIndex = 0
                    clipboardList.positionViewAtIndex(0, ListView.Contain)
                }
                event.accepted = true
                modeManager.bump()
            } else if (event.key === Qt.Key_End) {
                if (history.length > 0) {
                    currentIndex = history.length - 1
                    clipboardList.positionViewAtIndex(currentIndex, ListView.Contain)
                }
                event.accepted = true
                modeManager.bump()
            }
        }
        
        opacity: 0
        visible: opacity > 0.01
        
        states: [
            State {
                name: "visible"
                when: modeManager.isMode("clipboard")
                PropertyChanges { target: clipboardLayer; opacity: 1.0 }
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
        
        ColumnLayout {
            anchors.centerIn: parent
            spacing: root.modeManager.scale(10)

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: root.modeManager.scale(420)
                spacing: root.modeManager.scale(10)

                Common.GlowText {
                    text: "Clipboard"
                    font.pixelSize: root.modeManager.scale(20)
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    font.letterSpacing: 1.5
                    color: (theme ? theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))
                
                    enableGlow: true
                    glowColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6)
                    glowSamples: 20
                    glowRadius: 12
                    glowSpread: 0.5
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: clearAllButton
                    Layout.preferredWidth: clearAllButton.animatedWidth
                    Layout.fillWidth: false
                    height: 28
                    radius: clearAllButton.height / 2

                    property real baseWidth: clearText.implicitWidth + 24
                    property real animatedWidth: root.history.length > 0 ? baseWidth : 0
                    opacity: root.history.length > 0 ? 1.0 : 0.0
                    visible: opacity > 0.01
                    clip: true

                    color: Qt.rgba(root.danger.r, root.danger.g, root.danger.b,
                                   root.clearArmed ? (clearArea.containsMouse ? 0.55 : 0.45)
                                                   : (clearArea.containsMouse ? 0.30 : 0.20))

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
                    }

                    Behavior on animatedWidth {
                        NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
                    }

                    Behavior on color {
                        ColorAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
                    }

                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: root.clearArmed ? "Click again to clear all" : "Clear All"
                        color: Qt.rgba(root.danger.r, root.danger.g, root.danger.b,
                                       clearArea.containsMouse ? 1.0 : 0.85)
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.family: "M PLUS 2"

                        Behavior on color {
                            ColorAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.modeManager.bump()
                            if (!root.clearArmed) {
                                root.clearArmed = true
                                disarmTimer.restart()
                                return
                            }
                            root.clearArmed = false
                            disarmTimer.stop()
                            root.clipboardManager.clearHistory()
                        }
                    }
                }
            }

            UI.SearchField {
                id: searchField
                Layout.preferredWidth: root.modeManager.scale(420)
                Layout.alignment: Qt.AlignHCenter
                theme: root.theme
                icons: root.icons
                placeholder: "Search clipboard..."
                resultCount: root.history.length
                modeManager: root.modeManager

                onSearchTextChanged: (text) => {
                    root.clipboardManager.searchQuery = text
                    root.currentIndex = -1
                    root.modeManager.bump()
                }

                onRequestFocusResults: (backwards) => {
                    if (root.history.length === 0) return
                    clipboardLayer.forceActiveFocus()
                    root.currentIndex = backwards ? root.history.length - 1 : 0
                    clipboardList.positionViewAtIndex(root.currentIndex, ListView.Contain)
                }

                onRequestActivateSelected: () => {
                    const i = root.currentIndex >= 0 ? root.currentIndex : 0
                    root.clipboardManager.selectItem(root.history[i].id)
                    root.modeManager.closeAllModes()
                }
            }

            Item {
                Layout.preferredWidth: modeManager.scale(420)
                Layout.preferredHeight: modeManager.scale(320)
                clip: true
                
                Text {
                    anchors.centerIn: parent
                    text: history.length === 0 ? (clipboardManager.isLoading ? "Loading..." : "No clipboard items") : ""
                    color: (theme ? theme.textFaint : Qt.rgba(0.72, 0.72, 0.82, 0.50))
                    font.pixelSize: 16
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    visible: history.length === 0
                }
                
                ListView {
                    id: clipboardList
                    anchors.fill: parent
                    spacing: 0
                    clip: true
                    model: history
                    
                    onCurrentIndexChanged: {
                        if (root.currentIndex !== currentIndex && currentIndex >= 0) {
                            root.currentIndex = currentIndex
                        }
                    }
                    
                    Connections {
                        target: root
                        function onCurrentIndexChanged() {
                            if (clipboardList.currentIndex !== root.currentIndex && root.currentIndex >= 0) {
                                clipboardList.currentIndex = root.currentIndex
                            }
                        }
                    }
                    
                    add: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0.0
                            to: 1.0
                            duration: Theme.Motion.gentle
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 0.9
                            to: 1.0
                            duration: Theme.Motion.gentle
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    displaced: Transition {
                        NumberAnimation {
                            property: "y"
                            duration: Theme.Motion.standard
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    delegate: Item {
                        id: delegateRoot

                        required property var modelData
                        required property int index

                        width: clipboardList.width
                        // Card plus the old view spacing, so the collapse closes the whole gap in one motion.
                        height: 68

                        // Written, not bound: the view's add transition animates opacity and would sever a binding for good.
                        onXChanged: opacity = 1 - delegateRoot.swipeProgress * 0.85

                        readonly property real swipeThreshold: delegateRoot.width * 0.25
                        readonly property real swipeProgress: delegateRoot.width > 0
                            ? Math.min(1, Math.abs(delegateRoot.x) / delegateRoot.width)
                            : 0

                        NumberAnimation {
                            id: swipeCollapse
                            target: delegateRoot
                            property: "height"
                            to: 0
                            duration: Theme.Motion.standard
                            easing.type: Easing.InOutCubic
                            // Only once the gap has closed: replacing the model resets the whole view.
                            onStopped: {
                                root.pendingContentY = clipboardList.contentY
                                root.clipboardManager.loadHistory()
                            }
                        }

                        NumberAnimation {
                            id: swipeSpringBack
                            target: delegateRoot
                            property: "x"
                            to: 0
                            duration: Theme.Motion.standard
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            id: swipeFlyOut
                            target: delegateRoot
                            property: "x"
                            duration: Theme.Motion.fast
                            easing.type: Easing.OutCubic
                            onStopped: {
                                // The view snaps a delegate's x back to 0 on relayout, so hide before the collapse triggers one.
                                delegateRoot.visible = false
                                root.suppressHover = true
                                root.clipboardManager.deleteItem(delegateRoot.modelData.id)
                                swipeCollapse.start()
                            }
                        }

                        readonly property string thumbnail: delegateRoot.modelData && delegateRoot.modelData.isImage
                            ? root.clipboardManager.thumbnailFor(delegateRoot.modelData.id)
                            : ""

                        readonly property bool isCurrent: root.currentIndex === index
                        readonly property bool isActive: isCurrent
                            || (itemMouseArea.containsMouse && !root.suppressHover)
                        
                        Rectangle {
                            id: card
                            width: parent.width
                            height: 60

                            color: delegateRoot.isActive
                                ? (theme ? theme.surfaceInsetCardHover : Qt.rgba(0, 0, 0, 0.75))
                                : (theme ? theme.surfaceInsetCard : Qt.rgba(0, 0, 0, 0.65))
                            radius: delegateRoot.isActive ? 20 : card.height / 2
                            border.width: 0
                        
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.Motion.fast
                                    easing.type: Easing.OutCubic
                                }
                            }
                        
                            Behavior on radius {
                                NumberAnimation {
                                    duration: Theme.Motion.fast
                                    easing.type: Easing.OutCubic
                                }
                            }
                        
                            layer.enabled: true
                            layer.effect: Glow {
                                samples: 12
                                radius: 6
                                spread: 0.3
                                color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.15) : Qt.rgba(0.65, 0.55, 0.85, 0.15)
                                transparentBorder: true
                            }
                        
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: modeManager.scale(20)
                                anchors.rightMargin: modeManager.scale(20)
                                spacing: 12
                            
                                Item {
                                    Layout.preferredWidth: modeManager.scale(44)
                                    Layout.preferredHeight: modeManager.scale(34)
                                    visible: delegateRoot.thumbnail !== ""

                                    Image {
                                        id: thumbImage
                                        anchors.fill: parent
                                        source: delegateRoot.thumbnail
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: modeManager.scale(88)
                                        asynchronous: true
                                        smooth: true
                                        visible: false
                                    }

                                    OpacityMask {
                                        anchors.fill: thumbImage
                                        source: thumbImage
                                        visible: thumbImage.status === Image.Ready
                                        maskSource: Rectangle {
                                            width: thumbImage.width
                                            height: thumbImage.height
                                            radius: modeManager.scale(8)
                                        }
                                    }
                                }

                                UI.SvgIcon {
                                    width: 20
                                    height: 20
                                    source: icons ? icons.iconData.clipboard.value : ""
                                    color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                                    opacity: 0.8
                                    visible: delegateRoot.thumbnail === "" && icons && icons.iconData.clipboard.type === "svg"
                                }
                            
                                Text {
                                    text: "📋"
                                    font.pixelSize: 20
                                    opacity: 0.8
                                    visible: delegateRoot.thumbnail === "" && (!icons || icons.iconData.clipboard.type !== "svg")
                                }
                            
                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.PlainText
                                    text: delegateRoot.modelData ? delegateRoot.modelData.preview : ""
                                    color: (theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))
                                    font.pixelSize: 14
                                    font.family: "M PLUS 2"
                                    elide: Text.ElideRight
                                }
                            }
                        
                            MouseArea {
                                id: itemMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                drag.target: delegateRoot
                                drag.axis: Drag.XAxis
                                drag.minimumX: -delegateRoot.width
                                drag.maximumX: delegateRoot.width

                                property bool swiped: false

                                onPressed: {
                                    swiped = false
                                    swipeSpringBack.stop()
                                }

                                onReleased: {
                                    if (!swiped) return
                                    if (Math.abs(delegateRoot.x) < delegateRoot.swipeThreshold) {
                                        swipeSpringBack.start()
                                    } else {
                                        swipeFlyOut.to = delegateRoot.x < 0 ? -delegateRoot.width
                                                                           : delegateRoot.width
                                        swipeFlyOut.start()
                                    }
                                }

                                onClicked: {
                                    if (swiped) return
                                    if (delegateRoot.modelData) {
                                        root.clipboardManager.selectItem(delegateRoot.modelData.id)
                                        modeManager.closeAllModes()
                                    }
                                }

                                onPositionChanged: {
                                    if (drag.active) {
                                        swiped = true
                                        return
                                    }
                                    if (root.suppressHover) return
                                    root.currentIndex = index
                                    modeManager.bump()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("clipboard", root)
            if (modeManager.isMode("clipboard")) {
                clipboardManager.loadHistory()
                currentIndex = -1
                modeManager.bump()
                focusTimer.restart()
            }
        }
    }
}

