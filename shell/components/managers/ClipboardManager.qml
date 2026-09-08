import QtQuick
import Quickshell
import Quickshell.Io
import "../../lib" as Theme

QtObject {
    id: root
    
    property var history: []
    
    property bool isLoading: false
    property string searchQuery: ""
    readonly property string thumbDir: Theme.Paths.cacheDir + "/clipboard-thumbs"
    property var thumbTokens: ({})

    // cliphist prints an image as a placeholder line; the bytes come from `cliphist decode`.
    readonly property var imageEntry: /^\[\[\s*binary data\s+(.*?)\s*\]\]$/

    function thumbnailFor(id) {
        return thumbTokens[String(id)] === undefined
            ? ""
            : "file://" + thumbDir + "/" + id + ".png"
    }

    function syncThumbnails(ids) {
        if (thumbSyncProcess.running) return
        thumbSyncProcess.command = [
            "bash",
            Quickshell.shellDir + "/scripts/sync-clipboard-thumbs.sh",
            thumbDir
        ].concat(ids)
        thumbSyncProcess.pending = {}
        thumbSyncProcess.running = true
    }

    property Process thumbSyncProcess: Process {
        id: thumbSync

        command: []
        running: false
        property var pending: ({})

        stdout: SplitParser {
            onRead: data => {
                let line = data.trim()
                let sep = line.indexOf('\t')
                if (sep > 0) thumbSync.pending[line.substring(sep + 1)] = true
            }
        }

        onRunningChanged: {
            if (!thumbSync.running) root.thumbTokens = thumbSync.pending
        }
    }
    property bool reloadQueued: false

    function loadHistory() {
        if (isLoading) {
            reloadQueued = true
            return
        }

        isLoading = true
        historyProcess.command = historyCommand()
        historyProcess.running = true
    }

    // Filtering inside cliphist keeps the window over the whole history, not over the last 50.
    function historyCommand() {
        let query = searchQuery.trim()
        if (query.length === 0)
            return ["bash", "-c", "cliphist list | head -n " + maxItems]
        return ["bash", "-c",
            "cliphist list | grep -i -F -- \"$1\" | head -n " + maxItems,
            "bash", query]
    }

    onSearchQueryChanged: searchDebounce.restart()

    property Timer searchDebounce: Timer {
        interval: 120
        onTriggered: root.loadHistory()
    }
    
    function clearHistory() {
        clearProcess.running = true
    }

    // Quickshell only reserves one re-run on a busy Process, so a third id would drop the second.
    property var pendingDeletes: []

    // cliphist reads the line to drop from stdin; an id argument is accepted and ignored.
    function deleteItem(id) {
        pendingDeletes = pendingDeletes.concat([String(id)])
        if (!deleteProcess.running) _drainDeletes()
    }

    function _drainDeletes() {
        if (pendingDeletes.length === 0) return
        const id = pendingDeletes[0]
        pendingDeletes = pendingDeletes.slice(1)
        deleteProcess.command = ["bash", "-c",
            "cliphist list | grep -m1 -P \"^$1\\D\" | cliphist delete",
            "bash", id]
        deleteProcess.running = true
    }
    
    function selectItem(id) {
        selectProcess.command = ["bash", "-c", "cliphist decode \"$1\" | wl-copy", "bash", String(id)]
        selectProcess.running = true
    }
    
    property int maxItems: 50

    property Process historyProcess: Process {
        command: []
        running: false
        property var lines: []
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0) {
                    historyProcess.lines.push(trimmed)
                }
            }
        }
        
        onExited: (exitCode) => {
            isLoading = false
            if (exitCode === 0 && historyProcess.lines.length > 0) {
                let newHistory = []
                
                for (let i = 0; i < historyProcess.lines.length; i++) {
                    let line = historyProcess.lines[i]
                    if (line.length === 0) continue
                    
                    // cliphist list format: "ID├──┤CONTENT" or "ID\tCONTENT" or "ID\tTYPE\tCONTENT"
                    let id, type, content
                    
                    // The id is a leading integer, so whichever delimiter appears first is the real one.
                    let sepAt = line.indexOf('├──┤')
                    let tabAt = line.indexOf('\t')
                    if (sepAt >= 0 && (tabAt < 0 || sepAt < tabAt)) {
                        let parts = line.split('├──┤')
                        if (parts.length >= 2) {
                            id = parts[0].trim()
                            type = "text/plain"
                            content = parts.slice(1).join('├──┤').trim()
                        } else {
                            continue
                        }
                    } else {
                        let parts = line.split('\t')
                        
                        if (parts.length >= 3) {
                            id = parts[0]
                            type = parts[1]
                            content = parts.slice(2).join('\t')
                            if (type !== "text" && type !== "text/plain") {
                                continue
                            }
                        } else if (parts.length >= 2) {
                            id = parts[0]
                            type = "text/plain"
                            content = parts.slice(1).join('\t')
                        } else {
                            continue
                        }
                    }
                    
                    let binary = root.imageEntry.exec(content)
                    let isImage = binary !== null && /\b(png|jpe?g|gif|webp|bmp)\b/i.test(binary[1])

                    let preview = isImage ? binary[1] : content
                    if (preview.length > 100) {
                        preview = preview.substring(0, 97) + "..."
                    }
                    
                    newHistory.push({
                        id: id,
                        type: type,
                        content: content,
                        preview: preview,
                        isImage: isImage,
                        timestamp: Date.now() - i * 1000
                    })
                }
                
                root.history = newHistory
                root.syncThumbnails(newHistory.filter(n => n.isImage).map(n => String(n.id)))
            } else {
                root.history = []
            }
            historyProcess.lines = []

            if (root.reloadQueued) {
                root.reloadQueued = false
                root.loadHistory()
            }
        }
        
        stderr: SplitParser {
            onRead: data => {
            }
        }
    }
    
    property Process clearProcess: Process {
        command: ["cliphist", "wipe"]
        running: false
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.history = []
            }
        }
    }
    
    // No reload here: replacing the model mid-collapse resets the view and the rows below jump.
    property Process deleteProcess: Process {
        command: []
        running: false

        onExited: (exitCode) => {
            if (exitCode !== 0) console.warn("clipboard: cliphist delete exited " + exitCode)
            root._drainDeletes()
        }
    }

    property Process selectProcess: Process {
        command: []
        running: false

        onExited: (exitCode) => {
            if (exitCode === 0) {
                // Reload because selecting an item changes its position in history
                root.loadHistory()
            }
        }
    }
    
    Component.onCompleted: {
    }
}

