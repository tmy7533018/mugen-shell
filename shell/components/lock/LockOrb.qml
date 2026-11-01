pragma ComponentBehavior: Bound

import QtQuick
import "../content/ai" as Ai

Item {
    id: root

    property real orbSize: 0
    property real orbCX: 0
    property real orbCY: 0
    property real orbBoxW: 0
    property real orbBoxH: 0
    property color orbBase: "#a68cd9"
    property color errorColor: "#ff9db0"
    property int chargeLength: 0
    property real contentFade: 0
    property bool unlocking: false
    property bool uiVisible: false
    property bool authenticating: false
    property bool reduceMotion: false

    readonly property bool murking: failMurk.running

    // Outside the glow, which grows with charge and wobble to about 1.07x.
    readonly property real moteInner:
        orbSize * 0.53 * orbSlot.chargeScale * 1.16 + orbSize * 0.06
    readonly property real moteOuter: Math.min(orbBoxW, orbBoxH) * 0.47

    property int moteCursor: 0

    // Pooled: replacing the model restarts every mote in flight.
    function spawnMote() {
        const mote = moteField.itemAt(moteCursor) as LockMote
        if (mote) mote.launch(moteInner, moteOuter)
        moteCursor = (moteCursor + 1) % moteField.count
    }

    function bump() {
        wobbleAnim.restart()
        spawnMote()
    }

    function shake() {
        failShake.restart()
        failMurk.restart()
    }

    function startBloom() {
        successBloom.start()
    }

    // Outside the orb's item, which is already translated: it would double.
    Repeater {
        id: moteField
        model: 14

        LockMote {
            orbSize: root.orbSize
            orbBase: root.orbBase
            orbCX: root.orbCX
            orbCY: root.orbCY
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
                active: !root.unlocking && root.uiVisible
                breathEnabled: !root.reduceMotion && !root.unlocking
                idleBreathPeak: root.authenticating ? 1.13 : 1.05
                idleBreathDuration: root.authenticating ? 850 : 3500
                showHalo: true
                haloScale: root.authenticating ? 1.34 : 1.2
                haloOpacity: 0.5
            }
        }
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
}
