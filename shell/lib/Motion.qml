pragma Singleton
import QtQuick

// Transitions must draw from this scale. Looping ambience (orb breathing,
// cava pulses) is identity, not transition, and keeps its own literal timings.
QtObject {
    readonly property int instant: 0
    readonly property int micro: 150      // color / opacity ticks: hover tint, focus borders
    readonly property int fast: 200       // hover scale, chip toggles, small reveals
    readonly property int standard: 300   // fades, expands, most state changes
    readonly property int gentle: 400     // content transitions, crossfades that feel unhurried
    readonly property int slow: 600       // large element movement: panels growing, big fades
    readonly property int drift: 850      // full panel slides across the screen
    readonly property int sweep: 1000     // whole-bar reshapes (mode switches)

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
