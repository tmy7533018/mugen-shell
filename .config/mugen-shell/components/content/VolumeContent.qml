import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../common" as Common

Item {
    id: root

    required property var modeManager
    required property var audioManager
    property var cavaManager
    property var micCavaManager
    property var musicPlayerManager
    required property var theme
    required property var typo

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(370),
        "leftMargin": modeManager.scale(765),
        "rightMargin": modeManager.scale(765),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })

    // 0 = speaker, 1 = mic
    property int tabIndex: 0
    readonly property bool isMicMode: tabIndex === 1

    property real audioLevel: isMicMode
        ? (micCavaManager ? micCavaManager.audioLevel : 0.0)
        : (cavaManager ? cavaManager.audioLevel : 0.0)
    readonly property int currentVolume: isMicMode ? audioManager.micVolume : audioManager.volume
    readonly property bool currentMuted: isMicMode ? audioManager.micMuted : audioManager.isMuted
    readonly property string currentLabel: isMicMode ? "mic" : "speaker"

    function setCurrentVolume(v) {
        if (isMicMode) audioManager.setMicVolume(v)
        else audioManager.setVolume(v)
    }

    function toggleCurrentMute() {
        if (isMicMode) audioManager.toggleMicMute()
        else audioManager.toggleMute()
    }

    // mic = same hue-shift as active idle inhibitor
    function micShift(c) {
        return Qt.hsva((c.hsvHue + 0.2) % 1.0, c.hsvSaturation, Math.min(1.0, c.hsvValue + 0.25), c.a)
    }

    // fast close after hw volume change; panel is transient
    Timer {
        id: volumeChangeTimer
        interval: 2000
        running: false
        repeat: false
        onTriggered: {
            if (modeManager.isMode("volume")) modeManager.closeAllModes()
        }
    }

    function resetAutoCloseTimer() {
        if (modeManager.isMode("volume")) {
            modeManager.bump()
            volumeChangeTimer.stop()
        }
    }

    function startVolumeChangeTimer() {
        if (modeManager.isMode("volume")) {
            volumeChangeTimer.restart()
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (!modeManager.isMode("volume")) {
                volumeChangeTimer.stop()
                if (contentLayer) contentLayer.deviceDropdownVisible = false
                if (micCavaManager) micCavaManager.stop()
            } else {
                root.updateMicCavaState()
            }
        }
    }

    // mic cava only runs while volume panel open + mic tab
    function updateMicCavaState() {
        if (!micCavaManager) return
        if (modeManager.isMode("volume") && root.isMicMode) {
            micCavaManager.start()
        } else {
            micCavaManager.stop()
        }
    }

    onIsMicModeChanged: updateMicCavaState()

    MouseArea {
        anchors.fill: parent
        z: 1
        enabled: modeManager.isMode("volume")
        visible: enabled
        hoverEnabled: true

        onClicked: {
            modeManager.closeAllModes()
        }

        onPositionChanged: {
            if (modeManager.isMode("volume")) {
                root.resetAutoCloseTimer()
            }
        }

        onPressed: (mouse) => {
            let blobX = (width - contentLayer.blobSize) / 2
            let blobY = (height - contentLayer.blobSize) / 2
            let blobW = contentLayer.blobSize
            let blobH = contentLayer.blobSize

            if (mouse.x >= blobX && mouse.x <= blobX + blobW &&
                mouse.y >= blobY && mouse.y <= blobY + blobH) {
                mouse.accepted = false
            } else {
                modeManager.closeAllModes()
            }
        }
    }

    Item {
        id: contentLayer
        anchors.fill: parent
        z: 2

        focus: modeManager.isMode("volume")
        Keys.onPressed: (event) => {
            if (modeManager.isMode("volume")) {
                root.resetAutoCloseTimer()
            }
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
            }
        }

        opacity: 0
        visible: opacity > 0.01

        states: [
            State {
                name: "visible"
                when: modeManager.isMode("volume")
                PropertyChanges { target: contentLayer; opacity: 1.0 }
            }
        ]

        transitions: [
            Transition {
                from: "visible"
                to: ""
                NumberAnimation {
                    property: "opacity"
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: 300 }
                    NumberAnimation {
                        property: "opacity"
                        duration: 400
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        ]

        // 0% → 75px, 100% → 235px
        property real blobSize: (root.currentMuted || root.currentVolume === 0)
            ? modeManager.scale(75)
            : modeManager.scale(75 + Math.min(100, root.currentVolume) * 1.60)

        Behavior on blobSize {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }

        property color _cachedBlobColor: theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
        property real _lastAudioLevel: -1
        property bool _lastMuted: false
        property real _lastVolume: -1

        function calculateBlobColor() {
            if (!theme) {
                return Qt.rgba(0.65, 0.55, 0.85, 0.8)
            }
            if (root.currentMuted || root.currentVolume <= 0) {
                return theme.textFaint
            }
            let effectiveAudioLevel = Math.max(0.1, root.audioLevel)
            let rawMix = 1.0 - Math.pow(effectiveAudioLevel, 1.5)
            let lightMix = Math.min(0.4, Math.max(0.0, rawMix))
            let accent = root.isMicMode ? root.micShift(theme.accent) : theme.accent
            let lightColor = root.isMicMode ? root.micShift(theme.glowPrimary) : theme.glowPrimary
            return Qt.rgba(
                accent.r * (1.0 - lightMix) + lightColor.r * lightMix,
                accent.g * (1.0 - lightMix) + lightColor.g * lightMix,
                accent.b * (1.0 - lightMix) + lightColor.b * lightMix,
                1.0
            )
        }

        function updateBlobColor(forceUpdate) {
            if (forceUpdate ||
                Math.abs(root.audioLevel - _lastAudioLevel) > 0.01 ||
                root.currentMuted !== _lastMuted ||
                Math.abs(root.currentVolume - _lastVolume) > 0.1) {
                _cachedBlobColor = calculateBlobColor()
                _lastAudioLevel = root.audioLevel
                _lastMuted = root.currentMuted
                _lastVolume = root.currentVolume
            }
        }

        Connections {
            target: root
            function onAudioLevelChanged() {
                contentLayer.updateBlobColor()
            }
            function onCurrentMutedChanged() {
                contentLayer.updateBlobColor()
            }
            function onCurrentVolumeChanged() {
                contentLayer.updateBlobColor()
            }
            function onIsMicModeChanged() {
                contentLayer.updateBlobColor(true)
            }
        }

        Connections {
            target: theme
            enabled: theme !== null
            function onAccentChanged() {
                if (theme) {
                    contentLayer.updateBlobColor(true)
                }
            }
            function onGlowPrimaryChanged() {
                if (theme) {
                    contentLayer.updateBlobColor(true)
                }
            }
            function onTextFaintChanged() {
                if (theme) {
                    contentLayer.updateBlobColor(true)
                }
            }
        }

        Component.onCompleted: {
            _lastAudioLevel = root.audioLevel
            _lastMuted = root.currentMuted
            _lastVolume = root.currentVolume
            _cachedBlobColor = calculateBlobColor()
        }

        property color blobColor: _cachedBlobColor

        Behavior on blobColor {
            ColorAnimation {
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }

        property bool isInteracting: false
        property bool isHovering: false

        Timer {
            id: interactionTimer
            interval: 800
            running: false
            repeat: false
            onTriggered: {
                if (!contentLayer.isHovering) {
                    contentLayer.isInteracting = false
                }
            }
        }

        function startInteraction() {
            contentLayer.isInteracting = true
            if (!contentLayer.isHovering) {
                interactionTimer.restart()
            }
        }

        Connections {
            target: audioManager
            function onVolumeChanged() {
                if (root.isMicMode) return
                if (audioManager.isMuted) audioManager.toggleMute()
                contentLayer.startInteraction()
                root.startVolumeChangeTimer()
            }
            function onMicVolumeChanged() {
                if (!root.isMicMode) return
                if (audioManager.micMuted) audioManager.toggleMicMute()
                contentLayer.startInteraction()
                root.startVolumeChangeTimer()
            }
            function onIsMutedChanged() {
                if (root.isMicMode) return
                contentLayer.startInteraction()
                root.startVolumeChangeTimer()
            }
            function onMicMutedChanged() {
                if (!root.isMicMode) return
                contentLayer.startInteraction()
                root.startVolumeChangeTimer()
            }
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: modeManager.scale(16)
            z: 5
            width: Math.max(muteIcon.width, volumePercentText.implicitWidth)
            height: Math.max(muteIcon.height, volumePercentText.implicitHeight)

            opacity: (contentLayer.isInteracting || contentLayer.isHovering) ? 1.0 : 0.6
            visible: true

            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.InOutQuad
                }
            }

            Common.GlowSvgIcon {
                id: muteIcon
                anchors.centerIn: parent
                width: modeManager.scale(18)
                height: modeManager.scale(18)
                source: Quickshell.shellDir + "/assets/icons/volume-mute.svg"
                color: Qt.rgba(0.95, 0.93, 0.98, 0.95)
                visible: root.currentMuted && parent.opacity > 0.01
                opacity: root.currentMuted ? 1.0 : 0.0

                enableGlow: true
                glowColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6)
                glowSamples: 20
                glowRadius: modeManager.scale(12)
                glowSpread: 0.5

                Behavior on opacity {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Common.GlowText {
                id: volumePercentText
                anchors.centerIn: parent
                text: root.currentVolume + "%"
                color: Qt.rgba(0.95, 0.93, 0.98, 0.95)
                font.family: typo.fontFamily
                font.pixelSize: modeManager.scale(16)
                font.weight: typo.weightLight
                font.letterSpacing: 1.5
                visible: !root.currentMuted
                enableGlow: true
                glowColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6)
                glowSamples: 20
                glowRadius: modeManager.scale(12)
                glowSpread: 0.5
            }
        }

        Item {
            id: volumeBlob
            anchors.centerIn: parent
            width: contentLayer.blobSize
            height: contentLayer.blobSize
            z: 1

            property real pulseScale: 1.0

            SequentialAnimation on pulseScale {
                loops: Animation.Infinite
                running: modeManager.isMode("volume") && !contentLayer.isInteracting

                NumberAnimation {
                    to: 1.15
                    duration: 1400
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1.0
                    duration: 1400
                    easing.type: Easing.InOutSine
                }
            }

            property real targetScale: 1.0 + (root.audioLevel * 0.5)
            property real cavaScale: 1.0

            onTargetScaleChanged: {
                cavaScale = targetScale
            }

            Behavior on cavaScale {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutCubic
                }
            }

            transform: Scale {
                origin.x: volumeBlob.width / 2
                origin.y: volumeBlob.height / 2
                xScale: volumeBlob.pulseScale * volumeBlob.cavaScale
                yScale: volumeBlob.pulseScale * volumeBlob.cavaScale
            }

            Common.BlobEffect {
                anchors.fill: parent
                blobColor: contentLayer.blobColor
                layers: 3
                waveAmplitude: 4.0
                baseOpacity: 0.6
                animationSpeed: 0.05
                pointCount: 16
                running: modeManager.isMode("volume")
            }

            MouseArea {
                id: volumeMouseArea
                anchors.fill: parent
                z: 10
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor

                property real startY: 0
                property int startVolume: 0
                property bool isDragging: false
                property bool wasDragging: false

                onEntered: {
                    contentLayer.isHovering = true
                    contentLayer.startInteraction()
                }

                onExited: {
                    contentLayer.isHovering = false
                    interactionTimer.stop()
                    if (!contentLayer.isInteracting) {
                        contentLayer.isInteracting = false
                    } else {
                        interactionTimer.restart()
                    }
                }

                onClicked: {
                    if (!wasDragging && !isDragging) {
                        root.toggleCurrentMute()
                        contentLayer.startInteraction()
                        root.resetAutoCloseTimer()
                    }
                    // reset after onClicked finishes
                    Qt.callLater(() => {
                        isDragging = false
                        wasDragging = false
                    })
                }

                onPressed: (mouse) => {
                    startY = mouse.y
                    startVolume = root.currentVolume
                    isDragging = false
                    wasDragging = false
                    contentLayer.startInteraction()
                    root.resetAutoCloseTimer()
                }

                onPositionChanged: (mouse) => {
                    if (pressed) {
                        let deltaY = Math.abs(startY - mouse.y)
                        if (deltaY > 5) {
                            isDragging = true
                            wasDragging = true
                        }

                        if (isDragging) {
                            let volumeChange = Math.round((startY - mouse.y) * 0.5)
                            let newVolume = Math.max(0, Math.min(100, startVolume + volumeChange))
                            root.setCurrentVolume(newVolume)
                            contentLayer.startInteraction()
                            root.startVolumeChangeTimer()
                        }
                    }
                }

                onReleased: {
                }

                onWheel: (wheel) => {
                    let delta = wheel.angleDelta.y > 0 ? 2 : -2
                    let newVolume = Math.max(0, Math.min(100, root.currentVolume + delta))
                    root.setCurrentVolume(newVolume)
                    contentLayer.startInteraction()
                    root.startVolumeChangeTimer()
                }
            }
        }

        property bool deviceDropdownVisible: false

        Item {
            id: titleContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: modeManager.scale(16)
            z: 5
            width: volumeLabel.implicitWidth
            height: volumeLabel.implicitHeight

            Common.GlowText {
                id: volumeLabel
                anchors.centerIn: parent

                text: root.currentLabel
                color: Qt.rgba(0.95, 0.93, 0.98, 0.95)
                font.family: typo.fontFamily
                font.pixelSize: modeManager.scale(20)
                font.weight: typo.weightLight
                font.letterSpacing: 1.5
                opacity: volumeLabelMouseArea.containsMouse ? 1.0 : 0.95
                scale: volumeLabelMouseArea.containsMouse ? 1.15 : 1.0
                transformOrigin: Item.Center

                enableGlow: true
                glowColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6)
                glowSamples: 20
                glowRadius: modeManager.scale(12)
                glowSpread: 0.5

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }

            Common.GlowSvgIcon {
                id: swapIcon
                width: modeManager.scale(16)
                height: modeManager.scale(16)
                anchors.right: volumeLabel.left
                anchors.rightMargin: modeManager.scale(18)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: modeManager.scale(2)
                source: Quickshell.shellDir + "/assets/icons/arrows-right-left.svg"
                color: Qt.rgba(0.95, 0.93, 0.98, swapMouseArea.containsMouse ? 1.0 : 0.5)
                opacity: swapMouseArea.containsMouse ? 1.0 : 0.4

                enableGlow: opacity > 0.5
                glowColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5)
                glowSamples: 16
                glowRadius: modeManager.scale(8)
                glowSpread: 0.4

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                MouseArea {
                    id: swapMouseArea
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        root.tabIndex = root.tabIndex === 0 ? 1 : 0
                        root.resetAutoCloseTimer()
                    }
                }
            }

            MouseArea {
                id: volumeLabelMouseArea
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    // Hyprland.dispatch survives panel unload (Process child wouldn't)
                    Hyprland.dispatch("exec pavucontrol")
                    modeManager.closeAllModes()
                }
            }

            Common.GlowSvgIcon {
                id: dropdownIcon
                width: modeManager.scale(16)
                height: modeManager.scale(16)
                anchors.left: volumeLabel.right
                anchors.leftMargin: modeManager.scale(18)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: modeManager.scale(2)
                source: Quickshell.shellDir + "/assets/icons/chevron-down.svg"
                color: Qt.rgba(0.95, 0.93, 0.98, dropdownMouseArea.containsMouse ? 1.0 : 0.5)
                rotation: contentLayer.deviceDropdownVisible ? 180 : 0

                opacity: dropdownMouseArea.containsMouse || contentLayer.deviceDropdownVisible ? 1.0 : 0.4

                enableGlow: opacity > 0.5
                glowColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5)
                glowSamples: 16
                glowRadius: modeManager.scale(8)
                glowSpread: 0.4

                Behavior on rotation {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    id: dropdownMouseArea
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        contentLayer.deviceDropdownVisible = !contentLayer.deviceDropdownVisible
                        root.resetAutoCloseTimer()
                    }
                }
            }
        }

        Rectangle {
            id: deviceDropdown
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: titleContainer.bottom
            anchors.topMargin: modeManager.scale(12)
            z: 100

            width: modeManager.scale(280)
            property real maxHeight: modeManager.scale(250)
            height: Math.min(dropdownFlickable.contentHeight + modeManager.scale(16), maxHeight)

            color: theme ? theme.surfaceInsetCardHover : Qt.rgba(0.08, 0.08, 0.12, 0.75)
            radius: modeManager.scale(12)
            border.width: 1
            border.color: theme ? theme.surfaceBorder : Qt.rgba(0.3, 0.3, 0.4, 0.3)

            visible: contentLayer.deviceDropdownVisible
            opacity: contentLayer.deviceDropdownVisible ? 1.0 : 0.0
            scale: contentLayer.deviceDropdownVisible ? 1.0 : 0.95
            transformOrigin: Item.Top

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Flickable {
                id: dropdownFlickable
                anchors.fill: parent
                anchors.margins: modeManager.scale(8)
                contentWidth: width
                contentHeight: dropdownContent.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    propagateComposedEvents: false

                    onClicked: (mouse) => { mouse.accepted = true }
                    onPressed: (mouse) => { mouse.accepted = true }
                    onReleased: (mouse) => { mouse.accepted = true }
                    onPositionChanged: root.resetAutoCloseTimer()

                    onWheel: (wheel) => {
                        let delta = wheel.angleDelta.y / 3
                        dropdownFlickable.contentY = Math.max(0,
                            Math.min(dropdownFlickable.contentHeight - dropdownFlickable.height,
                                dropdownFlickable.contentY - delta))
                        wheel.accepted = true
                    }
                }

                Column {
                    id: dropdownContent
                    width: dropdownFlickable.width
                    spacing: modeManager.scale(8)

                    Common.GlowText {
                        visible: !root.isMicMode
                        text: "出力"
                        color: Qt.rgba(0.7, 0.7, 0.8, 0.8)
                        font.pixelSize: modeManager.scale(12)
                        font.weight: Font.Medium
                        font.letterSpacing: 1
                        enableGlow: false
                    }

                    Column {
                        visible: !root.isMicMode
                        width: parent.width
                        spacing: modeManager.scale(4)

                        Repeater {
                            model: audioManager.sinks

                            Rectangle {
                                width: parent.width
                                height: sinkText.implicitHeight + modeManager.scale(12)
                                color: modelData.isDefault
                                    ? Qt.rgba(theme ? theme.accent.r : 0.5, theme ? theme.accent.g : 0.4, theme ? theme.accent.b : 0.7, 0.25)
                                    : (sinkMouseArea.containsMouse ? Qt.rgba(0.3, 0.3, 0.4, 0.3) : "transparent")
                                radius: modeManager.scale(6)

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Text {
                                    id: sinkText
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: modeManager.scale(8)
                                    text: modelData.description
                                    color: modelData.isDefault ? Qt.rgba(0.95, 0.93, 0.98, 1.0) : Qt.rgba(0.85, 0.85, 0.9, 0.9)
                                    font.pixelSize: modeManager.scale(13)
                                    font.family: typo.fontFamily
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: sinkMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        audioManager.setDefaultSink(modelData.name)
                                        root.resetAutoCloseTimer()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: false
                        width: parent.width
                        height: 1
                        color: Qt.rgba(0.4, 0.4, 0.5, 0.3)
                    }

                    Common.GlowText {
                        visible: root.isMicMode
                        text: "入力"
                        color: Qt.rgba(0.7, 0.7, 0.8, 0.8)
                        font.pixelSize: modeManager.scale(12)
                        font.weight: Font.Medium
                        font.letterSpacing: 1
                        enableGlow: false
                    }

                    Column {
                        visible: root.isMicMode
                        width: parent.width
                        spacing: modeManager.scale(4)

                        Repeater {
                            model: audioManager.sources

                            Rectangle {
                                width: parent.width
                                height: sourceText.implicitHeight + modeManager.scale(12)
                                color: modelData.isDefault
                                    ? Qt.rgba(theme ? theme.accent.r : 0.5, theme ? theme.accent.g : 0.4, theme ? theme.accent.b : 0.7, 0.25)
                                    : (sourceMouseArea.containsMouse ? Qt.rgba(0.3, 0.3, 0.4, 0.3) : "transparent")
                                radius: modeManager.scale(6)

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                Text {
                                    id: sourceText
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: modeManager.scale(8)
                                    text: modelData.description
                                    color: modelData.isDefault ? Qt.rgba(0.95, 0.93, 0.98, 1.0) : Qt.rgba(0.85, 0.85, 0.9, 0.9)
                                    font.pixelSize: modeManager.scale(13)
                                    font.family: typo.fontFamily
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: sourceMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        audioManager.setDefaultSource(modelData.name)
                                        root.resetAutoCloseTimer()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: scrollbar
                anchors.right: parent.right
                anchors.rightMargin: modeManager.scale(3)
                anchors.top: parent.top
                anchors.topMargin: modeManager.scale(8) + (dropdownFlickable.height - scrollbar.height) * (dropdownFlickable.contentY / (dropdownFlickable.contentHeight - dropdownFlickable.height))

                width: modeManager.scale(3)
                height: Math.max(modeManager.scale(20), dropdownFlickable.height * (dropdownFlickable.height / dropdownFlickable.contentHeight))
                radius: modeManager.scale(1.5)

                color: Qt.rgba(0.6, 0.6, 0.7, 0.5)

                visible: dropdownFlickable.contentHeight > dropdownFlickable.height
                opacity: dropdownFlickable.moving ? 0.8 : 0.4

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
            }
        }
    }

    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("volume", root)
        }
        updateMicCavaState()
    }
}
