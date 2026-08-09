import QtQuick
import Quickshell
import Quickshell.Io
import "../../lib" as Theme

QtObject {
    id: wallpaperManager

    readonly property string cacheDir: Theme.Paths.cacheDir
    readonly property string dataDir: Theme.Paths.dataDir

    property string wallpaperDir: dataDir + "/wallpapers"
    property string thumbDir: cacheDir + "/wallpaper-thumbs"
    property string currentWallpaperFile: cacheDir + "/wallp/current_wallpaper_path.txt"

    property var wallpapers: []
    property string currentWallpaperPath: ""
    property bool isLoading: false

    property bool isInitialized: false

    // Raised by the picker so files dropped in while it is open show up without a reopen.
    property bool pickerOpen: false

    readonly property bool currentWallpaperExists:
        currentWallpaperPath.length > 0 && (wallpapers || []).indexOf(currentWallpaperPath) !== -1

    // Video path -> generation counter, which rides in the URL so Qt reloads a regenerated file.
    property var thumbTokens: ({})

    property Process mkdirProcess: Process {
        running: false
        command: []

        // Chained after the mkdir so a first run enumerates the folder it just created.
        onExited: () => {
            wallpaperManager.loadWallpapers()
        }
    }

    function loadWallpapers() {
        currentWallpaperProcess.running = true
        refreshWallpapers()
    }

    function refreshWallpapers() {
        if (!wallpaperProcess.running)
            wallpaperProcess.running = true
    }

    function setWallpaper(path) {
        // Detached: the script runs for seconds and a hot-reload would SIGTERM a tracked Process.
        Quickshell.execDetached([
            "bash",
            Quickshell.shellDir + "/scripts/change-wallpaper.sh",
            path
        ])
    }

    function isVideoFile(path) {
        let lower = path.toLowerCase()
        return lower.endsWith('.mp4') || lower.endsWith('.webm') ||
               lower.endsWith('.mkv') || lower.endsWith('.gif')
    }

    function thumbnailPathFor(videoPath) {
        return thumbDir + "/" + videoPath.split('/').pop() + ".png"
    }

    // Empty until a video's thumbnail exists, so the delegate can hold a placeholder.
    function thumbnailSource(path) {
        if (!isVideoFile(path))
            return "file://" + path

        let token = thumbTokens[path]
        if (token === undefined)
            return ""

        let url = "file://" + thumbnailPathFor(path)
        return token > 0 ? url + "#" + token : url
    }

    function applyThumbState(state, videoPath) {
        let prev = thumbTokens[videoPath]
        if (state === "ok" && prev !== undefined)
            return

        let next = Object.assign({}, thumbTokens)
        next[videoPath] = (state === "new" && prev !== undefined) ? prev + 1 : 0
        thumbTokens = next
    }

    function pruneThumbTokens() {
        let list = wallpapers || []
        let next = {}
        let changed = false

        for (let key in thumbTokens) {
            if (list.indexOf(key) !== -1)
                next[key] = thumbTokens[key]
            else
                changed = true
        }

        if (changed)
            thumbTokens = next
    }

    function syncThumbnails() {
        if (thumbSyncProcess.running)
            return

        let videos = (wallpapers || []).filter(isVideoFile)
        thumbSyncProcess.command = [
            "bash",
            Quickshell.shellDir + "/scripts/sync-wallpaper-thumbs.sh",
            thumbDir
        ].concat(videos)
        thumbSyncProcess.running = true
    }

    function sameList(a, b) {
        if (!a || !b || a.length !== b.length)
            return false
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i])
                return false
        }
        return true
    }

    property Process thumbSyncProcess: Process {
        command: []
        running: false

        stdout: SplitParser {
            onRead: data => {
                let line = data.trim()
                let sep = line.indexOf('\t')
                if (sep > 0)
                    wallpaperManager.applyThumbState(line.substring(0, sep), line.substring(sep + 1))
            }
        }

        onExited: () => {
            wallpaperManager.pruneThumbTokens()
        }
    }

    property Process currentWallpaperProcess: Process {
        command: ["cat", wallpaperManager.currentWallpaperFile]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let path = this.text.trim()
                if (path.length > 0)
                    wallpaperManager.currentWallpaperPath = path
            }
        }
    }

    property Process wallpaperProcess: Process {
        // The sentinel stands in for find's exit status, which onStreamFinished cannot see.
        command: [
            "bash", "-c",
            "set -o pipefail; find -L \"$1\" -maxdepth 2 -type f \\( " +
            "-iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o " +
            "-iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' -o " +
            "-iname '*.mkv' -o -iname '*.gif' \\) | sort && echo __END__",
            "_", wallpaperManager.wallpaperDir
        ]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                wallpaperManager.isLoading = false

                let lines = this.text.split("\n")
                if (lines.indexOf("__END__") === -1)
                    return

                let found = lines.filter(l => l.length > 0 && l !== "__END__")
                let changed = !wallpaperManager.sameList(found, wallpaperManager.wallpapers)
                if (changed)
                    wallpaperManager.wallpapers = found

                // A file replaced in place leaves the listing identical, so recheck while it is visible.
                if (changed || wallpaperManager.pickerOpen)
                    wallpaperManager.syncThumbnails()
            }
        }
    }

    // No directory watch available, so poll: tightly with the picker open, lazily otherwise.
    property Timer refreshTimer: Timer {
        interval: wallpaperManager.pickerOpen ? 2000 : 30000
        running: true
        repeat: true
        onTriggered: wallpaperManager.refreshWallpapers()
    }

    property FileView currentWallpaperWatcher: FileView {
        path: wallpaperManager.currentWallpaperFile
        watchChanges: true
        preload: false
        printErrors: false

        onFileChanged: {
            currentWallpaperProcess.running = true
        }
    }

    Component.onCompleted: {
        isLoading = true

        mkdirProcess.command = ["mkdir", "-p", thumbDir, wallpaperDir]
        mkdirProcess.running = true

        isInitialized = true
    }
}

