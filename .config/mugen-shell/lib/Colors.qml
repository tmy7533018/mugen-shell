import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: palette

    property string colorsJsonFile: Quickshell.shellDir + "/.cache/colors/Colors.json"
    property string themeModeFile: Quickshell.shellDir + "/.cache/theme-mode.txt"
    property string lastModified: ""
    
    property string themeMode: "dark"

    function toggleThemeMode() {
        themeMode = (themeMode === "dark") ? "light" : "dark"
        saveThemeMode()
    }
    
    function saveThemeMode() {
        saveThemeModeProcess.command = [
            "bash", "-c",
            "mkdir -p \"" + Quickshell.shellDir + "/.cache\" && echo \"" + themeMode + "\" > \"" + themeModeFile + "\""
        ]
        saveThemeModeProcess.running = true
    }
    
    function loadThemeMode() {
        readThemeModeProcess.running = true
    }

    property string primaryHex: "#a68cd9"
    property string secondaryHex: "#b8a5e0"
    property string tertiaryHex: "#c9b8e8"
    
    function loadFromJson() {
        readColorsProcess.running = true
    }
    
    property Process readColorsProcess: Process {
        command: ["cat", palette.colorsJsonFile]
        running: false
        property string output: ""
        
        stdout: SplitParser {
            onRead: data => { readColorsProcess.output += data }
        }
        
        onExited: (exitCode) => {
            if (exitCode === 0 && readColorsProcess.output.trim().length > 0) {
                try {
                    let json = JSON.parse(readColorsProcess.output.trim())
                    if (json.colors && json.colors.primary && json.colors.primary.hex) {
                        palette.primaryHex = json.colors.primary.hex
                    }
                    if (json.colors && json.colors.secondary && json.colors.secondary.hex) {
                        palette.secondaryHex = json.colors.secondary.hex
                    }
                    if (json.colors && json.colors.tertiary && json.colors.tertiary.hex) {
                        palette.tertiaryHex = json.colors.tertiary.hex
                    }
                } catch (e) {
                }
            }
            readColorsProcess.output = ""
        }
    }
    
    property Process statProcess: Process {
        command: ["stat", "-c", "%Y", palette.colorsJsonFile]
        running: false
        property string output: ""
        
        stdout: SplitParser {
            onRead: data => { statProcess.output += data }
        }
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                let modified = statProcess.output.trim()
                if (modified !== palette.lastModified && modified.length > 0) {
                    palette.lastModified = modified
                    palette.loadFromJson()
                }
            }
            statProcess.output = ""
        }
    }
    
    property Timer checkTimer: Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            statProcess.running = true
        }
    }
    
    property Process readThemeModeProcess: Process {
        command: ["cat", palette.themeModeFile]
        running: false
        property string output: ""
        
        stdout: SplitParser {
            onRead: data => { readThemeModeProcess.output += data }
        }
        
        onExited: (exitCode) => {
            if (exitCode === 0 && readThemeModeProcess.output.trim().length > 0) {
                let mode = readThemeModeProcess.output.trim()
                if (mode === "light" || mode === "dark") {
                    palette.themeMode = mode
                }
            }
            readThemeModeProcess.output = ""
        }
    }
    
    property Process saveThemeModeProcess: Process {
        command: []
        running: false
    }
    
    Component.onCompleted: {
        loadThemeMode()
        loadFromJson()
        statProcess.running = true
    }
    
    property color _glowPrimary: Qt.rgba(
        parseInt(primaryHex.substring(1, 3), 16) / 255,
        parseInt(primaryHex.substring(3, 5), 16) / 255,
        parseInt(primaryHex.substring(5, 7), 16) / 255,
        0.85
    )
    
    property color _glowSecondary: Qt.rgba(
        parseInt(secondaryHex.substring(1, 3), 16) / 255,
        parseInt(secondaryHex.substring(3, 5), 16) / 255,
        parseInt(secondaryHex.substring(5, 7), 16) / 255,
        0.85
    )
    
    property color _glowTertiary: Qt.rgba(
        parseInt(tertiaryHex.substring(1, 3), 16) / 255,
        parseInt(tertiaryHex.substring(3, 5), 16) / 255,
        parseInt(tertiaryHex.substring(5, 7), 16) / 255,
        0.85
    )
    
    property color _chipActiveBg: Qt.rgba(
        parseInt(primaryHex.substring(1, 3), 16) / 255,
        parseInt(primaryHex.substring(3, 5), 16) / 255,
        parseInt(primaryHex.substring(5, 7), 16) / 255,
        0.25
    )
    
    property color _chipActiveBorder: Qt.rgba(
        parseInt(primaryHex.substring(1, 3), 16) / 255,
        parseInt(primaryHex.substring(3, 5), 16) / 255,
        parseInt(primaryHex.substring(5, 7), 16) / 255,
        0.40
    )
    
    property color _accent: Qt.rgba(
        parseInt(primaryHex.substring(1, 3), 16) / 255,
        parseInt(primaryHex.substring(3, 5), 16) / 255,
        parseInt(primaryHex.substring(5, 7), 16) / 255,
        0.85
    )
    
    onPrimaryHexChanged: {
        let newColor = Qt.rgba(
            parseInt(primaryHex.substring(1, 3), 16) / 255,
            parseInt(primaryHex.substring(3, 5), 16) / 255,
            parseInt(primaryHex.substring(5, 7), 16) / 255,
            0.85
        )
        let newBgColor = Qt.rgba(
            parseInt(primaryHex.substring(1, 3), 16) / 255,
            parseInt(primaryHex.substring(3, 5), 16) / 255,
            parseInt(primaryHex.substring(5, 7), 16) / 255,
            0.25
        )
        let newBorderColor = Qt.rgba(
            parseInt(primaryHex.substring(1, 3), 16) / 255,
            parseInt(primaryHex.substring(3, 5), 16) / 255,
            parseInt(primaryHex.substring(5, 7), 16) / 255,
            0.40
        )
        _glowPrimary = newColor
        _chipActiveBg = newBgColor
        _chipActiveBorder = newBorderColor
        _accent = newColor
        colorAnimator.animatedGlowPrimary = newColor
        colorAnimator.animatedChipActiveBg = newBgColor
        colorAnimator.animatedChipActiveBorder = newBorderColor
        colorAnimator.animatedAccent = newColor
    }
    
    onSecondaryHexChanged: {
        let newColor = Qt.rgba(
            parseInt(secondaryHex.substring(1, 3), 16) / 255,
            parseInt(secondaryHex.substring(3, 5), 16) / 255,
            parseInt(secondaryHex.substring(5, 7), 16) / 255,
            0.85
        )
        _glowSecondary = newColor
        colorAnimator.animatedGlowSecondary = newColor
    }
    
    onTertiaryHexChanged: {
        let newColor = Qt.rgba(
            parseInt(tertiaryHex.substring(1, 3), 16) / 255,
            parseInt(tertiaryHex.substring(3, 5), 16) / 255,
            parseInt(tertiaryHex.substring(5, 7), 16) / 255,
            0.85
        )
        _glowTertiary = newColor
        colorAnimator.animatedGlowTertiary = newColor
    }
    
    property Item colorAnimator: Item {
        property color animatedGlowPrimary: Qt.rgba(
            parseInt(palette.primaryHex.substring(1, 3), 16) / 255,
            parseInt(palette.primaryHex.substring(3, 5), 16) / 255,
            parseInt(palette.primaryHex.substring(5, 7), 16) / 255,
            0.85
        )
        property color animatedGlowSecondary: Qt.rgba(
            parseInt(palette.secondaryHex.substring(1, 3), 16) / 255,
            parseInt(palette.secondaryHex.substring(3, 5), 16) / 255,
            parseInt(palette.secondaryHex.substring(5, 7), 16) / 255,
            0.85
        )
        property color animatedGlowTertiary: Qt.rgba(
            parseInt(palette.tertiaryHex.substring(1, 3), 16) / 255,
            parseInt(palette.tertiaryHex.substring(3, 5), 16) / 255,
            parseInt(palette.tertiaryHex.substring(5, 7), 16) / 255,
            0.85
        )
        property color animatedChipActiveBg: Qt.rgba(
            parseInt(palette.primaryHex.substring(1, 3), 16) / 255,
            parseInt(palette.primaryHex.substring(3, 5), 16) / 255,
            parseInt(palette.primaryHex.substring(5, 7), 16) / 255,
            0.25
        )
        property color animatedChipActiveBorder: Qt.rgba(
            parseInt(palette.primaryHex.substring(1, 3), 16) / 255,
            parseInt(palette.primaryHex.substring(3, 5), 16) / 255,
            parseInt(palette.primaryHex.substring(5, 7), 16) / 255,
            0.40
        )
        property color animatedAccent: Qt.rgba(
            parseInt(palette.primaryHex.substring(1, 3), 16) / 255,
            parseInt(palette.primaryHex.substring(3, 5), 16) / 255,
            parseInt(palette.primaryHex.substring(5, 7), 16) / 255,
            0.85
        )
        
        Behavior on animatedGlowPrimary {
            ColorAnimation {
                duration: 3000
                easing.type: Easing.InOutCubic
            }
        }
        
        Behavior on animatedGlowSecondary {
            ColorAnimation {
                duration: 3000
                easing.type: Easing.InOutCubic
            }
        }
        
        Behavior on animatedGlowTertiary {
            ColorAnimation {
                duration: 3000
                easing.type: Easing.InOutCubic
            }
        }
        
        Behavior on animatedChipActiveBg {
            ColorAnimation {
                duration: 3000
                easing.type: Easing.InOutCubic
            }
        }
        
        Behavior on animatedChipActiveBorder {
            ColorAnimation {
                duration: 3000
                easing.type: Easing.InOutCubic
            }
        }
        
        Behavior on animatedAccent {
            ColorAnimation {
                duration: 3000
                easing.type: Easing.InOutCubic
            }
        }
    }
    
    property color glowPrimary: colorAnimator.animatedGlowPrimary
    property color glowSecondary: colorAnimator.animatedGlowSecondary
    property color glowTertiary: colorAnimator.animatedGlowTertiary
    
    readonly property color darkSurfaceBorder: Qt.rgba(0.70, 0.65, 0.90, 0.3)
    readonly property color darkSurfaceGlass: Qt.rgba(0.08, 0.05, 0.15, 0.32)
    readonly property color darkTextPrimary: Qt.rgba(0.92, 0.92, 0.96, 0.90)
    readonly property color darkTextSecondary: Qt.rgba(0.72, 0.72, 0.82, 0.90)
    readonly property color darkTextFaint: Qt.rgba(0.62, 0.62, 0.72, 0.90)
    readonly property color darkChipInactiveBg: Qt.rgba(0.45, 0.45, 0.60, 0.10)
    readonly property color darkChipInactiveBorder: Qt.rgba(0.55, 0.55, 0.68, 0.15)
    readonly property color darkSurfaceInsetSubtle: Qt.rgba(0, 0, 0, 0.25)
    readonly property color darkSurfaceInsetCard: Qt.rgba(0, 0, 0, 0.65)
    readonly property color darkSurfaceInsetCardHover: Qt.rgba(0, 0, 0, 0.75)

    // Light mode leans into a clear "frosted glass" feel: white-tinted surfaces at low opacity,
    // wallpaper bleeds through. White text stays readable on the soft veil.
    readonly property color lightSurfaceBorder: Qt.rgba(1.0, 1.0, 1.0, 0.35)
    readonly property color lightSurfaceGlass: Qt.rgba(1.0, 1.0, 1.0, 0.15)
    readonly property color lightTextPrimary: Qt.rgba(0.92, 0.92, 0.96, 0.90)
    readonly property color lightTextSecondary: Qt.rgba(0.72, 0.72, 0.82, 0.90)
    readonly property color lightTextFaint: Qt.rgba(0.62, 0.62, 0.72, 0.90)
    readonly property color lightChipInactiveBg: Qt.rgba(1.0, 1.0, 1.0, 0.12)
    readonly property color lightChipInactiveBorder: Qt.rgba(1.0, 1.0, 1.0, 0.20)
    readonly property color lightSurfaceInsetSubtle: Qt.rgba(0, 0, 0, 0.18)
    readonly property color lightSurfaceInsetCard: Qt.rgba(0, 0, 0, 0.40)
    readonly property color lightSurfaceInsetCardHover: Qt.rgba(0, 0, 0, 0.55)

    property color surfaceBorder: themeMode === "light" ? lightSurfaceBorder : darkSurfaceBorder
    property color surfaceGlass: themeMode === "light" ? lightSurfaceGlass : darkSurfaceGlass
    property color textPrimary: themeMode === "light" ? lightTextPrimary : darkTextPrimary
    property color textSecondary: themeMode === "light" ? lightTextSecondary : darkTextSecondary
    property color textFaint: themeMode === "light" ? lightTextFaint : darkTextFaint
    property color chipInactiveBg: themeMode === "light" ? lightChipInactiveBg : darkChipInactiveBg
    property color chipInactiveBorder: themeMode === "light" ? lightChipInactiveBorder : darkChipInactiveBorder
    property color surfaceInsetSubtle: themeMode === "light" ? lightSurfaceInsetSubtle : darkSurfaceInsetSubtle
    property color surfaceInsetCard: themeMode === "light" ? lightSurfaceInsetCard : darkSurfaceInsetCard
    property color surfaceInsetCardHover: themeMode === "light" ? lightSurfaceInsetCardHover : darkSurfaceInsetCardHover

    property color chipActiveBg: colorAnimator.animatedChipActiveBg
    property color chipActiveBorder: colorAnimator.animatedChipActiveBorder
    property color accent: colorAnimator.animatedAccent

    Behavior on surfaceBorder { ColorAnimation { duration: 400; easing.type: Easing.InOutCubic } }
    Behavior on surfaceGlass { ColorAnimation { duration: 400; easing.type: Easing.InOutCubic } }
    Behavior on textPrimary { ColorAnimation { duration: 400; easing.type: Easing.InOutCubic } }
    Behavior on textSecondary { ColorAnimation { duration: 400; easing.type: Easing.InOutCubic } }
    Behavior on textFaint { ColorAnimation { duration: 400; easing.type: Easing.InOutCubic } }
    Behavior on chipInactiveBg { ColorAnimation { duration: 400; easing.type: Easing.InOutCubic } }
    Behavior on chipInactiveBorder { ColorAnimation { duration: 400; easing.type: Easing.InOutCubic } }
    Behavior on surfaceInsetSubtle { ColorAnimation { duration: 400; easing.type: Easing.InOutCubic } }
    Behavior on surfaceInsetCard { ColorAnimation { duration: 400; easing.type: Easing.InOutCubic } }
    Behavior on surfaceInsetCardHover { ColorAnimation { duration: 400; easing.type: Easing.InOutCubic } }
}
