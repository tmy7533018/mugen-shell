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
    property string _artTrackKey: ""
    property bool _artIsFallback: false
    property string _artCachedUrl: ""
    property string status: "Stopped"
    property bool isPlaying: status === "Playing"
    property bool isAvailable: availablePlayers.length > 0
    property color accentColor: Qt.rgba(0.65, 0.55, 0.85, 0.9)

    property real position: 0
    property real duration: 0
    property bool seekingSuspended: false

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

    function reportArtFailure(url) {
        if (url === "" || url !== artUrl || url === _artCachedUrl) return
        let derived = extractYoutubeThumbnail(_artTrackKey)
        if (derived === "" || derived === url) return
        artUrl = derived
        _artIsFallback = true
    }

    function extractYoutubeThumbnail(url) {
        if (!url) return ""
        var match = url.match(/(?:youtube\.com\/(?:watch\?.*v=|embed\/|shorts\/)|youtu\.be\/|music\.youtube\.com\/watch\?.*v=)([\w-]{11})/)
        return match ? "https://img.youtube.com/vi/" + match[1] + "/mqdefault.jpg" : ""
    }

    readonly property string artCacheScript: 'dir="${XDG_CACHE_HOME:-$HOME/.cache}/mugen-shell/art"\n'
        + 'mkdir -p "$dir" || exit 1\n'
        + 'f="$dir/$(printf %s "$1" | sha1sum | cut -c1-32)"\n'
        + 'if [ ! -s "$f" ]; then\n'
        + '  curl -sfL --max-time 10 -o "$f.part" "$1" || { rm -f "$f.part"; exit 1; }\n'
        + '  mv -f "$f.part" "$f" || exit 1\n'
        + '  ls -1t "$dir" | tail -n +129 | (cd "$dir" && xargs -r rm -f)\n'
        + 'fi\n'
        + 'printf %s "$f"\n'

    property string _artFetching: ""
    property string _artUnreachable: ""
    property string _artCacheOutput: ""

    onArtUrlChanged: cacheRemoteArt()

    function cacheRemoteArt() {
        if (artCacheProcess.running) return
        if (!artUrl.startsWith("http://") && !artUrl.startsWith("https://")) return
        if (artUrl === _artUnreachable) return
        _artFetching = artUrl
        artCacheProcess.command = ["bash", "-c", artCacheScript, "bash", artUrl]
        artCacheProcess.running = true
    }

    property Process artCacheProcess: Process {
        running: false
        command: []

        stdout: SplitParser {
            onRead: data => musicManager._artCacheOutput += data
        }

        onExited: (exitCode) => {
            let path = musicManager._artCacheOutput.trim()
            let source = musicManager._artFetching
            musicManager._artCacheOutput = ""
            musicManager._artFetching = ""
            if (exitCode === 0 && path !== "") {
                musicManager.artRetryTimer.interval = 2000
                if (musicManager.artUrl === source) {
                    musicManager._artCachedUrl = "file://" + path
                    musicManager.artUrl = musicManager._artCachedUrl
                }
            } else {
                musicManager._artUnreachable = source
                musicManager.artRetryTimer.restart()
            }
            Qt.callLater(() => musicManager.cacheRemoteArt())
        }
    }

    property Timer artRetryTimer: Timer {
        interval: 2000
        repeat: false
        onTriggered: {
            musicManager.artRetryTimer.interval = Math.min(60000, musicManager.artRetryTimer.interval * 2)
            musicManager._artUnreachable = ""
            musicManager.cacheRemoteArt()
        }
    }

    property Process metadataProcess: Process {
        running: false
        command: activePlayer !== ""
            ? ["playerctl", "-p", activePlayer, "metadata",
               "--format", "{{title}}|||{{artist}}|||{{album}}|||{{mpris:artUrl}}|||{{status}}|||{{xesam:url}}"]
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
                    let newUrl = (parts.length >= 6 && parts[5]) ? parts[5].trim() : ""

                    let trackKey = newUrl !== "" ? newUrl : (newTitle + "|" + newArtist)
                    if (trackKey !== musicManager._artTrackKey || musicManager.artUrl === "") {
                        musicManager._artIsFallback = newArtUrl === ""
                        if (newArtUrl === "" && newUrl !== "") {
                            newArtUrl = musicManager.extractYoutubeThumbnail(newUrl)
                        }
                        musicManager._artTrackKey = trackKey
                    } else if (musicManager._artIsFallback && newArtUrl !== "") {
                        musicManager._artIsFallback = false
                    } else {
                        newArtUrl = musicManager.artUrl
                    }

                    // some players only expose xesam:title
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

    function updatePosition() {
        if (activePlayer === "" || seekingSuspended) return
        if (!positionProcess.running) {
            positionProcess.running = true
        }
    }

    function seek(seconds) {
        if (activePlayer === "") return
        const clamped = Math.max(0, Math.min(duration > 0 ? duration : seconds, seconds))
        seekProcess.command = ["playerctl", "-p", activePlayer, "position", clamped.toString()]
        seekProcess.running = true
        // optimistic local: slider follows cursor instantly
        position = clamped
    }

    property Process positionProcess: Process {
        command: []
        running: false
        property string outputData: ""

        stdout: SplitParser {
            onRead: data => positionProcess.outputData += data
        }

        onExited: () => {
            const trimmed = positionProcess.outputData.trim()
            positionProcess.outputData = ""
            if (musicManager.seekingSuspended) return
            const parts = trimmed.split(/\s+/)
            if (parts.length >= 2) {
                const pos = parseFloat(parts[0])
                // mpris:length = µs
                const lenUs = parseFloat(parts[1])
                if (!isNaN(pos)) musicManager.position = pos
                if (!isNaN(lenUs)) musicManager.duration = lenUs / 1e6
            }
        }
    }

    property Process seekProcess: Process {
        command: []
        running: false
    }

    property Timer positionTimer: Timer {
        interval: 1000
        repeat: true
        running: musicManager.isPlaying && musicManager.activePlayer !== ""
        triggeredOnStart: true
        onTriggered: {
            if (musicManager.activePlayer === "" || musicManager.seekingSuspended) return
            positionProcess.command = [
                "bash", "-c",
                "echo \"$(playerctl -p \"$1\" position 2>/dev/null || echo 0) "
                + "$(playerctl -p \"$1\" metadata mpris:length 2>/dev/null || echo 0)\"",
                "bash", musicManager.activePlayer
            ]
            musicManager.updatePosition()
        }
    }
}

