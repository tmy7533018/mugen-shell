import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var notifications: []
    property int unreadCount: 0
    property bool notificationsEnabled: true
    property var settingsManager
    signal notificationReceived(var notification)

    function addNotification(n) {
        if (!n.summary && !n.body) {
            return
        }

        let newNotif = {
            id: n.id || Date.now(),
            title: n.summary || n.appName || "Notification",
            message: n.body || n.summary || "",
            time: "just now",
            timestamp: Date.now(),
            desktopEntry: n.desktopEntry || ""
        }

        let newNotifications = [newNotif]
        for (let i = 0; i < root.notifications.length && i < 49; i++) {
            newNotifications.push(root.notifications[i])
        }
        root.notifications = newNotifications
        root.unreadCount++
        root.notificationReceived(newNotif)
        playSound()
    }

    function playSound() {
        if (!notificationsEnabled) return
        if (!settingsManager) return
        let sound = settingsManager.notificationSound
        if (!sound || sound === "None") return
        soundPlayProcess.command = ["paplay", Quickshell.shellDir + "/assets/sounds/" + sound]
        soundPlayProcess.running = true
    }

    property Process soundPlayProcess: Process {
        command: []
        running: false
    }
    
    property Timer timeUpdateTimer: Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: updateTimeLabels()
    }
    
    function updateTimeLabels() {
        let now = Date.now()
        let updated = false
        
        for (let i = 0; i < notifications.length; i++) {
            let notif = notifications[i]
            let diff = Math.floor((now - notif.timestamp) / 1000)
            
            let newTime = ""
            if (diff < 60) {
                newTime = "just now"
            } else if (diff < 3600) {
                let mins = Math.floor(diff / 60)
                newTime = mins + (mins === 1 ? " min ago" : " mins ago")
            } else if (diff < 86400) {
                let hrs = Math.floor(diff / 3600)
                newTime = hrs + (hrs === 1 ? " hr ago" : " hrs ago")
            } else {
                let days = Math.floor(diff / 86400)
                newTime = days + (days === 1 ? " day ago" : " days ago")
            }
            
            if (notif.time !== newTime) {
                notif.time = newTime
                updated = true
            }
        }
        
        if (updated) {
            notifications = notifications.slice(0)
        }
    }
    
    function removeNotification(notifId) {
        notifications = notifications.filter(n => n.id !== notifId)
        if (unreadCount > 0) unreadCount--
    }
    
    function clearAll() {
        notifications = []
        unreadCount = 0
    }
    
    function markAllAsRead() {
        unreadCount = 0
    }
    
    Component.onCompleted: {
    }
}
