import QtQuick
import Quickshell
import Quickshell.Io
import "../../lib" as Theme

QtObject {
    id: root

    property var notifications: []
    property int unreadCount: 0
    property bool notificationsEnabled: settingsManager ? settingsManager.notificationsEnabled : true
    property var settingsManager
    signal notificationReceived(var notification)

    readonly property string soundsDir: Theme.Paths.soundsDir
    readonly property string stateFile: Theme.Paths.stateDir + "/notifications.json"

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
            desktopEntry: n.desktopEntry || "",
            appIcon: n.appIcon || "",
            appName: n.appName || "",
            image: n.image || "",
            // Live objects: an action cannot outlive its sending process, so neither is persisted.
            source: n,
            actions: n.actions || [],
            resident: n.resident === true
        }

        let newNotifications = [newNotif]
        for (let i = 0; i < root.notifications.length && i < 49; i++) {
            newNotifications.push(root.notifications[i])
        }
        for (let i = 49; i < root.notifications.length; i++) {
            release(root.notifications[i])
        }
        n.closed.connect(() => root.forgetSource(newNotif.id))

        root.notifications = newNotifications
        root.unreadCount++
        root.notificationReceived(newNotif)
        playSound()
        save()
    }

    // Once closed, the object is gone but the reference stays truthy, so drop it here.
    function forgetSource(notifId) {
        let next = notifications.slice(0)
        for (let i = 0; i < next.length; i++) {
            if (next[i].id === notifId) {
                next[i] = Object.assign({}, next[i], { source: null, actions: [] })
                notifications = next
                return
            }
        }
    }

    // Untracking hands the notification back to the server.
    function release(notif) {
        if (!notif || !notif.source) return
        try {
            notif.source.tracked = false
        } catch (e) {
            console.warn("notification already gone:", e)
        }
        notif.source = null
    }

    function invokeAction(notifId, action) {
        if (!action) return false
        action.invoke()
        let notif = notifications.find(n => n.id === notifId)
        // A resident notification is meant to outlive its own action.
        return !notif || !notif.resident
    }

    property real soundThrottleMs: 1000
    property real lastSoundAt: 0

    function playSound() {
        if (!notificationsEnabled) return
        if (!settingsManager) return
        let sound = settingsManager.notificationSound
        if (!sound || sound === "None") return
        let now = Date.now()
        if (now - lastSoundAt < soundThrottleMs) return
        lastSoundAt = now
        soundPlayProcess.command = ["paplay", soundsDir + "/" + sound]
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
    
    // Server ids restart near 1 each session, so a restored entry can share one with a live notification.
    function removeNotification(notifId) {
        let i = notifications.findIndex(n => n.id === notifId)
        if (i < 0) return
        release(notifications[i])
        let next = notifications.slice(0)
        next.splice(i, 1)
        notifications = next
        if (unreadCount > 0) unreadCount--
        save()
    }
    
    function clearAll() {
        clearArrivedBefore(Date.now())
    }

    // The panel animates the sweep for ~500ms, and anything arriving in that window must survive it.
    function clearArrivedBefore(cutoff) {
        let kept = []
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i].timestamp > cutoff) {
                kept.push(notifications[i])
                continue
            }
            release(notifications[i])
        }
        notifications = kept
        unreadCount = kept.length
        save()
    }
    
    function markAllAsRead() {
        unreadCount = 0
    }
    
    function save() {
        let payload = notifications.map(n => ({
            id: n.id,
            title: n.title,
            message: n.message,
            timestamp: n.timestamp,
            desktopEntry: n.desktopEntry,
            appIcon: n.appIcon,
            appName: n.appName,
            image: n.image
        }))
        saveProcess.command = Theme.JsonStore.atomicWriteArgv(
            Theme.Paths.stateDir, stateFile, JSON.stringify(payload))
        saveProcess.running = true
    }

    function applyFromJson(jsonString) {
        try {
            let restored = JSON.parse(jsonString)
            if (!Array.isArray(restored) || restored.length === 0) return
            // The read is async, so a notification arriving first must not be replaced by it.
            let known = {}
            for (let i = 0; i < notifications.length; i++) known[String(notifications[i].id)] = true
            let merged = notifications.slice(0)
            for (let i = 0; i < restored.length; i++) {
                if (known[String(restored[i].id)]) continue
                merged.push(Object.assign({}, restored[i], { time: "", actions: [] }))
            }
            notifications = merged
            updateTimeLabels()
        } catch (e) {
            console.error("Failed to parse notification state:", e)
        }
    }

    property Process saveProcess: Process {
        command: []
        running: false
    }

    property Process readProcess: Process {
        id: stateReader

        command: []
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => { stateReader.output += data }
        }

        // A missing state file just yields no output, so the exit code adds nothing.
        onRunningChanged: {
            if (stateReader.running) return
            if (stateReader.output.trim().length > 0) {
                root.applyFromJson(stateReader.output)
            }
            stateReader.output = ""
        }
    }

    Component.onCompleted: {
        readProcess.command = ["cat", stateFile]
        readProcess.running = true
    }
}
