import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: wallpaperManager

    property string wallpaperDir: Quickshell.shellDir + "/wallpapers"
    property string thumbDir: Quickshell.shellDir + "/.cache/wallpaper-thumbs"
    property string currentWallpaperFile: Quickshell.shellDir + "/.cache/wallp/current_wallpaper_path.txt"
    
    property var wallpapers: []
    property string currentWallpaperPath: ""
    property bool isLoading: false
    
    property bool isInitialized: false

    property Process mkdirProcess: Process {
        running: false
        command: []
    }

    function loadWallpapers() {
        isLoading = true
        currentWallpaperProcess.running = true
        wallpaperProcess.running = true
    }

    function setWallpaper(path) {
        setWallpaperProcess.command = [
            "bash",
            Quickshell.shellDir + "/scripts/change-wallpaper.sh",
            path
        ]
        setWallpaperProcess.running = true
    }

    function isVideoFile(path) {
        let lower = path.toLowerCase()
        return lower.endsWith('.mp4') || lower.endsWith('.webm') || 
               lower.endsWith('.mkv') || lower.endsWith('.gif')
    }

    function getThumbnailPath(wallpaperPath) {
        if (!isVideoFile(wallpaperPath)) {
            return wallpaperPath
        }
        let filename = wallpaperPath.split('/').pop()
        let thumbPath = thumbDir + "/" + filename + ".png"
        
        generateThumbnail(wallpaperPath, thumbPath)
        
        return thumbPath
    }

    function generateThumbnail(videoPath, outputPath) {
        checkThumbnailProcess.command = ["test", "-f", outputPath]
        checkThumbnailProcess.videoPath = videoPath
        checkThumbnailProcess.outputPath = outputPath
        checkThumbnailProcess.running = true
    }

    property Process checkThumbnailProcess: Process {
        command: []
        running: false
        property string videoPath: ""
        property string outputPath: ""

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                thumbnailProcess.command = [
                    "ffmpeg", "-y", "-v", "error",
                    "-ss", "2",
                    "-i", videoPath,
                    "-vf", "scale=360:-1:force_original_aspect_ratio=decrease",
                    "-frames:v", "1",
                    outputPath
                ]
                thumbnailProcess.running = true
            }
        }
    }

    property Process thumbnailProcess: Process {
        command: []
        running: false
        
        onExited: (exitCode) => {
        }
    }

    property Process currentWallpaperProcess: Process {
        command: ["cat", wallpaperManager.currentWallpaperFile]
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => { currentWallpaperProcess.output += data }
        }

        onExited: (exitCode) => {
            if (exitCode === 0 && currentWallpaperProcess.output.trim().length > 0) {
                wallpaperManager.currentWallpaperPath = currentWallpaperProcess.output.trim()
            }
            currentWallpaperProcess.output = ""
        }
    }

    property Process wallpaperProcess: Process {
        command: [
            "bash", "-c",
            "find -L '" + wallpaperManager.wallpaperDir + "' -maxdepth 2 -type f \\( " +
            "-iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o " +
            "-iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' -o " +
            "-iname '*.mkv' -o -iname '*.gif' \\) | sort"
        ]
        running: false
        property var files: []

        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0) {
                    wallpaperProcess.files.push(trimmed)
                }
            }
        }

        onExited: () => {
            wallpaperManager.wallpapers = wallpaperProcess.files
            wallpaperManager.isLoading = false
            wallpaperProcess.files = []
        }
    }

    property Process setWallpaperProcess: Process {
        command: []
        running: false
        
        stdout: SplitParser {
        }
        
        stderr: SplitParser {
        }
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                Qt.callLater(() => {
                    currentWallpaperProcess.running = true
                })
            }
        }
    }

    Component.onCompleted: {
        mkdirProcess.command = ["mkdir", "-p", thumbDir]
        mkdirProcess.running = true
        
        isInitialized = true
    }
}

