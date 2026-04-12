import QtQuick
import QtQml
import Qt.labs.folderlistmodel 2.15
import Quickshell
import Quickshell.Io

QtObject {
    id: screenshotManager

    readonly property string picturesDir: Quickshell.env("XDG_PICTURES_DIR") || (Quickshell.env("HOME") + "/Pictures")
    readonly property string screenshotDir: picturesDir + "/mugen-screenshots"

    property var folderModel: null
    property var screenshots: null

    Component.onCompleted: {
        folderModel = Qt.createQmlObject('import Qt.labs.folderlistmodel 2.15; FolderListModel {}', screenshotManager)
        folderModel.folder = "file://" + screenshotManager.screenshotDir
        folderModel.showDirs = false
        folderModel.nameFilters = ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        folderModel.sortField = FolderListModel.Time
        folderModel.sortReversed = true
        folderModel.statusChanged.connect(() => {
        })
        screenshots = folderModel
    }

    property Process ensureDirProcess: Process {
        command: ["bash", "-lc", "mkdir -p '" + screenshotManager.screenshotDir + "'"]
        running: true
        onExited: {
            if (folderModel) {
                folderModel.folder = "file://" + screenshotManager.screenshotDir
                folderModel.sortField = FolderListModel.Time
                folderModel.sortReversed = false
            }
        }
    }

    function refresh() {
        if (folderModel) {
            // FolderListModel has no refresh(); reset folder to force an update
            var currentFolder = folderModel.folder
            folderModel.folder = ""
            Qt.callLater(() => {
                folderModel.folder = currentFolder
                folderModel.sortField = FolderListModel.Time
                folderModel.sortReversed = false
            })
        }
    }

    function filePath(index) {
        if (index < 0 || index >= folderModel.count) return ""
        return screenshotManager.screenshotDir + "/" + folderModel.get(index, "fileName")
    }

    property Process openScreenshotProcess: Process {
        command: []
        running: false
    }

    function openScreenshot(filePath) {
        if (!filePath) return
        openScreenshotProcess.command = ["hyprctl", "dispatch", "exec", "imv '" + filePath + "'"]
        openScreenshotProcess.running = true
    }

    property Process deleteScreenshotProcess: Process {
        command: []
        running: false

        onExited: {
            screenshotManager.refresh()
        }
    }

    function deleteScreenshot(filePath) {
        if (!filePath || deleteScreenshotProcess.running) {
            return
        }
        deleteScreenshotProcess.command = ["rm", "-f", filePath]
        deleteScreenshotProcess.running = true
    }

    property Process copyScreenshotProcess: Process {
        command: []
        running: false
    }

    function copyScreenshot(filePath) {
        if (!filePath || copyScreenshotProcess.running) {
            return
        }
        function escapeSingleQuotes(path) {
            return path.replace(/'/g, "'\"'\"'")
        }
        let escapedPath = escapeSingleQuotes(filePath)
        copyScreenshotProcess.command = ["bash", "-lc", "wl-copy < '" + escapedPath + "'"]
        copyScreenshotProcess.running = true
    }
}

