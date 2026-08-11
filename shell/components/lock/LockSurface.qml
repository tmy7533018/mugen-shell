pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import "../../lib" as Theme
import "../ui" as UI
import "../common" as Common
import "../content" as Content
import "../content/ai" as Ai

Item {
    id: root

    property var typo
    readonly property string faceFontFamily: typo ? typo.fontFamily : "M PLUS 2"
    property var themeRef

    property string screenName: ""
    property bool uiVisible: false
    property bool entryStarted: false
    property bool entryMorph: false
    property string entryScreen: ""
    property int morphDuration: 900

    property real sourceX: 0
    property real sourceY: 0
    property real sourceWidth: 0
    property real sourceHeight: 0
    property real sourceRadius: 0
    property real sourceOpacity: 0.85

    property real exitX: 0
    property real exitY: 0
    property real exitWidth: 0
    property real exitHeight: 0
    property real exitRadius: 0

    property int marginBase: 6
    property int radiusBase: 50
    // Opaque: the desktop shows only through the margin around the face.
    property real faceOpacity: 1.0
    property real dimStrength: 0.60

    property string timeText: ""
    property date today: new Date()

    property int calendarWeekStart: 0
    property var calendarEvents: []

    property string iconsBase: ""
    property string texturesBase: ""
    property var cavaManager

    property var weatherPalette: null

    property string weatherIconSource: ""
    property string weatherText: ""
    property string weatherHighLow: ""
    property string weatherCondition: ""
    property string weatherParticleType: "clouds"
    property real weatherWind: 0

    property bool mediaIsPlaying: false
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaArtUrl: ""
    property real mediaPosition: 0
    property real mediaDuration: 0
    property color mediaAccent: "#a68cd9"

    signal previousRequested
    signal playPauseRequested
    signal nextRequested
    signal powerActionRequested(int action)

    property int passwordLength: 0
    property string faultText: ""
    property bool authenticating: false
    property bool unlocking: false
    property int unlockGrace: 0
    property bool reduceMotion: false

    readonly property bool morphing:
        entryMorph && screenName !== "" && screenName === entryScreen

    // The bar scales its margins against a reference width but not its radius.
    readonly property real faceMargin: Theme.Metrics.scaleTo(marginBase, width)
    readonly property real faceX: faceMargin
    readonly property real faceY: faceMargin
    readonly property real faceW: width - faceMargin * 2
    readonly property real faceH: height - faceMargin * 2
    readonly property real faceRadius:
        Math.min(radiusBase, Math.min(faceW, faceH) / 2)

    property bool exiting: false

    readonly property real startX: exiting ? exitX : (morphing ? sourceX : faceX)
    readonly property real startY: exiting ? exitY : (morphing ? sourceY : faceY)
    readonly property real startW: exiting ? exitWidth : (morphing ? sourceWidth : faceW)
    readonly property real startH: exiting ? exitHeight : (morphing ? sourceHeight : faceH)
    readonly property real startRadius:
        exiting ? exitRadius : (morphing ? sourceRadius : faceRadius)
    readonly property real startOpacity: morphing ? sourceOpacity : faceOpacity

    property real morphProgress: 0
    // Floor, not 0: session_lock_xray paints the desktop before entryStarted's first tick.
    property real dimProgress: 0.5
    property real contentFade: 0
    property real groupFade: 0
    property real faceEnterScale: 1
    property real exitFade: 1

    readonly property real liveX: startX + (faceX - startX) * morphProgress
    readonly property real liveW: startW + (faceW - startW) * morphProgress
    readonly property real liveY: startY + (faceY - startY) * morphProgress
    readonly property real liveH: startH + (faceH - startH) * morphProgress
    readonly property real liveRadius:
        startRadius + (faceRadius - startRadius) * morphProgress

    readonly property real cx: liveX + (liveW - faceW) / 2
    readonly property real cy: liveY + (liveH - faceH) / 2

    // Pinned while leaving: the face collapses faster than the content fades.
    readonly property real contentX: exiting ? faceX : cx
    readonly property real contentY: exiting ? faceY : cy

    // Staggered starts, shared finish, so the sweep costs no extra time.
    readonly property real revealStagger: 0.26

    function columnReveal(col) {
        const start = col * revealStagger
        const span = 1 - revealStagger * (colUnits.length - 1)
        return Math.max(0, Math.min(1, (contentFade - start) / span))
    }

    // One square unit per row; the power column is exactly that square.
    readonly property var colUnits: [2, 2, 2, 1]
    readonly property int rowCount: 4

    readonly property real gridPadY: faceH * 0.172
    readonly property real gutterX: faceW * 0.007
    readonly property real gutterY: faceH * 0.012

    readonly property real gridH: faceH - gridPadY * 2 - gutterY * (rowCount - 1)
    readonly property real cellH: gridH / rowCount

    readonly property real gridW: {
        let units = 0
        for (const u of colUnits) units += u
        return cellH * units + gutterX * (colUnits.length - 1)
    }
    readonly property real gridPadX: (faceW - gridW) / 2

    readonly property real boxRadius: Math.round(faceH * 0.022)

    readonly property int levelsBarCount: 12
    readonly property real levelsBarWidth: Math.max(2, Math.min(
        cellH * 0.055,
        colSpan(1, 1) * 0.8 / (levelsBarCount + (levelsBarCount - 1) * 0.75)))

    function colLeft(c) {
        let x = gridPadX
        for (let i = 0; i < c; i++) x += colUnits[i] * cellH + gutterX
        return x
    }

    function colSpan(c, span) {
        let units = 0
        for (let i = c; i < c + span; i++) units += colUnits[i]
        return units * cellH + gutterX * (span - 1)
    }

    function rowTop(r) {
        return gridPadY + r * (cellH + gutterY)
    }

    function rowSpan(span) {
        return cellH * span + gutterY * (span - 1)
    }


    readonly property color clockColor:
        themeRef ? themeRef.textPrimary : "#f2f3ff"
    readonly property color subtleColor:
        themeRef ? themeRef.textSecondary : Qt.rgba(235 / 255, 238 / 255, 1, 0.55)
    readonly property color errorColor: "#ff9db0"
    // The wallpaper's colour, the same one the volume module blooms with.
    readonly property color orbBase:
        themeRef ? themeRef.glowPrimary : "#a68cd9"
    readonly property color accentColor:
        themeRef ? themeRef.accent : "#a68cd9"
    readonly property color glowSecondaryColor:
        themeRef ? themeRef.glowSecondary : "#a68cd9"
    readonly property color glowTertiaryColor:
        themeRef ? themeRef.glowTertiary : "#a68cd9"


    readonly property real orbBoxW: colSpan(1, 1)
    readonly property real orbBoxH: rowSpan(2)
    readonly property real orbSize: Math.round(Math.min(orbBoxW, orbBoxH) * 0.55)
    readonly property real orbCX: contentX + colLeft(1) + orbBoxW / 2
    readonly property real orbCY: contentY + rowTop(0) + orbBoxH * 0.5
    readonly property int chargeLength: Math.min(passwordLength, 14)

    // Outside the glow, which grows with charge and wobble to about 1.07x.
    readonly property real moteInner:
        orbSize * 0.53 * orbSlot.chargeScale * 1.16 + orbSize * 0.06
    readonly property real moteOuter: Math.min(orbBoxW, orbBoxH) * 0.47

    property int moteCursor: 0

    // Pooled: replacing the model restarts every mote in flight.
    function spawnMote() {
        const mote = moteField.itemAt(moteCursor)
        if (mote) mote.launch()
        moteCursor = (moteCursor + 1) % moteField.count
    }

    function bumpOrb() {
        if (reduceMotion) return
        wobbleAnim.restart()
        spawnMote()
        glowOrb.bump()
        hourSand.bump()
    }

    function shakeOrb() {
        failShake.restart()
        failMurk.restart()
    }

    function skipEntry() {
        morphProgress = 1
        dimProgress = 1
        contentFade = 1
        groupFade = 1
        faceEnterScale = 1
    }

    onEntryStartedChanged: {
        if (!entryStarted) return
        if (morphing) morphEntry.start()
        else scaleEntry.start()
    }

    function startExit() {
        if (morphing) {
            // Flag before the animation: the morph is settled, so nothing jumps.
            exiting = true
            morphExit.start()
        } else {
            scaleExit.start()
        }
    }

    // Held so the unlock reads on the orb before the geometry moves.
    onUnlockingChanged: {
        if (!unlocking) return
        morphEntry.stop()
        scaleEntry.stop()
        // startExit swaps the geometry assuming the entry finished, so settle it first.
        skipEntry()
        successBloom.start()
        if (unlockGrace > 0) exitDelay.restart()
        else startExit()
    }

    Timer {
        id: exitDelay
        interval: root.unlockGrace
        onTriggered: root.startExit()
    }

    // session_lock_xray paints the desktop through anything translucent.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.02, 0.06, 1)
        opacity: (root.uiVisible ? root.dimStrength : 1) * root.dimProgress
    }

    Item {
        id: faceGroup
        anchors.fill: parent
        visible: root.uiVisible
        transformOrigin: Item.Center
        scale: root.faceEnterScale
        opacity: root.morphing ? 1 : root.groupFade

        UI.MugenSurface {
            id: face

            x: root.liveX
            y: root.liveY
            width: root.liveW
            height: root.liveH

            // Never `radius`: MugenSurface binds it to baseRadius.
            baseRadius: root.liveRadius
            // The face carries none of the bar's modules, so unlocking cross-fades.
            opacity: (root.startOpacity
                + (root.faceOpacity - root.startOpacity) * root.morphProgress) * root.exitFade

            theme: root.themeRef
        }

        // Elements leave the face at different times; one fade cannot cover both.
        Item {
            id: faceClip
            x: root.liveX
            y: root.liveY
            width: root.liveW
            height: root.liveH
            clip: true
            opacity: root.contentFade

            // Cancels the clip's offset so children stay in surface coordinates.
            Item {
                x: -faceClip.x
                y: -faceClip.y
                width: root.width
                height: root.height

                LockBox {
                    x: root.contentX + root.colLeft(0)
                    y: root.contentY + root.rowTop(0)
                    width: root.colSpan(0, 1)
                    height: root.rowSpan(1)
                    cornerRadius: root.boxRadius
                    opacity: root.columnReveal(0)

                    Text {
                        anchors.centerIn: parent
                        width: parent.width * 0.86
                        text: root.timeText
                        color: root.clockColor
                        opacity: 0.7
                        horizontalAlignment: Text.AlignHCenter
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: Math.round(root.cellH * 0.2)
                        font.family: root.faceFontFamily
                        font.weight: 200
                        font.pixelSize: Math.round(root.cellH * 0.5)
                        font.letterSpacing: root.cellH * 0.5 * 0.02
                        font.hintingPreference: root.typo
                            ? root.typo.hintLarge : Font.PreferNoHinting
                    }
                }

                LockBox {
                    x: root.contentX + root.colLeft(0)
                    y: root.contentY + root.rowTop(1)
                    width: root.colSpan(0, 1)
                    height: root.rowSpan(1)
                    cornerRadius: root.boxRadius
                    opacity: root.columnReveal(0)

                    LockCalendarMonth {
                        anchors.fill: parent
                        fontFamily: root.faceFontFamily
                        tint: root.clockColor
                        faintTint: root.subtleColor
                        accent: root.accentColor
                        today: root.today
                        weekStart: root.calendarWeekStart
                        events: root.calendarEvents
                    }
                }

                LockBox {
                    x: root.contentX + root.colLeft(0)
                    y: root.contentY + root.rowTop(2)
                    width: root.colSpan(0, 1)
                    height: root.rowSpan(2)
                    cornerRadius: root.boxRadius
                    opacity: root.columnReveal(0)
                    Rectangle {
                        anchors.fill: parent
                        radius: root.boxRadius
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: root.weatherPalette ? root.weatherPalette.bg2 : "transparent"
                            }
                            GradientStop {
                                position: 0.55
                                color: root.weatherPalette ? root.weatherPalette.bg1 : "transparent"
                            }
                            GradientStop {
                                position: 1
                                color: root.weatherPalette ? root.weatherPalette.bg3 : "transparent"
                            }
                        }
                        opacity: root.weatherPalette ? 0.65 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
                        }
                    }

                    Rectangle {
                        id: weatherMask
                        anchors.fill: parent
                        radius: root.boxRadius
                        color: "white"
                        antialiasing: true
                        visible: false
                        layer.enabled: true
                    }

                    Content.WeatherParticles {
                        anchors.fill: parent
                        wtype: root.weatherParticleType
                        windKmh: root.weatherWind
                        tint: root.weatherPalette ? root.weatherPalette.accent : root.accentColor
                        active: !root.reduceMotion
                        layer.enabled: true
                        layer.effect: OpacityMask { maskSource: weatherMask }
                    }

                    LockWeatherBox {
                        anchors.fill: parent
                        anchors.margins: root.cellH * 0.2
                        fontFamily: root.faceFontFamily
                        tint: root.clockColor
                        faintTint: root.subtleColor
                        unit: Math.round(root.cellH * 0.2)
                        iconSource: root.weatherIconSource
                        temperature: root.weatherText
                        highLow: root.weatherHighLow
                        condition: root.weatherCondition
                    }
                }

                LockBox {
                    id: orbBox
                    x: root.contentX + root.colLeft(1)
                    y: root.contentY + root.rowTop(0)
                    width: root.colSpan(1, 1)
                    height: root.rowSpan(2)
                    cornerRadius: root.boxRadius
                    opacity: root.columnReveal(1)

                    Item {
                        id: lockIcon

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: root.cellH * 0.17
                        width: root.cellH * 0.13
                        height: width

                        property real glyphOpacity: root.unlocking ? 0.85 : 0.4

                        Behavior on glyphOpacity {
                            NumberAnimation { duration: 200 }
                        }

                        // Under the body, so the feet hide when closed and show as it swings.
                        Item {
                            width: parent.width
                            height: parent.height

                            // Lifted first, or the free foot sweeps through the body.
                            y: root.unlocking ? -height * 0.15 : 0

                            Behavior on y {
                                NumberAnimation {
                                    duration: 260; easing.type: Easing.OutCubic
                                }
                            }

                            transform: Rotation {
                                // Swung about the standing foot, as a shackle clears its body.
                                origin.x: lockIcon.width * (9 / 24)
                                origin.y: lockIcon.height * (8 / 24)
                                // Upright: a tilted axis lands the half turn skewed, not mirrored.
                                axis: Qt.vector3d(0, 1, 0)
                                angle: root.unlocking ? 180 : 0

                                Behavior on angle {
                                    NumberAnimation {
                                        duration: 380; easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            Image {
                                id: shackleGlyph
                                anchors.fill: parent
                                source: root.iconsBase + "/lock-shackle.svg"
                                sourceSize.width: width * 2
                                sourceSize.height: height * 2
                                mipmap: true
                                visible: false
                            }

                            ColorOverlay {
                                anchors.fill: parent
                                source: shackleGlyph
                                color: root.clockColor
                                opacity: lockIcon.glyphOpacity
                            }
                        }

                        Image {
                            id: bodyGlyph
                            anchors.fill: parent
                            source: root.iconsBase + "/lock-body.svg"
                            sourceSize.width: width * 2
                            sourceSize.height: height * 2
                            mipmap: true
                            visible: false
                        }

                        ColorOverlay {
                            anchors.fill: parent
                            source: bodyGlyph
                            color: root.clockColor
                            opacity: lockIcon.glyphOpacity
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.cellH * 0.17
                        width: parent.width * 0.82
                        text: root.faultText
                        visible: root.faultText !== ""
                        color: root.errorColor
                        opacity: 0.9
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.family: root.faceFontFamily
                        font.pixelSize: Math.round(root.cellH * 0.13)
                    }
                }

                LockBox {
                    x: root.contentX + root.colLeft(2)
                    y: root.contentY + root.rowTop(0)
                    width: root.colSpan(2, 1)
                    height: root.rowSpan(1)
                    cornerRadius: root.boxRadius
                    opacity: root.columnReveal(2)

                    LockMoonPhase {
                        anchors.fill: parent
                        fontFamily: root.faceFontFamily
                        textureSource: root.texturesBase === ""
                            ? "" : root.texturesBase + "/moon-nearside.png"
                        tint: root.clockColor
                        faintTint: root.subtleColor
                        accent: root.accentColor
                        today: root.today
                        running: !root.reduceMotion
                    }
                }

                LockBox {
                    x: root.contentX + root.colLeft(2)
                    y: root.contentY + root.rowTop(1)
                    width: root.colSpan(2, 1)
                    height: root.rowSpan(1)
                    cornerRadius: root.boxRadius
                    opacity: root.columnReveal(2)

                    LockGlowOrb {
                        id: glowOrb
                        anchors.fill: parent
                        fontFamily: root.faceFontFamily
                        tint: root.clockColor
                        faintTint: root.subtleColor
                        accent: root.accentColor
                        glow: root.orbBase
                        today: root.today
                        running: !root.reduceMotion
                    }
                }

                LockMediaBlock {
                    x: root.contentX + root.colLeft(1)
                    y: root.contentY + root.rowTop(2)
                    width: root.colSpan(1, 2)
                    height: root.rowSpan(1)
                    cornerRadius: root.boxRadius
                    opacity: root.columnReveal(1)

                    fontFamily: root.faceFontFamily
                    tint: root.clockColor
                    faintTint: root.subtleColor
                    iconsBase: root.iconsBase
                    accent: root.mediaAccent
                    isPlaying: root.mediaIsPlaying
                    title: root.mediaTitle
                    artist: root.mediaArtist
                    artUrl: root.mediaArtUrl
                    position: root.mediaPosition
                    duration: root.mediaDuration

                    onPreviousRequested: root.previousRequested()
                    onPlayPauseRequested: root.playPauseRequested()
                    onNextRequested: root.nextRequested()
                }

                LockBox {
                    x: root.contentX + root.colLeft(1)
                    y: root.contentY + root.rowTop(3)
                    width: root.colSpan(1, 1)
                    height: root.rowSpan(1)
                    cornerRadius: root.boxRadius
                    opacity: root.columnReveal(1)

                    Common.BarVisualizer {
                        anchors.centerIn: parent
                        cavaManager: root.cavaManager
                        barCount: root.levelsBarCount
                        barIndices: [12, 10, 8, 6, 4, 2, 1, 3, 5, 7, 9, 11]
                        maxHeightMultipliers: [0.5, 0.7, 0.85, 1.0, 0.9, 0.75,
                                               0.75, 0.9, 1.0, 0.85, 0.7, 0.5]
                        barWidth: root.levelsBarWidth
                        barSpacing: root.levelsBarWidth * 0.75
                        minBarHeight: Math.round(root.cellH * 0.08)
                        maxBarHeight: Math.round(root.cellH * 0.5)
                        barColor: root.mediaAccent
                        baseColor: root.accentColor

                        Behavior on barColor {
                            ColorAnimation {
                                duration: 600
                                easing.type: Easing.InOutCubic
                            }
                        }
                    }
                }

                LockBox {
                    x: root.contentX + root.colLeft(2)
                    y: root.contentY + root.rowTop(3)
                    width: root.colSpan(2, 1)
                    height: root.rowSpan(1)
                    cornerRadius: root.boxRadius
                    opacity: root.columnReveal(2)

                    LockHourSand {
                        id: hourSand
                        anchors.fill: parent
                        fontFamily: root.faceFontFamily
                        tint: root.clockColor
                        faintTint: root.subtleColor
                        accent: root.accentColor
                        glow: root.orbBase
                        glowSecondary: root.glowSecondaryColor
                        glowTertiary: root.glowTertiaryColor
                        running: !root.reduceMotion
                    }
                }

                Repeater {
                    model: [
                        { row: 0, icon: "/power-shutdown.svg", label: "SHUT DOWN", act: 0 },
                        { row: 1, icon: "/moon.svg", label: "SLEEP", act: 1 },
                        { row: 2, icon: "/reboot.svg", label: "RESTART", act: 2 },
                        { row: 3, icon: "/logout.svg", label: "LOG OUT", act: 3 }
                    ]

                    LockBox {
                        id: powerBox
                        required property var modelData

                        x: root.contentX + root.colLeft(3)
                        y: root.contentY + root.rowTop(modelData.row)
                        width: root.colSpan(3, 1)
                        height: root.rowSpan(1)
                        cornerRadius: root.boxRadius
                        opacity: root.columnReveal(3)

                        LockPowerButton {
                            anchors.fill: parent
                            fontFamily: root.faceFontFamily
                            tint: root.clockColor
                            unit: Math.round(root.cellH * 0.18)
                            source: root.iconsBase + powerBox.modelData.icon
                            label: powerBox.modelData.label
                            onActivated: root.powerActionRequested(powerBox.modelData.act)
                        }
                    }
                }

                // Outside the orb's item, which is already translated: it would double.
                Repeater {
                    id: moteField
                    model: 14

                    Rectangle {
                        id: mote
                        required property int index

                        property real progress: 1
                        property real angle: 0
                        property real travel: 0

                        function launch() {
                            angle = Math.random() * Math.PI * 2
                            // Clamped: a long password leaves only a sliver to start in.
                            const inner = Math.min(root.moteInner,
                                                   root.moteOuter * 0.96)
                            travel = inner + (root.moteOuter - inner) * Math.random()
                            flight.restart()
                        }

                        NumberAnimation {
                            id: flight
                            target: mote
                            property: "progress"
                            from: 0
                            to: 1
                            duration: 620
                            // Accelerating inwards, so it reads as pulled rather than drifting.
                            easing.type: Easing.InCubic
                        }

                        width: Math.max(2, root.orbSize * 0.024)
                        height: width
                        radius: width / 2
                        color: root.orbBase
                        visible: progress < 1
                        opacity: Math.min(1, (1 - progress) * 2.4) * 0.4
                        scale: 0.45 + (1 - progress) * 0.6
                        x: root.orbCX - width / 2
                            + Math.cos(angle) * travel * (1 - progress)
                        y: root.orbCY - height / 2
                            + Math.sin(angle) * travel * (1 - progress)
                    }
                }

                Item {
                    x: root.orbCX - root.orbSize / 2
                    y: root.orbCY - root.orbSize / 2
                    width: root.orbSize
                    height: root.orbSize

                // One property per factor: writing scale directly severs the others.
                    Item {
                        id: orbSlot

                        // Sized, not anchored: `anchors.fill` owns x and silently wins.
                        width: parent.width
                        height: parent.height

                        property real chargeScale: 1 + root.chargeLength * 0.022
                        property real chargeOpacity: 0.78 + root.chargeLength * 0.016
                        property real wobble: 1.0
                        property real failOffset: 0
                        property real murk: 0
                        property real bloom: 0
                        readonly property real entryScale: 0.9 + 0.1 * root.contentFade

                        x: failOffset
                        scale: chargeScale * wobble * entryScale * (1 + bloom * 0.22)
                        opacity: chargeOpacity

                        Behavior on chargeScale {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }
                        Behavior on chargeOpacity {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }

                        // The only report on the attempt, so every state must read on its own.
                        Ai.AmbientOrb {
                            anchors.fill: parent
                            orbColor: Qt.tint(root.orbBase,
                                              Qt.rgba(root.errorColor.r,
                                                      root.errorColor.g,
                                                      root.errorColor.b,
                                                      orbSlot.murk * 0.8))
                            active: !root.unlocking
                            breathEnabled: !root.reduceMotion && !root.unlocking
                            idleBreathPeak: root.authenticating ? 1.13 : 1.05
                            idleBreathDuration: root.authenticating ? 850 : 3500
                            showHalo: true
                            haloScale: root.authenticating ? 1.34 : 1.2
                            haloOpacity: 0.5
                        }
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: morphEntry

        NumberAnimation {
            target: root; property: "morphProgress"; to: 1
            duration: root.morphDuration; easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: root; property: "dimProgress"; to: 1
            duration: Math.round(root.morphDuration * 0.8)
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            PauseAnimation { duration: Math.round(root.morphDuration * 0.42) }
            NumberAnimation {
                target: root; property: "contentFade"; to: 1
                duration: Math.round(root.morphDuration * 0.8)
                easing.type: Easing.OutCubic
            }
        }
    }

    ParallelAnimation {
        id: scaleEntry

        NumberAnimation {
            target: root; property: "groupFade"; to: 1
            duration: Math.round(root.morphDuration * 0.45)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "faceEnterScale"; from: 0.94; to: 1
            duration: Math.round(root.morphDuration * 0.45)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "dimProgress"; to: 1
            duration: Math.round(root.morphDuration * 0.45)
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            PauseAnimation { duration: Math.round(root.morphDuration * 0.1) }
            NumberAnimation {
                target: root; property: "contentFade"; to: 1
                duration: Math.round(root.morphDuration * 0.8)
                easing.type: Easing.OutCubic
            }
        }
        // The geometry bindings read it even when this path does not morph.
        NumberAnimation { target: root; property: "morphProgress"; to: 1; duration: 0 }
    }

    SequentialAnimation {
        id: wobbleAnim
        NumberAnimation {
            target: orbSlot
            property: "wobble"
            to: 1.16
            duration: 220
            easing.type: Easing.Bezier
            easing.bezierCurve: [0.25, 0.55, 0.35, 1, 1, 1]
        }
        NumberAnimation {
            target: orbSlot
            property: "wobble"
            to: 1.0
            duration: 700
            easing.type: Easing.Bezier
            easing.bezierCurve: [0.3, 0.7, 0.25, 1, 1, 1]
        }
    }

    // Fast and short, or it reads as drift rather than refusal.
    SequentialAnimation {
        id: failShake
        NumberAnimation { target: orbSlot; property: "failOffset"; to: -0.072 * root.orbSize; duration: 65 }
        NumberAnimation { target: orbSlot; property: "failOffset"; to: 0.064 * root.orbSize; duration: 75 }
        NumberAnimation { target: orbSlot; property: "failOffset"; to: -0.05 * root.orbSize; duration: 75 }
        NumberAnimation { target: orbSlot; property: "failOffset"; to: 0.035 * root.orbSize; duration: 75 }
        NumberAnimation { target: orbSlot; property: "failOffset"; to: -0.019 * root.orbSize; duration: 75 }
        NumberAnimation {
            target: orbSlot; property: "failOffset"; to: 0
            duration: 130; easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: successBloom

        // Pulled in first, or the opening reads as swelling, not release.
        NumberAnimation {
            target: orbSlot; property: "bloom"; to: -0.4
            duration: 90; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: orbSlot; property: "bloom"; to: 1
            duration: 220; easing.type: Easing.OutBack
        }
        NumberAnimation {
            target: orbSlot; property: "bloom"; to: 0
            duration: 520; easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: failMurk
        NumberAnimation { target: orbSlot; property: "murk"; to: 1; duration: 220 }
        PauseAnimation { duration: 550 }
        NumberAnimation { target: orbSlot; property: "murk"; to: 0; duration: 330 }
    }

    ParallelAnimation {
        id: morphExit

        NumberAnimation {
            target: root; property: "dimProgress"; to: 0
            duration: Math.round(root.morphDuration * 0.8)
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root; property: "morphProgress"; to: 0
            duration: root.morphDuration; easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: root; property: "contentFade"; to: 0
            duration: Math.round(root.morphDuration * 0.3)
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            // OutExpo has all but landed here, so the face is already on the bar.
            PauseAnimation { duration: Math.round(root.morphDuration * 0.75) }
            NumberAnimation {
                target: root; property: "exitFade"; to: 0
                duration: Math.round(root.morphDuration * 0.25)
                easing.type: Easing.OutCubic
            }
        }
    }

    ParallelAnimation {
        id: scaleExit

        NumberAnimation {
            target: root; property: "dimProgress"; to: 0
            duration: Math.round(root.morphDuration * 0.8)
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root; property: "groupFade"; to: 0
            duration: Math.round(root.morphDuration * 0.45)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "faceEnterScale"; to: 0.94
            duration: Math.round(root.morphDuration * 0.45)
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            PauseAnimation { duration: Math.round(root.morphDuration * 0.15) }
            NumberAnimation {
                target: root; property: "contentFade"; to: 0
                duration: Math.round(root.morphDuration * 0.3)
                easing.type: Easing.OutCubic
            }
        }
    }
}
