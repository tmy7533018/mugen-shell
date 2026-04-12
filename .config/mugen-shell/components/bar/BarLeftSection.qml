import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../ui" as UI
import "../common" as Common

RowLayout {
    id: root
    
    spacing: 4
    Layout.alignment: Qt.AlignVCenter
    
    property var theme
    property var typo
    property var icons
    property var modeManager
    property var imeStatus
    property var screenshotManager
    property var audioManager
    property var musicPlayerManager
    property var cavaManager
    

    
    function blendColors(baseColor, accentColor, factor) {
        const safeFactor = Math.max(0, Math.min(1, factor || 0))
        const base = baseColor || Qt.rgba(0.72, 0.72, 0.82, 0.90)
        const accent = accentColor || Qt.rgba(0.65, 0.55, 0.85, 0.9)
        return Qt.rgba(
            base.r + (accent.r - base.r) * safeFactor,
            base.g + (accent.g - base.g) * safeFactor,
            base.b + (accent.b - base.b) * safeFactor,
            base.a + (accent.a - base.a) * safeFactor
        )
    }
    
    function scaled(val) {
        if (modeManager) return modeManager.scale(val)
        return val
    }
    
    component Separator: UI.SvgIcon {
        width: 1
        height: scaled(16)
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: scaled(-4)
        Layout.rightMargin: scaled(-4)
        source: Quickshell.shellDir + "/assets/icons/divider.svg"
        color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.40)
        opacity: 0.5
    }
    
    Common.IconButton {
        modeManager: root.modeManager
        iconSource: root.icons ? (root.icons.iconData.launcher.type === "svg" ? root.icons.iconData.launcher.value : "") : ""
        iconText: root.icons ? (root.icons.iconData.launcher.type === "text" ? root.icons.iconData.launcher.value : "") : ""
        iconColor: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        fontSize: root.typo ? root.typo.clockStyle.size : 14
        fontFamily: root.typo ? root.typo.clockStyle.family : "M PLUS 2"
        fontWeight: root.typo ? root.typo.clockStyle.weight : Font.Normal
        letterSpacing: root.typo ? root.typo.clockStyle.letterSpacing : 0
        
        onClicked: {
            if (root.modeManager) {
                root.modeManager.switchMode("launcher")
            }
        }
    }
    
    Separator {}

    Item {
        id: clockContainer
        implicitWidth: clockComponent.implicitWidth
        implicitHeight: clockComponent.implicitHeight
        Layout.alignment: Qt.AlignVCenter
        
        function generateRandomGlowColor() {
            let hue = (Date.now() % 360) + Math.random() * 360
            if (hue > 360) hue = hue % 360
            let saturation = 0.3 + Math.random() * 0.4
            let value = 0.8 + Math.random() * 0.2
            return Qt.hsva(hue / 360, saturation, value, 0.6)
        }

        property color glowColor: generateRandomGlowColor()

        UI.Clock {
            id: clockComponent
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: scaled(-1)
            modeManager: root.modeManager
            theme: root.theme
            typo: root.typo
            showSeconds: false
            isHovered: clockMouseArea.containsMouse
            glowColor: clockContainer.glowColor
            opacity: clockMouseArea.containsMouse ? 1.0 : 0.6
            scale: clockMouseArea.containsMouse ? 1.3 : 1.0
            
            Behavior on opacity {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
            }
        }
        
        MouseArea {
            id: clockMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.modeManager) {
                    root.modeManager.switchMode("calendar")
                }
            }
            onContainsMouseChanged: {
                if (containsMouse) {
                    clockContainer.glowColor = clockContainer.generateRandomGlowColor()
                }
            }
        }
    }
    
    Separator {}

    Common.IconButton {
        modeManager: root.modeManager
        iconSource: root.icons ? (root.icons.iconData.wallpaper.type === "svg" ? root.icons.iconData.wallpaper.value : "") : ""
        iconText: root.icons ? (root.icons.iconData.wallpaper.type === "text" ? root.icons.iconData.wallpaper.value : "") : ""
        iconColor: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        fontSize: root.typo ? root.typo.clockStyle.size : 14
        fontFamily: root.typo ? root.typo.clockStyle.family : "M PLUS 2"
        fontWeight: root.typo ? root.typo.clockStyle.weight : Font.Normal
        letterSpacing: root.typo ? root.typo.clockStyle.letterSpacing : 0
        
        onClicked: {
            if (root.modeManager) {
                root.modeManager.switchMode("wallpaper")
            }
        }
    }
    
    UI.ScreenshotButton {
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: scaled(4)
        theme: root.theme
        icons: root.icons
        modeManager: root.modeManager
        screenshotManager: root.screenshotManager
    }
    
    Separator {}

    Item {
        id: volumeContainer
        implicitWidth: scaled(24)
        implicitHeight: scaled(24)
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: 0
        Layout.rightMargin: 0
        
        function generateRandomColor() {
            let hue = (Date.now() % 360) + Math.random() * 360
            if (hue > 360) hue = hue % 360
            let saturation = 0.3 + Math.random() * 0.4
            let value = 0.8 + Math.random() * 0.2
            return Qt.hsva(hue / 360, saturation, value, 0.3)
        }
        
        property color blobColor: generateRandomColor()
        
        Common.BlobEffect {
            anchors.fill: parent
            anchors.leftMargin: scaled(-20)
            anchors.rightMargin: scaled(-20)
            anchors.topMargin: scaled(-14)
            anchors.bottomMargin: scaled(-14)
            blobColor: volumeContainer.blobColor
            layers: 3
            waveAmplitude: 2.0
            baseOpacity: 0.4
            animationSpeed: 0.08
            pointCount: 12
            z: -1
            opacity: volumeMouseArea.containsMouse ? 1.0 : 0.0
            visible: opacity > 0.01
            running: volumeMouseArea.containsMouse
            
            Behavior on opacity {
                NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
            }
        }
        
        Text {
            id: volumeTextMeasure
            visible: false
            text: "100%"
            font.family: root.typo ? root.typo.clockStyle.family : "M PLUS 2"
            font.pixelSize: root.typo ? root.typo.clockStyle.size : 14
            font.weight: root.typo ? root.typo.clockStyle.weight : Font.Normal
            font.letterSpacing: root.typo ? root.typo.clockStyle.letterSpacing : 0
        }
        
        readonly property real volumePercentTextWidth: Math.ceil(volumeTextMeasure.implicitWidth * 1.05)
        
        state: volumeMouseArea.containsMouse ? "hovered" : "normal"
        
        states: [
            State {
                name: "normal"
                PropertyChanges { target: volumeIconSvg; opacity: 0.6; scale: 1.0 }
                PropertyChanges { target: volumeIcon; opacity: 0.6; scale: 1.0 }
                PropertyChanges { target: volumePercentText; opacity: 0; scale: 1.0 }
            },
            State {
                name: "hovered"
                PropertyChanges { target: volumeIconSvg; opacity: 0; scale: 0.8 }
                PropertyChanges { target: volumeIcon; opacity: 0; scale: 0.8 }
                PropertyChanges { target: volumePercentText; opacity: 1.0; scale: 1.3 }
            }
        ]
        
        transitions: [
            Transition {
                from: "normal"; to: "hovered"
                PropertyAnimation {
                    target: volumeIconSvg
                    properties: "opacity,scale"
                    duration: 300
                    easing.type: Easing.OutCubic
                }
                PropertyAnimation {
                    target: volumeIcon
                    properties: "opacity,scale"
                    duration: 300
                    easing.type: Easing.OutCubic
                }
                SequentialAnimation {
                    PauseAnimation { duration: 150 }
                    ParallelAnimation {
                        PropertyAnimation {
                            target: volumePercentText
                            property: "opacity"
                            duration: 400
                            easing.type: Easing.OutCubic
                        }
                        PropertyAnimation {
                            target: volumePercentText
                            property: "scale"
                            duration: 600
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            },
            Transition {
                from: "hovered"; to: "normal"
                PropertyAnimation {
                    targets: [volumeIconSvg, volumeIcon, volumePercentText]
                    properties: "opacity,scale"
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        ]
        
        property string currentIconSource: ""
        property string currentIconText: ""
        property bool currentIconIsSvg: true
        property bool isInitialized: false
        
        function updateIcon(animate) {
            if (!root.icons || !root.audioManager) return
            
            let iconData = root.icons.getVolumeIcon(
                root.audioManager.volume, 
                root.audioManager.isMuted,
                root.audioManager.isHeadphone
            )
            
            let newSource = iconData.type === "svg" ? iconData.value : ""
            let newText = iconData.type === "text" ? iconData.value : ""
            let newIsSvg = iconData.type === "svg"
            
            if (newSource !== currentIconSource || newText !== currentIconText || newIsSvg !== currentIconIsSvg) {
                if (animate && isInitialized) {
                    iconChangeAnimation.start()
                } else {
                    currentIconSource = newSource
                    currentIconText = newText
                    currentIconIsSvg = newIsSvg
                    volumeIconSvg.opacity = volumeContainer.state === "hovered" ? 0 : 0.6
                    volumeIcon.opacity = volumeContainer.state === "hovered" ? 0 : 0.6
                }
            }
        }
        
        SequentialAnimation {
            id: iconChangeAnimation
            running: false

            ParallelAnimation {
                NumberAnimation {
                    target: volumeIconSvg
                    property: "opacity"
                    from: volumeIconSvg.opacity
                    to: 0
                    duration: 200
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: volumeIcon
                    property: "opacity"
                    from: volumeIcon.opacity
                    to: 0
                    duration: 200
                    easing.type: Easing.InOutQuad
                }
            }
            
            PropertyAction {
                target: volumeContainer
                property: "currentIconSource"
                value: {
                    if (!root.icons || !root.audioManager) return ""
                    let iconData = root.icons.getVolumeIcon(
                        root.audioManager.volume, 
                        root.audioManager.isMuted,
                        root.audioManager.isHeadphone
                    )
                    return iconData.type === "svg" ? iconData.value : ""
                }
            }
            PropertyAction {
                target: volumeContainer
                property: "currentIconText"
                value: {
                    if (!root.icons || !root.audioManager) return ""
                    let iconData = root.icons.getVolumeIcon(
                        root.audioManager.volume, 
                        root.audioManager.isMuted,
                        root.audioManager.isHeadphone
                    )
                    return iconData.type === "text" ? iconData.value : ""
                }
            }
            PropertyAction {
                target: volumeContainer
                property: "currentIconIsSvg"
                value: {
                    if (!root.icons || !root.audioManager) return true
                    let iconData = root.icons.getVolumeIcon(
                        root.audioManager.volume, 
                        root.audioManager.isMuted,
                        root.audioManager.isHeadphone
                    )
                    return iconData.type === "svg"
                }
            }
            
            ParallelAnimation {
                NumberAnimation {
                    target: volumeIconSvg
                    property: "opacity"
                    from: 0
                    to: volumeContainer.state === "hovered" ? 0 : 0.6
                    duration: 200
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: volumeIcon
                    property: "opacity"
                    from: 0
                    to: volumeContainer.state === "hovered" ? 0 : 0.6
                    duration: 200
                    easing.type: Easing.InOutQuad
                }
            }
        }
        
        Component.onCompleted: {
            if (root.audioManager && root.audioManager.headphoneReady) {
                updateIcon(false)
            }
            isInitialized = true
        }

        Connections {
            target: root.audioManager
            function onVolumeChanged() { volumeContainer.updateIcon(true) }
            function onIsMutedChanged() { volumeContainer.updateIcon(true) }
            function onIsHeadphoneChanged() { volumeContainer.updateIcon(true) }
            function onHeadphoneReadyChanged() { volumeContainer.updateIcon(false) }
        }
        
        UI.SvgIcon {
            id: volumeIconSvg
            anchors.centerIn: parent
            width: scaled(24)
            height: scaled(24)
            source: volumeContainer.currentIconSource
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            visible: volumeContainer.currentIconIsSvg && volumeContainer.currentIconSource !== ""
        }
        
        Text {
            id: volumeIcon
            anchors.centerIn: parent
            text: volumeContainer.currentIconText
            font.family: root.typo ? root.typo.clockStyle.family : "M PLUS 2"
            font.pixelSize: scaled(root.typo ? root.typo.clockStyle.size : 14)
            font.weight: root.typo ? root.typo.clockStyle.weight : Font.Normal
            font.letterSpacing: root.typo ? root.typo.clockStyle.letterSpacing : 0
            font.hintingPreference: root.typo ? root.typo.clockStyle.hinting : Font.PreferDefaultHinting
            font.kerning: root.typo ? root.typo.clockStyle.kerning : true
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            visible: !volumeContainer.currentIconIsSvg && volumeContainer.currentIconText !== ""
        }
        
        Text {
            id: volumePercentText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: scaled(-1)
            text: root.audioManager ? (root.audioManager.isMuted ? "—" : root.audioManager.volume.toString()) : "0"
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            font.family: root.typo ? root.typo.clockStyle.family : "M PLUS 2"
            font.pixelSize: scaled(root.typo ? root.typo.clockStyle.size : 14)
            font.weight: root.typo ? root.typo.clockStyle.weight : Font.Normal
            font.letterSpacing: root.typo ? root.typo.clockStyle.letterSpacing : 0
            font.hintingPreference: root.typo ? root.typo.clockStyle.hinting : Font.PreferDefaultHinting
            font.kerning: root.typo ? root.typo.clockStyle.kerning : true
            
            Behavior on color {
                ColorAnimation { duration: 400; easing.type: Easing.OutCubic }
            }
        }
        
        MouseArea {
            id: volumeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.modeManager) {
                    root.modeManager.switchMode("volume")
                }
            }
            onContainsMouseChanged: {
                if (containsMouse) {
                    volumeContainer.blobColor = volumeContainer.generateRandomColor()
                }
            }
        }
    }
    
    Item {
        id: musicButtonWrapper
        implicitWidth: isPlaying ? scaled(33) : scaled(24)
        implicitHeight: scaled(24)
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: scaled(4)
        
        property bool isPlaying: root.musicPlayerManager ? root.musicPlayerManager.isPlaying : false
        property color baseColor: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        property color accentColor: root.musicPlayerManager && root.musicPlayerManager.accentColor
            ? root.musicPlayerManager.accentColor
            : (root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
        property real colorPhase: 0
        
        property color currentIconColor: blendColors(baseColor, accentColor, isPlaying ? colorPhase : 0)
        
        readonly property real visualizerWidth: scaled(6 * 3 + 5 * 3)
        
        function getCurrentIconColor() {
            return currentIconColor
        }
        
        onIsPlayingChanged: {
            if (!isPlaying) {
                colorPhase = 0
            }
        }
        
        Behavior on implicitWidth {
            NumberAnimation { 
                duration: 420; 
                easing.type: Easing.OutCubic 
            }
        }
        
        Item {
            id: iconPanel
            anchors.fill: parent
            opacity: (!musicButtonWrapper.isPlaying || visualizerHoverHandler.hovered) ? 1.0 : 0.0
            
            Behavior on opacity {
                NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
            }
            
            Common.IconButton {
                id: musicButton
                anchors.centerIn: parent
                modeManager: root.modeManager
                iconSource: root.icons ? (root.icons.iconData.music.type === "svg" ? root.icons.iconData.music.value : "") : ""
                iconText: root.icons ? (root.icons.iconData.music.type === "text" ? root.icons.iconData.music.value : "") : ""
                iconColor: musicButtonWrapper.currentIconColor
                fontSize: root.typo ? root.typo.clockStyle.size : 14
                fontFamily: root.typo ? root.typo.clockStyle.family : "M PLUS 2"
                fontWeight: root.typo ? root.typo.clockStyle.weight : Font.Normal
                letterSpacing: root.typo ? root.typo.clockStyle.letterSpacing : 0
                
                Behavior on iconColor {
                    ColorAnimation { duration: 600; easing.type: Easing.InOutCubic }
                }
                
                onClicked: {
                    if (root.modeManager) {
                        root.modeManager.switchMode("music")
                    }
                }
            }
        }
        
        Common.BarVisualizer {
            id: barVisualizer
            anchors.centerIn: parent
            cavaManager: root.cavaManager
            barWidth: scaled(3)
            barSpacing: scaled(3)
            minBarHeight: scaled(6)
            maxBarHeight: scaled(28)
            barColor: musicButtonWrapper.accentColor
            baseColor: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.85)
            opacity: musicButtonWrapper.isPlaying
                ? (visualizerHoverHandler.hovered ? 0.0 : 0.6)
                : 0.0
            
            Behavior on opacity {
                NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
            }
            
            Behavior on barColor {
                ColorAnimation { duration: 600; easing.type: Easing.InOutCubic }
            }
        }
        
        SequentialAnimation on colorPhase {
            loops: Animation.Infinite
            running: musicButtonWrapper.isPlaying
            NumberAnimation {
                from: 0
                to: 1
                duration: 1600
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: 1
                to: 0
                duration: 1600
                easing.type: Easing.InOutSine
            }
        }
        
        HoverHandler {
            id: visualizerHoverHandler
            enabled: musicButtonWrapper.isPlaying
            cursorShape: Qt.PointingHandCursor
        }
        
        MouseArea {
            id: visualizerClickArea
            anchors.fill: parent
            hoverEnabled: false
            cursorShape: Qt.PointingHandCursor
            visible: musicButtonWrapper.isPlaying
            enabled: musicButtonWrapper.isPlaying
            onClicked: {
                if (root.modeManager) {
                    root.modeManager.switchMode("music")
                }
            }
            z: 1
        }
    }
    
}

