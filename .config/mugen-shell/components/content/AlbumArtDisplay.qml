import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../ui" as UI

Item {
    id: root
    
    property var musicManager
    property var cavaManager
    property var theme
    property var icons
    required property var modeManager
    
    property color extractedColor: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)

    function defaultAccentColor() {
        return theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
    }

    function lightenColor(baseColor, amount) {
        const mix = Math.max(0.0, Math.min(1.0, amount || 0.0))
        if (!baseColor) {
            return defaultAccentColor()
        }
        let r = baseColor.r + (1.0 - baseColor.r) * mix
        let g = baseColor.g + (1.0 - baseColor.g) * mix
        let b = baseColor.b + (1.0 - baseColor.b) * mix
        return Qt.rgba(r, g, b, baseColor.a !== undefined ? baseColor.a : 1.0)
    }

    function applyExtractedColor(color) {
        let base = color || defaultAccentColor()
        let targetColor = lightenColor(base, 0.4)
        extractedColor = targetColor
        if (musicManager && musicManager.accentColor !== targetColor) {
            musicManager.accentColor = targetColor
        }
    }
    
    width: modeManager.scale(96)
    height: modeManager.scale(96)
    Layout.preferredWidth: width
    Layout.preferredHeight: height
    
    Process {
        id: colorExtractorProcess
        command: []
        running: false
        
        property string output: ""
        
        stdout: SplitParser {
            onRead: data => {
                colorExtractorProcess.output += data
            }
        }
        
        property string errorOutput: ""
        
        stderr: SplitParser {
            onRead: data => {
                colorExtractorProcess.errorOutput += data
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode === 0 && colorExtractorProcess.output.trim().length > 0) {
                try {
                    // Output format: "0.650,0.550,0.850"
                    var output = colorExtractorProcess.output.trim()
                    var parts = output.split(",")
                    
                    if (parts.length === 3) {
                        var r = parseFloat(parts[0])
                        var g = parseFloat(parts[1])
                        var b = parseFloat(parts[2])
                        
                        if (!isNaN(r) && !isNaN(g) && !isNaN(b) &&
                            r >= 0 && r <= 1 && g >= 0 && g <= 1 && b >= 0 && b <= 1) {
                            var baseColor = Qt.rgba(r, g, b, 1.0)
                            var h = baseColor.hslHue
                            var s = Math.min(1.0, baseColor.hslSaturation * 1.5)
                            var l = Math.max(0.2, baseColor.hslLightness * 0.7)
                            var darkerColor = Qt.hsla(h, s, l, 0.9)
                            
                            applyExtractedColor(darkerColor)
                        } else {
                            applyExtractedColor(defaultAccentColor())
                        }
                    } else {
                        applyExtractedColor(defaultAccentColor())
                    }
                } catch (e) {
                    applyExtractedColor(defaultAccentColor())
                }
            } else {
                applyExtractedColor(defaultAccentColor())
            }
            colorExtractorProcess.output = ""
            colorExtractorProcess.errorOutput = ""
        }
    }

    Component.onCompleted: {
        applyExtractedColor(extractedColor)
    }
    
    function extractColorFromImage(imageSource) {
        if (!imageSource || imageSource === "") {
            applyExtractedColor(defaultAccentColor())
            return
        }
        
        var filePath = imageSource.toString()
        
        // Color extraction only works on local files
        if (filePath.startsWith("http://") || filePath.startsWith("https://")) {
            applyExtractedColor(defaultAccentColor())
            return
        }
        
        if (filePath.startsWith("file://")) {
            filePath = filePath.substring(7)
        }
        
        try {
            filePath = decodeURIComponent(filePath)
        } catch (e) {
        }
        
        colorExtractorProcess.command = [
            "python3",
            Quickshell.shellDir + "/scripts/extract-color.py",
            filePath
        ]
        colorExtractorProcess.running = true
    }
    
    property bool hasArt: root.musicManager && root.musicManager.artUrl !== ""

    Rectangle {
        id: artBackground
        anchors.centerIn: parent
        width: modeManager.scale(80)
        height: modeManager.scale(80)
        radius: root.hasArt ? modeManager.scale(12) : width / 2
        color: "transparent"
        border.width: 0
        z: 1

        Behavior on radius {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        scale: 1.0

        Image {
            id: albumArt
            anchors.fill: parent
            source: root.musicManager && root.musicManager.artUrl ? root.musicManager.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: true
            cache: true

            onStatusChanged: {
                if (status === Image.Ready && source && source !== "") {
                    Qt.callLater(() => {
                        root.extractColorFromImage(source)
                    })
                }
            }

            onSourceChanged: {
            }
        }

        OpacityMask {
            anchors.fill: albumArt
            source: albumArt
            maskSource: Rectangle {
                width: albumArt.width
                height: albumArt.height
                radius: artBackground.radius
            }
            visible: root.hasArt
        }

        UI.SvgIcon {
            anchors.centerIn: parent
            width: modeManager.scale(48)
            height: modeManager.scale(48)
            source: root.icons ? root.icons.musicSvg : ""
            color: root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.60)
            opacity: 0.5
            visible: !root.hasArt
        }
    }
    
    Connections {
        target: root.musicManager
        function onArtUrlChanged() {
            // Actual color extraction happens in Image.onStatusChanged after source updates
            if (!root.musicManager || !root.musicManager.artUrl || root.musicManager.artUrl === "") {
                applyExtractedColor(defaultAccentColor())
            }
        }
    }
}

