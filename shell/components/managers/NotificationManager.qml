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
    signal notificationUpdated(var notification)

    readonly property string soundsDir: Theme.Paths.soundsDir
    readonly property string stateFile: Theme.Paths.stateDir + "/notifications.json"

    property int keySeq: 0
    property var pendingRefresh: ({})
    property bool stateRead: false
    property bool saveQueued: false

    function newKey() {
        return Date.now().toString(36) + "-" + (++keySeq)
    }

    function fieldsFrom(n) {
        return {
            title: n.summary || n.appName || "Notification",
            message: n.body || n.summary || "",
            desktopEntry: n.desktopEntry || "",
            appIcon: n.appIcon || "",
            appName: n.appName || "",
            image: n.image || "",
            actions: n.actions || [],
            resident: n.resident === true
        }
    }

    function addNotification(n) {
        let newNotif = Object.assign({
            id: n.id || Date.now(),
            // Stable across hot reloads (live notifications are re-emitted) but unique per launch (server ids restart).
            key: Quickshell.instanceId + "-" + n.id,
            time: "just now",
            timestamp: Date.now(),
            // Live objects: an action cannot outlive its sending process, so neither is persisted.
            source: n
        }, fieldsFrom(n))

        let newNotifications = [newNotif]
        for (let i = 0; i < root.notifications.length && i < 49; i++) {
            newNotifications.push(root.notifications[i])
        }
        for (let i = 49; i < root.notifications.length; i++) {
            release(root.notifications[i])
        }
        const key = newNotif.key
        n.closed.connect(() => root.forgetSource(key))
        const refresh = () => root.scheduleRefresh(key)
        for (const changed of [n.summaryChanged, n.bodyChanged, n.appNameChanged, n.appIconChanged,
                               n.imageChanged, n.desktopEntryChanged, n.residentChanged]) {
            changed.connect(refresh)
        }
        // Quickshell frees the replaced actions right after this signal returns, so refresh before it does.
        n.actionsChanged.connect(() => {
            root.pendingRefresh[key] = true
            root.flushRefresh()
        })

        root.notifications = newNotifications
        root.unreadCount++
        // A reload re-emits every live notification; only a new arrival should pop up and chime.
        if (!n.lastGeneration) {
            root.notificationReceived(newNotif)
            playSound()
        }
        save()
    }

    function scheduleRefresh(key) {
        pendingRefresh[key] = true
        Qt.callLater(root.flushRefresh)
    }

    function flushRefresh() {
        const keys = pendingRefresh
        pendingRefresh = ({})
        let next = null
        const updated = []
        for (let i = 0; i < notifications.length; i++) {
            const entry = notifications[i]
            if (!keys[entry.key] || !entry.source) continue
            if (!next) next = notifications.slice(0)
            next[i] = Object.assign({}, entry, fieldsFrom(entry.source))
            updated.push(next[i])
        }
        if (!next) return
        notifications = next
        for (const entry of updated) root.notificationUpdated(entry)
        saveDebounce.restart()
    }

    // Once closed, the object is gone but the reference stays truthy, so drop it here.
    function forgetSource(key) {
        let next = notifications.slice(0)
        for (let i = 0; i < next.length; i++) {
            if (next[i].key === key) {
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

    function invokeAction(key, action) {
        // An action dropped by a replacement lingers as an object with no invoke().
        if (!action || typeof action.invoke !== "function") return false
        action.invoke()
        let notif = notifications.find(n => n.key === key)
        // A resident notification is meant to outlive its own action.
        return !notif || !notif.resident
    }

    function defaultAction(notif) {
        let actions = notif && notif.actions ? notif.actions : []
        for (let i = 0; i < actions.length; i++) {
            if (actions[i] && typeof actions[i].identifier === "string" && actions[i].identifier === "default") return actions[i]
        }
        return null
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
    
    function removeNotification(key) {
        let i = notifications.findIndex(n => n.key === key)
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
        // A reload re-emits live notifications before the history is read, and saving then would overwrite it.
        if (!stateRead) {
            saveQueued = true
            return
        }
        saveQueued = false
        let payload = notifications.map(n => ({
            id: n.id,
            key: n.key,
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
            for (let i = 0; i < notifications.length; i++) known[notifications[i].key] = true
            let merged = notifications.slice(0)
            for (let i = 0; i < restored.length; i++) {
                if (restored[i].key && known[restored[i].key]) continue
                let key = restored[i].key || newKey()
                known[key] = true
                merged.push(Object.assign({}, restored[i], { key: key, time: "", actions: [] }))
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

    property Timer saveDebounce: Timer {
        interval: 1000
        onTriggered: root.save()
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
            root.stateRead = true
            if (root.saveQueued) root.save()
        }
    }

    Component.onCompleted: {
        readProcess.command = ["cat", stateFile]
        readProcess.running = true
    }
}
