pragma ComponentBehavior: Bound

import QtQuick
import "../ui" as UI
import "../common" as Common
import "../content" as Content
import "../content/ai" as Ai

Item {
    id: root

    property var typo
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
    property real faceOpacity: 0.92
    property real dimStrength: 0.30

    property string timeText: ""
    property date today: new Date()

    property string iconsBase: ""
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

    signal previousRequested
    signal playPauseRequested
    signal nextRequested
    signal powerActionRequested(int action)

    property int passwordLength: 0
    property string pamMessage: ""
    property bool pamIsError: false
    property bool unlocking: false
    property bool reduceMotion: false

    readonly property bool morphing:
        entryMorph && screenName !== "" && screenName === entryScreen

    // The bar scales its margins against a 1920 reference but not its radius.
    readonly property real faceMargin: Math.round(marginBase * width / 1920)
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

    property real mpH: 0
    property real mpV: 0
    property real dimProgress: 0
    property real contentFade: 0
    property real groupFade: 0
    property real faceEnterScale: 1
    property real exitFade: 1

    readonly property real liveX: startX + (faceX - startX) * mpH
    readonly property real liveW: startW + (faceW - startW) * mpH
    readonly property real liveY: startY + (faceY - startY) * mpV
    readonly property real liveH: startH + (faceH - startH) * mpV
    readonly property real liveRadius:
        startRadius + (faceRadius - startRadius) * mpV

    readonly property real cx: liveX + (liveW - faceW) / 2
    readonly property real cy: liveY + (liveH - faceH) / 2

    // Pinned while leaving: the face collapses far faster than the content can
    // fade, so following it would fling the clock off the top of the screen.
    readonly property real contentX: exiting ? faceX : cx
    readonly property real contentY: exiting ? faceY : cy

    readonly property real headP: Math.min(1, contentFade / 0.6)
    readonly property real footP: Math.max(0, (contentFade - 0.35) / 0.65)

    // A 4x4 grid of cells. Columns are uneven: the first holds the clock stack
    // and the last is a narrow strip of power buttons.
    readonly property var colFrac: [0.327, 0.268, 0.270, 0.127]
    readonly property int rowCount: 4

    readonly property real gridPadX: faceW * 0.05
    readonly property real gridPadY: faceH * 0.085
    readonly property real gutterX: faceW * 0.007
    readonly property real gutterY: faceH * 0.012

    readonly property real gridW: faceW - gridPadX * 2 - gutterX * (colFrac.length - 1)
    readonly property real gridH: faceH - gridPadY * 2 - gutterY * (rowCount - 1)
    readonly property real cellH: gridH / rowCount

    readonly property real boxRadius: Math.round(faceH * 0.022)

    readonly property int levelsBarCount: 12
    readonly property real levelsBarWidth: Math.max(2, Math.min(
        cellH * 0.055,
        colSpan(1, 1) * 0.8 / (levelsBarCount + (levelsBarCount - 1) * 0.75)))

    function colLeft(c) {
        let x = gridPadX
        for (let i = 0; i < c; i++) x += colFrac[i] * gridW + gutterX
        return x
    }

    function colSpan(c, span) {
        let w = 0
        for (let i = c; i < c + span; i++) w += colFrac[i] * gridW
        return w + gutterX * (span - 1)
    }

    function rowTop(r) {
        return gridPadY + r * (cellH + gutterY)
    }

    function rowSpan(span) {
        return cellH * span + gutterY * (span - 1)
    }


    readonly property color clockColor:
        themeRef ? themeRef.textPrimary : "#f2f3ff"
    readonly property color pamColor:
        themeRef ? themeRef.textSecondary : Qt.rgba(235 / 255, 238 / 255, 1, 0.55)
    readonly property color pamErrorColor: "#ff9db0"
    readonly property color orbBase:
        themeRef ? themeRef.glowTertiary : "#7b6cf6"

    property int clockWeight: 200
    property real clockOpacity: 0.7

    readonly property real orbBoxW: colSpan(1, 1)
    readonly property real orbBoxH: rowSpan(2)
    readonly property real orbSize: Math.round(Math.min(orbBoxW, orbBoxH) * 0.55)
    readonly property real orbCX: contentX + colLeft(1) + orbBoxW / 2
    readonly property real orbCY: contentY + rowTop(0) + orbBoxH * 0.5
    readonly property int chargeLength: Math.min(passwordLength, 14)

    function bumpOrb() {
        if (reduceMotion) return
        wobbleAnim.restart()
    }

    function shakeOrb() {
        failShake.restart()
        failMurk.restart()
    }

    function skipEntry() {
        mpH = 1
        mpV = 1
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

    onUnlockingChanged: {
        if (!unlocking) return
        morphEntry.stop()
        scaleEntry.stop()
        if (morphing) {
            // Flag before the animation: the geometry bindings read it, and
            // mpH is still 1 here so nothing jumps.
            exiting = true
            morphExit.start()
        } else {
            scaleExit.start()
        }
    }

    Component {
        id: weatherBackdrop

        Item {
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
                opacity: root.weatherPalette ? 0.85 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
                }
            }

            Content.WeatherParticles {
                anchors.fill: parent
                wtype: root.weatherParticleType
                windKmh: root.weatherWind
                tint: root.weatherPalette ? root.weatherPalette.accent : root.orbBase
                active: !root.reduceMotion
            }
        }
    }

    // session_lock_xray keeps painting the desktop wherever this surface is
    // translucent, so a screen without the face has to be covered outright.
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
            // The face lands on the bar's rectangle but carries none of its
            // modules, so unlocking has to cross-fade into the restored bar:
            // destroying the lock surface reveals them in a single frame.
            opacity: (root.startOpacity
                + (root.faceOpacity - root.startOpacity) * root.mpH) * root.exitFade

            theme: root.themeRef
            gradientEnabled: false
            reduceMotion: root.reduceMotion
        }

        // The content belongs to the panel, so the collapsing edge has to wipe
        // it: elements leave the face at different times (the orb 120ms before
        // the clock) and no single fade duration can cover both.
        Item {
            id: faceClip
            x: root.liveX
            y: root.liveY
            width: root.liveW
            height: root.liveH
            clip: true
            opacity: root.contentFade

            // Children stay in surface coordinates; this cancels the clip's own
            // offset so the layout never has to know about it.
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
                    opacity: root.headP

                    Text {
                        anchors.centerIn: parent
                        width: parent.width * 0.86
                        text: root.timeText
                        color: root.clockColor
                        opacity: root.clockOpacity
                        horizontalAlignment: Text.AlignHCenter
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: Math.round(root.cellH * 0.2)
                        font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
                        font.weight: root.clockWeight
                        font.pixelSize: Math.round(root.cellH * 0.62)
                        font.letterSpacing: root.cellH * 0.62 * 0.02
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
                    opacity: root.headP

                    LockCalendarStrip {
                        anchors.fill: parent
                        anchors.margins: root.cellH * 0.18
                        typo: root.typo
                        tint: root.clockColor
                        faintTint: root.pamColor
                        todayTint: root.orbBase
                        unit: Math.round(root.cellH * 0.17)
                        today: root.today
                    }
                }

                LockBox {
                    x: root.contentX + root.colLeft(0)
                    y: root.contentY + root.rowTop(2)
                    width: root.colSpan(0, 1)
                    height: root.rowSpan(2)
                    cornerRadius: root.boxRadius
                    opacity: root.footP
                    background: weatherBackdrop

                    LockWeatherBox {
                        anchors.fill: parent
                        anchors.margins: root.cellH * 0.2
                        typo: root.typo
                        tint: root.clockColor
                        faintTint: root.pamColor
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
                    opacity: root.headP

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.cellH * 0.18
                        width: parent.width * 0.8
                        text: root.pamMessage
                        color: root.pamIsError ? root.pamErrorColor : root.pamColor
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
                        font.pixelSize: Math.round(root.cellH * 0.11)
                        font.letterSpacing: root.cellH * 0.11 * 0.18

                        Behavior on color {
                            ColorAnimation { duration: 300 }
                        }
                    }
                }

                LockBox {
                    x: root.contentX + root.colLeft(2)
                    y: root.contentY + root.rowTop(0)
                    width: root.colSpan(2, 1)
                    height: root.rowSpan(1)
                    cornerRadius: root.boxRadius
                    opacity: root.footP
                }

                LockBox {
                    x: root.contentX + root.colLeft(2)
                    y: root.contentY + root.rowTop(1)
                    width: root.colSpan(2, 1)
                    height: root.rowSpan(1)
                    cornerRadius: root.boxRadius
                    opacity: root.footP
                }

                LockMediaBlock {
                    x: root.contentX + root.colLeft(1)
                    y: root.contentY + root.rowTop(2)
                    width: root.colSpan(1, 2)
                    height: root.rowSpan(1)
                    cornerRadius: root.boxRadius
                    opacity: root.footP

                    typo: root.typo
                    tint: root.clockColor
                    faintTint: root.pamColor
                    iconsBase: root.iconsBase
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
                    opacity: root.footP

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
                        barColor: root.clockColor
                        baseColor: root.clockColor
                    }
                }

                LockBox {
                    x: root.contentX + root.colLeft(2)
                    y: root.contentY + root.rowTop(3)
                    width: root.colSpan(2, 1)
                    height: root.rowSpan(1)
                    cornerRadius: root.boxRadius
                    opacity: root.footP
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
                        opacity: root.footP

                        LockPowerButton {
                            anchors.fill: parent
                            typo: root.typo
                            tint: root.clockColor
                            unit: Math.round(root.cellH * 0.18)
                            source: root.iconsBase + powerBox.modelData.icon
                            label: powerBox.modelData.label
                            onActivated: root.powerActionRequested(powerBox.modelData.act)
                        }
                    }
                }

                Item {
                    x: root.orbCX - root.orbSize / 2
                    y: root.orbCY - root.orbSize / 2
                    width: root.orbSize
                    height: root.orbSize

                    // One property per animated factor, multiplied in: no
                    // animation may write to scale or opacity and sever the
                    // others' binding.
                    Item {
                        id: orbSlot
                        anchors.fill: parent

                        property real chargeScale: 1 + root.chargeLength * 0.022
                        property real chargeOpacity: 0.78 + root.chargeLength * 0.016
                        property real wobble: 1.0
                        property real failOffset: 0
                        property real murk: 0
                        readonly property real entryScale: 0.9 + 0.1 * root.contentFade

                        x: failOffset
                        scale: chargeScale * wobble * entryScale
                        opacity: chargeOpacity

                        Behavior on chargeScale {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }
                        Behavior on chargeOpacity {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }

                        Ai.AmbientOrb {
                            anchors.fill: parent
                            orbColor: Qt.tint(root.orbBase,
                                              Qt.rgba(orbSlot.murk * 0.6,
                                                      orbSlot.murk * 0.6,
                                                      orbSlot.murk * 0.6,
                                                      orbSlot.murk))
                            active: !root.unlocking
                            breathEnabled: !root.reduceMotion && !root.unlocking
                            idleBreathPeak: 1.05
                            idleBreathDuration: 3500
                            showHalo: true
                            haloScale: 1.2
                        }
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: morphEntry

        NumberAnimation {
            target: root; property: "mpH"; to: 1
            duration: root.morphDuration; easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: root; property: "mpV"; to: 1
            duration: root.morphDuration; easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: root; property: "dimProgress"; to: 1
            duration: Math.round(root.morphDuration * 0.8)
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            PauseAnimation { duration: Math.round(root.morphDuration * 0.72) }
            NumberAnimation {
                target: root; property: "contentFade"; to: 1
                duration: Math.round(root.morphDuration * 0.4)
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
            PauseAnimation { duration: Math.round(root.morphDuration * 0.15) }
            NumberAnimation {
                target: root; property: "contentFade"; to: 1
                duration: Math.round(root.morphDuration * 0.4)
                easing.type: Easing.OutCubic
            }
        }
        // mpH/mpV are the identity here, but the geometry bindings read them.
        NumberAnimation { target: root; property: "mpH"; to: 1; duration: 0 }
        NumberAnimation { target: root; property: "mpV"; to: 1; duration: 0 }
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

    SequentialAnimation {
        id: failShake
        NumberAnimation { target: orbSlot; property: "failOffset"; to: -0.037 * root.orbSize; duration: 165 }
        NumberAnimation { target: orbSlot; property: "failOffset"; to: 0.032 * root.orbSize; duration: 165 }
        NumberAnimation { target: orbSlot; property: "failOffset"; to: -0.026 * root.orbSize; duration: 165 }
        NumberAnimation { target: orbSlot; property: "failOffset"; to: 0.021 * root.orbSize; duration: 165 }
        NumberAnimation { target: orbSlot; property: "failOffset"; to: 0; duration: 440 }
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
            target: root; property: "mpH"; to: 0
            duration: root.morphDuration; easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: root; property: "mpV"; to: 0
            duration: root.morphDuration; easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: root; property: "contentFade"; to: 0
            duration: Math.round(root.morphDuration * 0.3)
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            // OutExpo has all but landed by here, so the face is already sitting
            // on the bar's rectangle while it dissolves into it.
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
