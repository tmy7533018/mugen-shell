import QtQuick
import Quickshell.Io

QtObject {
    id: root
    
    property var history: []
    
    property bool isLoading: false

    function loadHistory() {
        if (isLoading) return
        
        isLoading = true
        historyProcess.running = true
    }
    
    function clearHistory() {
        clearProcess.running = true
    }
    
    function deleteItem(id) {
        deleteProcess.command = ["cliphist", "delete", id]
        deleteProcess.running = true
    }
    
    function selectItem(id) {
        selectProcess.command = ["bash", "-c", "cliphist decode " + id + " | wl-copy"]
        selectProcess.running = true
    }
    
    property Process historyProcess: Process {
        command: ["cliphist", "list"]
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
                    
                    if (line.includes('├──┤')) {
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
                    
                    let preview = content
                    if (preview.length > 100) {
                        preview = content.substring(0, 97) + "..."
                    }
                    
                    newHistory.push({
                        id: id,
                        type: type,
                        content: content,
                        preview: preview,
                        timestamp: Date.now() - i * 1000
                    })
                }
                
                root.history = newHistory
            } else {
                root.history = []
            }
            historyProcess.lines = []
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
    
    property Process deleteProcess: Process {
        command: []
        running: false
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.loadHistory()
            }
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

