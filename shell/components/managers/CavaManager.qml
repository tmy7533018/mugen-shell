import QtQuick
import Mugen.Audio

QtObject {
    id: cavaManager

    // "speaker" reads the default sink's monitor, "mic" reads the default source.
    property string source: "speaker"
    property bool isActive: false

    readonly property alias barLevels: cavaSource.barLevels
    readonly property alias audioLevel: cavaSource.audioLevel
    readonly property alias rms: cavaSource.rms

    // Draining through cava's fall-off, not a cut to zero, matches an always-on one.
    property Timer drainTimer: Timer { interval: 700 }

    onIsActiveChanged: if (!isActive) drainTimer.restart()

    property CavaSource cavaSource: CavaSource {
        id: cavaSource
        bars: 16
        active: cavaManager.isActive || cavaManager.drainTimer.running
        source: cavaManager.source === "mic" ? "auto_input" : "auto"
    }

    function start() {
        if (!isActive) isActive = true
    }

    function stop() {
        if (isActive) isActive = false
    }
}
