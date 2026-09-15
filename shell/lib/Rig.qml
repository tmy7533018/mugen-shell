pragma Singleton
import QtQuick

// Pure progress → motion helpers for RiggedIcon parts; t runs 0..1 over `duration`.
QtObject {
    readonly property int duration: Motion.dur(800)

    function fraction(ms) {
        return ms / 800
    }

    function clamp01(v) {
        return v < 0 ? 0 : (v > 1 ? 1 : v)
    }

    // (1−t)^1.5 envelope: peak ratios 0.74 / 0.56 / 0.41 match the reference bell's 12 → 9 → 5 → 2.
    function damped(t, amp, cycles) {
        t = clamp01(t)
        return amp * Math.pow(1 - t, 1.5) * Math.sin(2 * Math.PI * cycles * t)
    }

    function delay(t, d) {
        return clamp01((t - d) / (1 - d))
    }

    function bump(t, center, width) {
        const u = (t - center) / width
        return Math.exp(-u * u)
    }

    function pulse(t, i, n) {
        const phase = 0.5 * (i + 1) / (n + 1)
        return bump(t, phase, 0.07) + 0.5 * bump(t, 0.5 + phase, 0.07)
    }

    function flip(t) {
        return Math.cos(2 * Math.PI * clamp01(t / 0.6))
    }
}
