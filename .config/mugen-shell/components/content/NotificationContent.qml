import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../notification" as NotificationComponents
import "../ui" as UI
import "../common" as Common

Item {
    id: root
    
    required property var modeManager
    required property var notificationManager
    property var theme
    property var icons
    
    readonly property var requiredBarSize: ({
        "height": modeManager.scale(420),
        "leftMargin": modeManager.scale(700),
        "rightMargin": modeManager.scale(700),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })
    
    property var notifications: notificationManager.notifications
    property var removingNotifications: ({})
    
    onNotificationsChanged: {
        if (!isClearingAll) {
            syncNotificationsToModel()
        }
    }
    
    function syncNotificationsToModel() {
        if (notifications.length > notificationListModel.count) {
            let newCount = notifications.length - notificationListModel.count
            for (let i = newCount - 1; i >= 0; i--) {
                notificationListModel.insert(0, {
                    "modelData": notifications[i]
                })
            }
        }
        else if (notifications.length < notificationListModel.count) {
            for (let i = notificationListModel.count - 1; i >= 0; i--) {
                let modelId = notificationListModel.get(i).modelData.id
                let found = false
                for (let j = 0; j < notifications.length; j++) {
                    if (notifications[j].id === modelId) {
                        found = true
                        break
                    }
                }
                if (!found) {
                    notificationListModel.remove(i)
                }
            }
        }
        else if (notifications.length > 0) {
            let needsSync = false
            for (let i = 0; i < notifications.length && i < notificationListModel.count; i++) {
                if (notifications[i].id !== notificationListModel.get(i).modelData.id) {
                    needsSync = true
                    break
                }
            }
            if (needsSync) {
                notificationListModel.clear()
                for (let i = 0; i < notifications.length; i++) {
                    notificationListModel.append({
                        "modelData": notifications[i]
                    })
                }
            }
        }
    }
    
    function removeNotification(notificationId) {
        let notifIdStr = String(notificationId)
        
        if (removingNotifications[notifIdStr] !== undefined) {
            return
        }
        
        let newRemoving = Object.assign({}, removingNotifications)
        newRemoving[notifIdStr] = Date.now()
        removingNotifications = newRemoving
        
        removeTimer.notificationId = notifIdStr
        removeTimer.restart()
    }
    
    Timer {
        id: removeTimer
        property string notificationId: ""
        interval: 500
        onTriggered: {
            if (!notificationId) return
            
            let notifId = isNaN(notificationId) ? notificationId : Number(notificationId)
            notificationManager.removeNotification(notifId)
            
            removeFlagTimer.notificationId = notificationId
            removeFlagTimer.restart()
            
            notificationId = ""
        }
    }
    
    Timer {
        id: removeFlagTimer
        property string notificationId: ""
        interval: 450
        onTriggered: {
            if (!notificationId) return
            
            let stillExists = false
            for (let i = 0; i < notifications.length; i++) {
                if (String(notifications[i].id) === notificationId) {
                    stillExists = true
                    break
                }
            }
            
            if (!stillExists) {
                Qt.callLater(() => {
                    let updatedRemoving = Object.assign({}, removingNotifications)
                    delete updatedRemoving[notificationId]
                    removingNotifications = updatedRemoving
                })
            }
            
            notificationId = ""
        }
    }
    
    Process {
        id: launchAppProcess
        running: false
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
            }
        }
    }
    

    
    Timer {
        id: autoCloseTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            if (modeManager.isMode("notification")) {
                modeManager.closeAllModes()
            }
        }
    }
    
    function resetAutoCloseTimer() {
        if (modeManager.isMode("notification")) {
            autoCloseTimer.restart()
        }
    }
    
    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("notification")) {
                autoCloseTimer.restart()
            } else {
                autoCloseTimer.stop()
            }
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
            if (modeManager.isMode("notification")) {
                autoCloseTimer.restart()
            }
        }
    }
    
    Item {
        id: notificationLayer
        anchors.fill: parent
        anchors.leftMargin: modeManager.scale(32)
        anchors.rightMargin: modeManager.scale(32)
        z: 2
        
        focus: modeManager.isMode("notification")
        Keys.onPressed: (event) => {
            if (modeManager.isMode("notification")) {
                autoCloseTimer.restart()
            }
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
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
                    color: Qt.rgba(0.95, 0.93, 0.98, 0.95)
                    
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
                            duration: 300
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
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        Behavior on scale {
                            NumberAnimation {
                                duration: 300
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
                            notificationManager.notificationsEnabled = !notificationManager.notificationsEnabled
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
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    Behavior on animatedWidth {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: 300
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
                                duration: 300
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
                    color: Qt.rgba(0.72, 0.72, 0.82, 0.50)
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

                    property bool hasMoreBelow: !atYEnd && contentHeight > height

                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation {
                                properties: "y"
                                from: -60
                                duration: 400
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                properties: "opacity"
                                from: 0.0
                                duration: 400
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                properties: "scale"
                                from: 0.95
                                duration: 400
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
                            duration: 400
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    delegate: NotificationComponents.NotificationItem {
                        modelData: model.modelData
                        theme: root.theme
                        removingNotifications: root.removingNotifications
                        notifications: root.notifications
                        index: model.index
                        
                        onRemoveRequested: (notificationId) => {
                            root.removeNotification(notificationId)
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
                            duration: 300
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
                            color: Qt.rgba(0, 0, 0, 0.7)
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
                                duration: 800
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
                                    duration: 800
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
        }
    }
}

