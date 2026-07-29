import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../notification" as NotificationComponents
import "../ui" as UI
import "../common" as Common
import "../../lib" as Theme

Item {
    id: root
    
    required property var modeManager
    required property var notificationManager
    property var settingsManager
    property var theme
    property var icons
    
    readonly property var requiredBarSize: ({
        "height": modeManager.scale(420),
        "leftMargin": modeManager.scale(700),
        "rightMargin": modeManager.scale(700),
        "topMargin": modeManager.normalBarSize.topMargin,
        "bottomMargin": modeManager.normalBarSize.bottomMargin
    })
    
    property var notifications: notificationManager.notifications
    property var removingNotifications: ({})

    // Keys are prefixed so they can never collide with a notification id, which
    // the removal paths round-trip through Number().
    property var expandedGroups: ({})

    function groupKeyOf(n) {
        if (n.desktopEntry && String(n.desktopEntry).length > 0) return "d:" + String(n.desktopEntry).toLowerCase()
        if (n.appName && String(n.appName).length > 0) return "a:" + String(n.appName).toLowerCase()
        // No app identity: stay a singleton rather than merge with strangers.
        return "n:" + n.id
    }

    // A card that sometimes means one notification and sometimes five cannot
    // signal which, so a group is a header row plus plain notification rows.
    // The header's synthetic id keeps syncNotificationsToModel, which matches
    // rows by id, free of any notion of row kinds.
    readonly property string groupRowPrefix: "grp:"

    // Members are indented under their header; that step is what makes the
    // group read as one thing rather than a stray label between cards.
    function withGroup(n) {
        let copy = Object.assign({}, n)
        copy.inGroup = true
        return copy
    }

    readonly property var displayRows: {
        let src = notifications
        let counts = ({})
        let members = ({})
        for (let i = 0; i < src.length; i++) {
            let k = groupKeyOf(src[i])
            counts[k] = (counts[k] || 0) + 1
            if (!members[k]) members[k] = []
            members[k].push(src[i].id)
        }

        let rows = []
        let seen = ({})
        for (let i = 0; i < src.length; i++) {
            let n = src[i]
            let k = groupKeyOf(n)
            if (!seen[k]) {
                seen[k] = true
                if (counts[k] > 1) {
                    rows.push({
                        "id": groupRowPrefix + k,
                        "isGroupHeader": true,
                        "groupKey": k,
                        "groupCount": counts[k],
                        "groupMemberIds": members[k],
                        "groupExpanded": expandedGroups[k] === true,
                        "appName": n.appName,
                        "desktopEntry": n.desktopEntry,
                        "image": n.image
                    })
                }
                // The newest member always shows as an ordinary card, so a
                // collapsed group still offers one notification to act on.
                rows.push(counts[k] > 1 ? withGroup(n) : n)
            } else if (expandedGroups[k] === true) {
                rows.push(withGroup(n))
            }
        }
        return rows
    }

    function isGroupRow(id) {
        return String(id).indexOf(groupRowPrefix) === 0
    }

    onDisplayRowsChanged: {
        if (!isClearingAll) {
            syncNotificationsToModel()
        }
    }

    function toggleGroup(key) {
        let next = Object.assign({}, expandedGroups)
        if (next[key] === true) delete next[key]
        else next[key] = true
        expandedGroups = next
        resetAutoCloseTimer()
    }

    function syncNotificationsToModel() {
        let rows = displayRows

        // Row count and notification count are decoupled once grouping is on
        // (a second notification for an existing app adds no row, expanding one
        // inserts several), so this diffs by id instead of by length.
        let want = ({})
        for (let i = 0; i < rows.length; i++) {
            let k = String(rows[i].id)
            want[k] = (want[k] || 0) + 1
        }

        // Counted rather than set-based: the manager does not dedupe ids, and a
        // notification server reusing one must not make two rows match at random.
        let keep = []
        for (let i = 0; i < notificationListModel.count; i++) {
            let k = String(notificationListModel.get(i).modelData.id)
            if (want[k] > 0) {
                want[k]--
                keep.push(true)
            } else {
                keep.push(false)
            }
        }
        for (let i = keep.length - 1; i >= 0; i--) {
            if (!keep[i]) notificationListModel.remove(i)
        }

        for (let i = 0; i < rows.length; i++) {
            let id = String(rows[i].id)
            if (i < notificationListModel.count && String(notificationListModel.get(i).modelData.id) === id) {
                // Re-push even when unchanged: the relative "x mins ago" label
                // mutates on each tick and delegates freeze without it.
                notificationListModel.set(i, { "modelData": rows[i] })
                continue
            }
            let at = -1
            for (let j = i + 1; j < notificationListModel.count; j++) {
                if (String(notificationListModel.get(j).modelData.id) === id) {
                    at = j
                    break
                }
            }
            if (at >= 0) {
                notificationListModel.move(at, i, 1)
                notificationListModel.set(i, { "modelData": rows[i] })
            } else {
                notificationListModel.insert(i, { "modelData": rows[i] })
            }
        }
        while (notificationListModel.count > rows.length) {
            notificationListModel.remove(notificationListModel.count - 1)
        }
    }
    
    function removeNotification(notificationId) {
        removeNotificationIds([notificationId])
    }

    function removeNotificationIds(ids) {
        let pending = []
        let newRemoving = Object.assign({}, removingNotifications)
        for (let i = 0; i < ids.length; i++) {
            let s = String(ids[i])
            if (newRemoving[s] !== undefined) continue
            newRemoving[s] = Date.now()
            pending.push(s)
        }
        if (pending.length === 0) return
        removingNotifications = newRemoving

        // Queued, not overwritten: a second dismissal inside the 500ms window
        // used to drop the first id, leaving its row flagged forever at height 0.
        removeTimer.notificationIds = removeTimer.notificationIds.concat(pending)
        if (!removeTimer.running) removeTimer.restart()
    }

    Timer {
        id: removeTimer
        property var notificationIds: []
        interval: 500
        onTriggered: {
            let ids = notificationIds
            notificationIds = []
            if (ids.length === 0) return

            for (let i = 0; i < ids.length; i++) {
                // Header rows fade with their group but have nothing behind
                // them for the manager to drop.
                if (root.isGroupRow(ids[i])) continue
                notificationManager.removeNotification(isNaN(ids[i]) ? ids[i] : Number(ids[i]))
            }

            removeFlagTimer.notificationIds = removeFlagTimer.notificationIds.concat(ids)
            if (!removeFlagTimer.running) removeFlagTimer.restart()
        }
    }

    Timer {
        id: removeFlagTimer
        property var notificationIds: []
        interval: 450
        onTriggered: {
            let ids = notificationIds
            notificationIds = []
            if (ids.length === 0) return

            let gone = []
            for (let i = 0; i < ids.length; i++) {
                let stillExists = false
                for (let j = 0; j < notifications.length; j++) {
                    if (String(notifications[j].id) === ids[i]) {
                        stillExists = true
                        break
                    }
                }
                if (!stillExists) gone.push(ids[i])
            }
            if (gone.length === 0) return

            Qt.callLater(() => {
                let updatedRemoving = Object.assign({}, removingNotifications)
                for (let i = 0; i < gone.length; i++) delete updatedRemoving[gone[i]]
                removingNotifications = updatedRemoving
            })
        }
    }
    
    Process {
        id: launchAppProcess
        running: false

        // hyprctl exits 0 even when a dispatch is rejected, so without this a
        // broken focus is invisible — how the Lua config migration silently took
        // notification click-to-focus out for two weeks.
        property string errorOutput: ""

        stderr: SplitParser {
            onRead: data => {
                launchAppProcess.errorOutput += data
            }
        }

        onRunningChanged: { if (running) errorOutput = "" }

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("focus_or_launch failed (" + exitCode + "): "
                             + launchAppProcess.errorOutput.trim())
            }
        }
    }
    
    property bool isClearingAll: false
    property int clearAllCurrentIndex: 0
    
    function clearAllNotifications() {
        if (notificationListModel.count === 0) return
        
        isClearingAll = true
        clearAllCurrentIndex = 0
        clearAllSequentialTimer.start()
    }
    
    Timer {
        id: clearAllSequentialTimer
        interval: 80
        repeat: true
        onTriggered: {
            if (clearAllCurrentIndex < notificationListModel.count) {
                let notifId = String(notificationListModel.get(clearAllCurrentIndex).modelData.id)
                let newRemoving = Object.assign({}, removingNotifications)
                newRemoving[notifId] = Date.now()
                removingNotifications = newRemoving
                
                clearAllCurrentIndex++
            } else {
                clearAllSequentialTimer.stop()
                clearAllFinalTimer.start()
            }
        }
    }
    
    // Wait for removal animations to finish before actually deleting
    Timer {
        id: clearAllFinalTimer
        interval: 500
        onTriggered: {
            notificationListModel.clear()
            notificationManager.clearAll()
            removingNotifications = {}
            isClearingAll = false
            clearAllCurrentIndex = 0
        }
    }
    
    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("notification")) {
                notificationManager.markAllAsRead()
                notificationList.currentIndex = -1
                focusTimer.restart()
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: {
            if (notificationLayer && modeManager.isMode("notification")) {
                notificationLayer.forceActiveFocus()
            }
        }
    }
    

    
    function resetAutoCloseTimer() {
        if (modeManager.isMode("notification")) modeManager.bump()
    }

    function toggleNotificationsAndPreview() {
        if (!settingsManager) return
        let wasOff = !settingsManager.notificationsEnabled
        settingsManager.notificationsEnabled = !settingsManager.notificationsEnabled
        settingsManager.saveSettings()
        if (wasOff && settingsManager.notificationsEnabled) {
            notificationManager.playSound()
        }
    }


    MouseArea {
        anchors.fill: parent
        z: 1.5
        enabled: modeManager.isMode("notification")
        visible: enabled
        hoverEnabled: true
        
        onClicked: {
            modeManager.closeAllModes()
        }

        onPositionChanged: {
            if (modeManager.isMode("notification")) modeManager.bump()
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: root.requiredBarSize.topMargin
        anchors.bottomMargin: root.requiredBarSize.bottomMargin
        anchors.leftMargin: root.requiredBarSize.leftMargin
        anchors.rightMargin: root.requiredBarSize.rightMargin
        z: 1.8
        enabled: modeManager.isMode("notification")
        visible: enabled
        hoverEnabled: true
        onClicked: modeManager.bump()
        onPositionChanged: modeManager.bump()
    }

    Item {
        id: notificationLayer
        anchors.fill: parent
        anchors.leftMargin: modeManager.scale(32)
        anchors.rightMargin: modeManager.scale(32)
        z: 2
        
        focus: modeManager.isMode("notification")
        Keys.onPressed: (event) => {
            if (modeManager.isMode("notification")) modeManager.bump()
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_D && !(event.modifiers & Qt.ControlModifier)) {
                root.toggleNotificationsAndPreview()
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_L && (event.modifiers & Qt.ControlModifier)) {
                root.clearAllNotifications()
                event.accepted = true
                return
            }

            let count = notificationListModel.count
            if (count === 0) return

            if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                let next = notificationList.currentIndex + 1
                if (next >= count) next = 0
                notificationList.currentIndex = next
                notificationList.positionViewAtIndex(next, ListView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                let prev = notificationList.currentIndex - 1
                if (prev < 0) prev = count - 1
                notificationList.currentIndex = prev
                notificationList.positionViewAtIndex(prev, ListView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Home) {
                notificationList.currentIndex = 0
                notificationList.positionViewAtIndex(0, ListView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_End) {
                notificationList.currentIndex = count - 1
                notificationList.positionViewAtIndex(count - 1, ListView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                let idx = notificationList.currentIndex
                if (idx >= 0 && idx < root.displayRows.length) {
                    let notif = root.displayRows[idx]
                    if (notif && notif.groupCount > 1) {
                        // Mirrors left-click: reach the members first, then Enter
                        // on the header launches like any other row.
                        root.toggleGroup(notif.groupKey)
                    } else {
                        if (notif && notif.desktopEntry && notif.desktopEntry.length > 0) {
                            launchAppProcess.command = ["python3", Quickshell.shellDir + "/scripts/focus_or_launch.py", notif.desktopEntry]
                            launchAppProcess.running = true
                        }
                        if (notif && notif.id !== undefined) {
                            root.removeNotification(notif.id)
                        }
                    }
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                let idx = notificationList.currentIndex
                if (idx >= 0 && idx < root.displayRows.length) {
                    let notif = root.displayRows[idx]
                    if (notif && notif.groupCount > 1 && notif.groupExpanded !== true) {
                        root.removeNotificationIds(notif.groupMemberIds)
                    } else if (notif && notif.id !== undefined) {
                        root.removeNotification(notif.id)
                    }
                }
                event.accepted = true
            }
        }
        
        opacity: 0
        visible: opacity > 0.01
        
        states: [
            State {
                name: "visible"
                when: modeManager.isMode("notification")
                PropertyChanges { target: notificationLayer; opacity: 1.0 }
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
            spacing: modeManager.scale(10)
            
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: modeManager.scale(420)
                spacing: modeManager.scale(10)
                
                Common.GlowText {
                    text: "Notifications"
                    font.pixelSize: modeManager.scale(20)
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
                    id: toggleButton
                    width: 28
                    height: 28
                    color: notificationManager.notificationsEnabled
                        ? Qt.rgba(0.45, 0.75, 0.55, toggleArea.containsMouse ? 0.4 : 0.3)
                        : Qt.rgba(0.75, 0.45, 0.45, toggleArea.containsMouse ? 0.4 : 0.3)
                    radius: height / 2
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.Motion.standard
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    UI.SvgIcon {
                        id: toggleIcon
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: root.icons 
                            ? (notificationManager.notificationsEnabled
                                ? root.icons.notificationSvg
                                : root.icons.notificationOffSvg)
                            : ""
                        color: notificationManager.notificationsEnabled
                            ? Qt.rgba(0.55, 0.95, 0.65, toggleArea.containsMouse ? 1.0 : 0.9)
                            : Qt.rgba(0.95, 0.55, 0.65, toggleArea.containsMouse ? 1.0 : 0.9)
                        opacity: toggleArea.containsMouse ? 1.0 : 0.9
                        scale: toggleArea.containsMouse ? 1.2 : 1.0
                        
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.Motion.standard
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.Motion.standard
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.Motion.standard
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    
                    MouseArea {
                        id: toggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.toggleNotificationsAndPreview()
                            root.resetAutoCloseTimer()
                        }
                    }
                }
                
                Rectangle {
                    id: clearAllButton
                    property real baseWidth: clearAllText.implicitWidth + 24
                    property real animatedWidth: (notifications.length > 0 && !root.isClearingAll) ? baseWidth : 0
                    Layout.preferredWidth: animatedWidth
                    Layout.fillWidth: false
                    height: 28
                    color: Qt.rgba(0.90, 0.45, 0.55, clearAllArea.containsMouse ? 0.3 : 0.2)
                    radius: height / 2
                    visible: opacity > 0.01

                    opacity: (notifications.length > 0 && !root.isClearingAll) ? 1.0 : 0.0
                    
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.Motion.standard
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    Behavior on animatedWidth {
                        NumberAnimation {
                            duration: Theme.Motion.standard
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.Motion.standard
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    Text {
                        id: clearAllText
                        anchors.centerIn: parent
                        text: "Clear All"
                        color: Qt.rgba(0.95, 0.55, 0.65, clearAllArea.containsMouse ? 1.0 : 0.85)
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.family: "M PLUS 2"
                        
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.Motion.standard
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    
                    MouseArea {
                        id: clearAllArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.isClearingAll
                        onClicked: {
                            root.clearAllNotifications()
                            root.resetAutoCloseTimer()
                        }
                    }
                }
            }
            
            Item {
                Layout.preferredWidth: modeManager.scale(420)
                Layout.preferredHeight: modeManager.scale(280)
                clip: true
                
                Text {
                    anchors.centerIn: parent
                    text: "No notifications"
                    color: (theme ? theme.textFaint : Qt.rgba(0.72, 0.72, 0.82, 0.50))
                    font.pixelSize: 16
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    visible: notificationListModel.count === 0
                }
                
                ListView {
                    id: notificationList
                    anchors.fill: parent
                    spacing: 8
                    clip: true
                    visible: notificationListModel.count > 0

                    model: ListModel {
                        id: notificationListModel
                    }

                    // Disable item reuse so removal animations play correctly
                    reuseItems: false

                    cacheBuffer: 200

                    currentIndex: -1

                    property bool hasMoreBelow: !atYEnd && contentHeight > height

                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation {
                                // Relative to where this row lands, not to the
                                // top of the list: expanding a group inserts
                                // rows mid-list, and an absolute start sent
                                // them flying down from the panel's top edge.
                                properties: "y"
                                from: ViewTransition.destination.y - 30
                                duration: Theme.Motion.gentle
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                properties: "opacity"
                                from: 0.0
                                duration: Theme.Motion.gentle
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                properties: "scale"
                                from: 0.95
                                duration: Theme.Motion.gentle
                                easing.type: Easing.OutBack
                            }
                        }
                    }
                    
                    // Minimal duration so contentHeight recalculates smoothly
                    remove: Transition {
                        NumberAnimation {
                            properties: "opacity"
                            from: 1.0
                            to: 0.0
                            duration: 1
                        }
                    }
                    
                    displaced: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: Theme.Motion.gentle
                            easing.type: Easing.OutCubic
                        }
                    }

                    // displaced only animates the rows pushed aside; without this
                    // a group bumped to the top by a new member would teleport.
                    move: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: Theme.Motion.gentle
                            easing.type: Easing.OutCubic
                        }
                    }

                    delegate: NotificationComponents.NotificationItem {
                        modelData: model.modelData
                        theme: root.theme
                        icons: root.icons
                        removingNotifications: root.removingNotifications
                        notifications: root.notifications
                        index: model.index

                        onRemoveRequested: (notificationId) => {
                            root.removeNotification(notificationId)
                            root.resetAutoCloseTimer()
                        }

                        onGroupToggleRequested: (groupKey) => {
                            root.toggleGroup(groupKey)
                        }

                        onGroupDismissRequested: (memberIds) => {
                            root.removeNotificationIds(memberIds)
                            root.resetAutoCloseTimer()
                        }

                        onActionRequested: (notif) => {
                            if (notif.desktopEntry && notif.desktopEntry.length > 0) {
                                launchAppProcess.command = ["python3", Quickshell.shellDir + "/scripts/focus_or_launch.py", notif.desktopEntry]
                                launchAppProcess.running = true
                            }
                            root.removeNotification(notif.id)
                            root.resetAutoCloseTimer()
                        }
                    }
                }
                
                Item {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: 40
                    visible: notificationList.hasMoreBelow
                    opacity: notificationList.hasMoreBelow ? 1.0 : 0.0
                    
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.Motion.standard
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    Item {
                        id: scrollArrowContainer
                        anchors.centerIn: parent
                        width: 40
                        height: 40
                        
                        property real yOffset: 0
                        y: parent.height / 2 - height / 2 + yOffset
                        
                        Rectangle {
                            anchors.centerIn: parent
                            width: 40
                            height: 40
                            radius: 20
                            color: theme ? theme.surfaceInsetCardHover : Qt.rgba(0, 0, 0, 0.7)
                        }
                        
                        SequentialAnimation on yOffset {
                            loops: Animation.Infinite
                            running: notificationList.hasMoreBelow
                            
                            NumberAnimation {
                                from: 0
                                to: 6
                                duration: 800
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                from: 6
                                to: 0
                                duration: Theme.Motion.drift
                                easing.type: Easing.InOutSine
                            }
                        }
                        
                        Image {
                            id: arrowSvg
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            source: icons ? icons.arrowDownwardSvg : ""
                            visible: false
                        }
                        
                        ColorOverlay {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            source: arrowSvg
                            color: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1.0)
                            opacity: 0.6
                            
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: notificationList.hasMoreBelow
                                
                                NumberAnimation {
                                    from: 0.6
                                    to: 0.9
                                    duration: 800
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    from: 0.9
                                    to: 0.6
                                    duration: Theme.Motion.drift
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    Component.onCompleted: {
        syncNotificationsToModel()
        if (modeManager) {
            modeManager.registerMode("notification", root)
            if (modeManager.isMode("notification")) {
                notificationManager.markAllAsRead()
                focusTimer.restart()
            }
        }
    }
}

