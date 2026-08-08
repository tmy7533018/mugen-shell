pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property var typo
    property color tint: "white"
    property color faintTint: Qt.rgba(1, 1, 1, 0.35)
    property color accent: "#a68cd9"
    property color glow: "#a68cd9"
    property color glowSecondary: "#a68cd9"
    property color glowTertiary: "#a68cd9"
    property bool running: true

    // Mixed from the wallpaper's glows so the pile is not one flat colour.
    readonly property var grainColors:
        [accent, glow, glowSecondary, glowTertiary]

    readonly property real designPx: height / 221

    readonly property real grain: Math.max(2, Math.round(4 * designPx))

    // Short of the box: sand in the rounded corners reads as clipped.
    readonly property real inset: 16 * designPx

    readonly property int cols: Math.max(1, Math.floor((width - inset * 2) / grain))
    readonly property int rows: Math.max(1, Math.floor((height - inset * 2) / grain))

    property var grid: null
    property int filled: 0
    property int hour: -1
    property bool seeding: true
    property real shakeFrom: 0
    property real shakeUntil: 0

    // Survives the hour, so time at the keyboard shows in the pile.
    property int bonus: 0

    function bump() {
        if (!running) return

        // Grains need this long to land; shaking sooner disturbs an untouched pile.
        const now = Date.now()
        if (now > shakeUntil) shakeFrom = now + 620
        shakeUntil = Math.max(shakeUntil, shakeFrom + 420)

        bonus = Math.min(bonus + 6, Math.round(cols * rows * 0.35))
    }

    function reset(nextHour) {
        grid.fill(0)
        filled = 0
        bonus = 0
        shakeFrom = 0
        shakeUntil = 0
        hour = nextHour
        seeding = true
    }

    function pour(target) {
        // Opening at :47 must show 47 minutes at once, not fill up as you watch.
        const budget = seeding ? 40 : 3
        const mid = Math.floor(cols / 2)
        for (let i = 0; i < budget && filled < target; i++) {
            const x = mid + Math.round((Math.random() - 0.5) * 5)
            if (x < 0 || x >= cols) continue
            const cell = cols + x
            if (grid[cell]) continue
            const roll = Math.random()
            grid[cell] = roll < 0.04 ? 4 : roll < 0.11 ? 3 : roll < 0.24 ? 2 : 1
            filled += 1
        }
        if (filled >= target) seeding = false
    }

    function settle(shaking) {
        for (let y = rows - 2; y >= 0; y--) {
            for (let k = 0; k < cols; k++) {
                // Strided: scanning in order drags every pile to one side.
                const x = (k * 7 + y) % cols
                const at = y * cols + x
                const v = grid[at]
                if (!v) continue

                if (!grid[at + cols]) {
                    grid[at + cols] = v
                    grid[at] = 0
                    continue
                }

                const dir = Math.random() < 0.5 ? -1 : 1
                const nx = x + dir
                if (nx >= 0 && nx < cols && !grid[at + cols + dir] && !grid[at + dir]) {
                    grid[at + cols + dir] = v
                    grid[at] = 0
                    continue
                }

                if (shaking && Math.random() < 0.08) {
                    const sx = x + (Math.random() < 0.5 ? -1 : 1)
                    if (sx >= 0 && sx < cols && !grid[y * cols + sx]) {
                        grid[y * cols + sx] = v
                        grid[at] = 0
                    }
                }
            }
        }
    }

    function step() {
        if (!grid || grid.length !== cols * rows) {
            grid = new Uint8Array(cols * rows)
            filled = 0
            hour = -1
        }

        const now = new Date()
        if (now.getHours() !== hour) reset(now.getHours())

        const progress = (now.getMinutes() * 60 + now.getSeconds()) / 3600
        pour(Math.floor(progress * cols * 6) + bonus)

        // Stepped more often than drawn: stop-motion look at a real speed.
        const stamp = now.getTime()
        const shaking = stamp >= shakeFrom && stamp < shakeUntil
        settle(shaking)
        settle(shaking)

        canvas.requestPaint()
    }

    Timer {
        interval: 33
        repeat: true
        running: root.running && root.visible
        onTriggered: root.step()
    }

    Canvas {
        id: canvas

        anchors.fill: parent
        anchors.margins: root.inset

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            const g = root.grain
            const mid = Math.floor(root.cols / 2)

            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.14)
            ctx.fillRect((mid - 4) * g, 0, 9 * g, Math.max(1, Math.round(2 * root.designPx)))

            if (!root.grid) return

            for (let y = 0; y < root.rows; y++) {
                for (let x = 0; x < root.cols; x++) {
                    const v = root.grid[y * root.cols + x]
                    if (!v) continue
                    ctx.fillStyle = root.grainColors[v - 1]
                    ctx.globalAlpha = v === 1 ? 0.34 + (y / root.rows) * 0.5 : 0.9
                    ctx.fillRect(x * g, y * g, g - 1, g - 1)
                }
            }
            ctx.globalAlpha = 1
        }
    }
}
