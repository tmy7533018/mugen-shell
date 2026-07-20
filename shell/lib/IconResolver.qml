import QtQuick
import Quickshell

QtObject {
    id: resolver

    property string iconTheme: ""

    // From XDG_DATA_DIRS rather than a hardcoded /usr/share, so lookup works
    // on NixOS as well as FHS distros.
    readonly property var dataDirs: {
        let dirs = []
        const home = Quickshell.env("HOME") || ""
        if (home !== "")
            dirs.push(home + "/.local/share")
        const xdg = Quickshell.env("XDG_DATA_DIRS") || "/usr/local/share:/usr/share"
        for (const d of xdg.split(":")) {
            if (d !== "" && dirs.indexOf(d) === -1)
                dirs.push(d)
        }
        return dirs
    }

    function resolveIconPath(iconName) {
        if (!iconName || iconName === "") {
            return []
        }

        if (iconName.startsWith("/")) {
            return [iconName]
        }

        let baseName = iconName.replace(/\.(png|svg|xpm)$/, "")

        let paths = []

        if (iconTheme && iconTheme !== "" && iconTheme !== "hicolor") {
            for (const dataDir of dataDirs) {
                const themeBase = dataDir + "/icons/" + iconTheme

                paths.push(themeBase + "/scalable/apps/" + baseName + ".svg")
                paths.push(themeBase + "/scalable/apps/" + baseName + ".png")
                paths.push(themeBase + "/256x256/apps/" + baseName + ".png")
                paths.push(themeBase + "/128x128/apps/" + baseName + ".png")
                paths.push(themeBase + "/64x64/apps/" + baseName + ".png")
                paths.push(themeBase + "/48x48/apps/" + baseName + ".png")
                paths.push(themeBase + "/32x32/apps/" + baseName + ".png")

                paths.push(themeBase + "/scalable/devices/" + baseName + ".svg")
                paths.push(themeBase + "/scalable/devices/" + baseName + ".png")
                paths.push(themeBase + "/256x256/devices/" + baseName + ".png")
                paths.push(themeBase + "/128x128/devices/" + baseName + ".png")
                paths.push(themeBase + "/64x64/devices/" + baseName + ".png")
                paths.push(themeBase + "/48x48/devices/" + baseName + ".png")

                // Some themes reverse the nesting: apps/scalable/, not scalable/apps/
                paths.push(themeBase + "/apps/scalable/" + baseName + ".svg")
                paths.push(themeBase + "/apps/48/" + baseName + ".svg")
            }
        }

        for (const dataDir of dataDirs) {
            const hicolorBase = dataDir + "/icons/hicolor"

            paths.push(hicolorBase + "/scalable/apps/" + baseName + ".svg")
            paths.push(hicolorBase + "/scalable/apps/" + baseName + ".png")
            paths.push(hicolorBase + "/128x128/apps/" + baseName + ".png")
            paths.push(hicolorBase + "/48x48/apps/" + baseName + ".png")

            paths.push(hicolorBase + "/scalable/devices/" + baseName + ".svg")
            paths.push(hicolorBase + "/scalable/devices/" + baseName + ".png")
            paths.push(hicolorBase + "/128x128/devices/" + baseName + ".png")
            paths.push(hicolorBase + "/48x48/devices/" + baseName + ".png")
        }

        for (const dataDir of dataDirs) {
            paths.push(dataDir + "/pixmaps/" + baseName + ".svg")
            paths.push(dataDir + "/pixmaps/" + baseName + ".png")
        }

        return paths
    }
}
