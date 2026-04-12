import QtQuick
import Quickshell.Io

QtObject {
    id: musicManager

    property var playerPriority: [
        "spotify",
        "spotifyd",
        "mpd",
        "strawberry",
        "rhythmbox",
        "clementine",
        "audacious",
        "vlc",
        "mpv",
        "firefox",
        "chromium",
        "chrome"
    ]

    property var ignoredPlayers: [
        "plasma-browser-integration",
        "kdeconnect"
    ]

    property string activePlayer: ""
    property var availablePlayers: []

    property string title: ""
    property string artist: ""
    property string album: ""
    property string artUrl: ""
    property string status: "Stopped"
    property bool isPlaying: status === "Playing"
    property bool isAvailable: availablePlayers.length > 0
    property color accentColor: Qt.rgba(0.65, 0.55, 0.85, 0.9)
    
    property var barLevels: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    property Process listPlayersProcess: Process {
        running: false
        command: ["playerctl", "-l"]

        property string outputData: ""

        stdout: SplitParser {
            onRead: data => listPlayersProcess.outputData += data
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                let output = outputData.trim()
                if (output !== "") {
                    let players = output.split('\n').filter(p => p !== "")
                    players = players.filter(p => {
                        return !musicManager.ignoredPlayers.some(ignored => p.includes(ignored))
                    })
                    musicManager.availablePlayers = players
                    musicManager.selectBestPlayer(players)
                } else {
                    musicManager.availablePlayers = []
                    musicManager.activePlayer = ""
                    musicManager.resetMetadata()
                }
            } else {
                musicManager.availablePlayers = []
                musicManager.activePlayer = ""
                musicManager.resetMetadata()
            }
            outputData = ""
        }
    }

    function selectBestPlayer(availablePlayers) {
        if (availablePlayers.length === 0) {
            activePlayer = ""
            resetMetadata()
            return
        }

        if (activePlayer !== "" && availablePlayers.includes(activePlayer)) {
            return
        }

        for (let i = 0; i < playerPriority.length; i++) {
            let preferred = playerPriority[i]
            for (let j = 0; j < availablePlayers.length; j++) {
                if (availablePlayers[j].includes(preferred)) {
                    activePlayer = availablePlayers[j]
                    updateMetadata()
                    return
                }
            }
        }

        if (availablePlayers.length > 0) {
            activePlayer = availablePlayers[0]
            updateMetadata()
        }
    }

    property Process metadataProcess: Process {
        running: false
        command: activePlayer !== ""
            ? ["playerctl", "-p", activePlayer, "metadata",
               "--format", "{{title}}|||{{artist}}|||{{album}}|||{{mpris:artUrl}}|||{{status}}"]
            : []

        property string outputData: ""

        stdout: SplitParser {
            onRead: data => metadataProcess.outputData += data
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && outputData.trim() !== "") {
                let parts = outputData.trim().split("|||")
                if (parts.length >= 5) {
                    let newTitle = parts[0] ? parts[0].trim() : ""
                    let newArtist = parts[1] ? parts[1].trim() : ""
                    let newAlbum = parts[2] ? parts[2].trim() : ""
                    let newArtUrl = parts[3] ? parts[3].trim() : ""
                    let newStatus = parts[4] ? parts[4].trim() : "Stopped"
                    
                    // Fallback: some players only expose xesam:title
                    if (newTitle === "" || newTitle === "Unknown") {
                        if (!altMetadataProcess.running) {
                            Qt.callLater(() => {
                                altMetadataProcess.running = true
                            })
                        }
                    }
                    
                    musicManager.title = newTitle || ""
                    musicManager.artist = newArtist || ""
                    musicManager.album = newAlbum || ""
                    musicManager.artUrl = newArtUrl || ""
                    musicManager.status = newStatus || "Stopped"
                } else {
                    if (parts.length > 0) {
                        musicManager.title = parts[0] ? parts[0].trim() : ""
                    }
                    if (parts.length > 1) {
                        musicManager.artist = parts[1] ? parts[1].trim() : ""
                    }
                    if (parts.length > 4) {
                        musicManager.status = parts[4] ? parts[4].trim() : "Stopped"
                    }
                }
            } else {
                if (activePlayer !== "") {
                    Qt.callLater(() => {
                        musicManager.refreshPlayerList()
                    })
                }
            }
            outputData = ""
        }
    }

    property Process controlProcess: Process {
        running: false
        command: []

        onExited: (exitCode, exitStatus) => {
            Qt.callLater(() => {
                musicManager.updateMetadata()
            })
        }
    }

    function playPause() {
        if (activePlayer !== "") {
            controlProcess.command = ["playerctl", "-p", activePlayer, "play-pause"]
            controlProcess.running = true
        }
    }

    function next() {
        if (activePlayer !== "") {
            controlProcess.command = ["playerctl", "-p", activePlayer, "next"]
            controlProcess.running = true
        }
    }

    function previous() {
        if (activePlayer !== "") {
            controlProcess.command = ["playerctl", "-p", activePlayer, "previous"]
            controlProcess.running = true
        }
    }

    function updateMetadata() {
        if (activePlayer !== "" && !metadataProcess.running) {
            // Qt.callLater: brief wait in case the player is still initializing
            Qt.callLater(() => {
                if (activePlayer !== "" && !metadataProcess.running) {
                    metadataProcess.running = true
                }
            })
        }
    }
    
    property Process altMetadataProcess: Process {
        running: false
        command: activePlayer !== ""
            ? ["playerctl", "-p", activePlayer, "metadata", "xesam:title"]
            : []
        
        property string outputData: ""
        
        stdout: SplitParser {
            onRead: data => altMetadataProcess.outputData += data
        }
        
        onExited: (exitCode) => {
            if (exitCode === 0 && outputData.trim() !== "") {
                let altTitle = outputData.trim()
                if (altTitle !== "" && musicManager.title === "") {
                    musicManager.title = altTitle
                }
            }
            outputData = ""
        }
    }

    function refreshPlayerList() {
        if (!listPlayersProcess.running) {
            listPlayersProcess.running = true
        }
    }

    function resetMetadata() {
        title = ""
        artist = ""
        album = ""
        artUrl = ""
        status = "Stopped"
    }

    function switchToPlayer(playerName) {
        if (availablePlayers.includes(playerName)) {
            activePlayer = playerName
            updateMetadata()
        }
    }

    // Replaced by D-Bus monitoring; kept as disabled fallback
    property Timer updateTimer: Timer {
        interval: 500
        running: false
        repeat: true
        onTriggered: {
            if (musicManager.activePlayer !== "") {
                musicManager.updateMetadata()
            }
        }
    }

    property Timer refreshTimer: Timer {
        interval: 3000
        running: false
        repeat: true
        onTriggered: {
            musicManager.refreshPlayerList()
        }
    }

    property Process dbusMonitor: Process {
        command: [
            "dbus-monitor",
            "--session",
            "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.mpris.MediaPlayer2.Player'",
            "type='signal',interface='org.freedesktop.DBus.ObjectManager',member='InterfacesAdded'",
            "type='signal',interface='org.freedesktop.DBus.ObjectManager',member='InterfacesRemoved'"
        ]
        running: true
        
        stdout: SplitParser {
            onRead: data => {
                musicDebounceTimer.restart()
            }
        }
        
        stderr: SplitParser {
            onRead: data => {}
        }
    }
    
    property Timer musicDebounceTimer: Timer {
        interval: 200
        repeat: false
        onTriggered: {
            if (!listPlayersProcess.running) {
                refreshPlayerList()
            }
            if (activePlayer !== "" && !metadataProcess.running) {
                updateMetadata()
            }
        }
    }

    Component.onCompleted: {
        refreshPlayerList()
    }
    
    Component.onDestruction: {
        if (dbusMonitor.running) {
            dbusMonitor.running = false
        }
    }
}

