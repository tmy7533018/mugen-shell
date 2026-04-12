import QtQuick

QtObject {
    id: resolver
    
    property string iconTheme: ""
    
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

            paths.push("/usr/share/icons/" + iconTheme + "/scalable/apps/" + baseName + ".svg")
            paths.push("/usr/share/icons/" + iconTheme + "/scalable/apps/" + baseName + ".png")
            paths.push("/usr/share/icons/" + iconTheme + "/256x256/apps/" + baseName + ".png")
            paths.push("/usr/share/icons/" + iconTheme + "/128x128/apps/" + baseName + ".png")
            paths.push("/usr/share/icons/" + iconTheme + "/64x64/apps/" + baseName + ".png")
            paths.push("/usr/share/icons/" + iconTheme + "/48x48/apps/" + baseName + ".png")
            paths.push("/usr/share/icons/" + iconTheme + "/32x32/apps/" + baseName + ".png")
            
            paths.push("/usr/share/icons/" + iconTheme + "/scalable/devices/" + baseName + ".svg")
            paths.push("/usr/share/icons/" + iconTheme + "/scalable/devices/" + baseName + ".png")
            paths.push("/usr/share/icons/" + iconTheme + "/256x256/devices/" + baseName + ".png")
            paths.push("/usr/share/icons/" + iconTheme + "/128x128/devices/" + baseName + ".png")
            paths.push("/usr/share/icons/" + iconTheme + "/64x64/devices/" + baseName + ".png")
            paths.push("/usr/share/icons/" + iconTheme + "/48x48/devices/" + baseName + ".png")
            
            // Some themes use reversed directory structure (apps/scalable/ instead of scalable/apps/)
            paths.push("/usr/share/icons/" + iconTheme + "/apps/scalable/" + baseName + ".svg")
            paths.push("/usr/share/icons/" + iconTheme + "/apps/48/" + baseName + ".svg")
        }
        
        paths.push("/usr/share/icons/hicolor/scalable/apps/" + baseName + ".svg")
        paths.push("/usr/share/icons/hicolor/scalable/apps/" + baseName + ".png")
        paths.push("/usr/share/icons/hicolor/128x128/apps/" + baseName + ".png")
        paths.push("/usr/share/icons/hicolor/48x48/apps/" + baseName + ".png")
        
        paths.push("/usr/share/icons/hicolor/scalable/devices/" + baseName + ".svg")
        paths.push("/usr/share/icons/hicolor/scalable/devices/" + baseName + ".png")
        paths.push("/usr/share/icons/hicolor/128x128/devices/" + baseName + ".png")
        paths.push("/usr/share/icons/hicolor/48x48/devices/" + baseName + ".png")
        
        paths.push("/usr/share/pixmaps/" + baseName + ".svg")
        paths.push("/usr/share/pixmaps/" + baseName + ".png")
        
        return paths
    }
}

