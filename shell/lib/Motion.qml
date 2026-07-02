pragma Singleton
import QtQuick

// The shell's motion language. Every transition picks a duration from this
// scale and an easing from these roles, so unrelated modules move with the
// same rhythm. Looping ambience (orb breathing, cava pulses) is identity,
// not transition — those keep their own literal timings.
QtObject {
    readonly property int instant: 0
    // Color / opacity ticks: hover tint, focus borders.
    readonly property int micro: 150
    // Hover scale, chip toggles, small reveals.
    readonly property int fast: 200
    // Fades, expands, most state changes.
    readonly property int standard: 300
    // Content transitions, crossfades that should feel unhurried.
    readonly property int gentle: 400
    // Large element movement (panels growing, big fades).
    readonly property int slow: 600
    // Full panel slides across the screen.
    readonly property int drift: 850
    // Whole-bar reshapes (mode switches).
    readonly property int sweep: 1000

    // Settle out of a change — the shell's default voice.
    readonly property int easeOut: Easing.OutCubic
    // A → B movement where both ends are visible.
    readonly property int easeMove: Easing.InOutCubic
    // Organic, breathing motion.
    readonly property int easeOrganic: Easing.InOutSine
    // Arrivals that should snap into place (mode switches).
    readonly property int easeArrive: Easing.OutExpo
    // Playful overshoot accent — use sparingly.
    readonly property int easeSpring: Easing.OutBack

    // Corner language.
    readonly property int radiusPanel: 24
    readonly property int radiusSection: 20
    readonly property int radiusCard: 12
    readonly property int radiusSmall: 8
}
