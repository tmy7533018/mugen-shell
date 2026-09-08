pragma Singleton
import QtQuick

// Transitions must draw from this scale. Looping ambience (orb breathing,
// cava pulses) is identity, not transition, and keeps its own literal timings.
QtObject {
    property var settings: null
    readonly property real speed: settings && isFinite(settings.animationDurationMultiplier) ? settings.animationDurationMultiplier : 1.0

    readonly property int instant: 0
    readonly property int micro: Math.round(150 * speed)      // color / opacity ticks: hover tint, focus borders
    readonly property int fast: Math.round(200 * speed)       // hover scale, chip toggles, small reveals
    readonly property int standard: Math.round(300 * speed)   // fades, expands, most state changes
    readonly property int gentle: Math.round(400 * speed)     // content transitions, crossfades that feel unhurried
    readonly property int slow: Math.round(600 * speed)       // large element movement: panels growing, big fades
    readonly property int drift: Math.round(850 * speed)      // full panel slides across the screen
    readonly property int sweep: Math.round(1000 * speed)     // whole-bar reshapes (mode switches)

    function dur(ms) {
        return Math.round(ms * speed)
    }

    readonly property int easeOut: Easing.OutCubic      // settle out of a change; the default voice
    readonly property int easeMove: Easing.InOutCubic   // A → B where both ends are visible
    readonly property int easeOrganic: Easing.InOutSine // organic, breathing motion
    readonly property int easeArrive: Easing.OutExpo    // arrivals that snap into place
    readonly property int easeSpring: Easing.OutBack    // playful overshoot accent; use sparingly

    readonly property int radiusPanel: 24
    readonly property int radiusSection: 20
    readonly property int radiusCard: 12
    readonly property int radiusSmall: 8
}
