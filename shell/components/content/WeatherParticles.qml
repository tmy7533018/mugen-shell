import QtQuick
import QtQuick.Particles
import Quickshell

Item {
    id: root

    property string wtype: "clouds"
    property real windKmh: 0
    property color tint: "#9fb4ff"
    property bool active: true

    readonly property bool rainOn: active && (wtype === "rain" || wtype === "thunder")
    readonly property bool snowOn: active && wtype === "snow"
    readonly property bool windOn: active && windKmh >= 20
    readonly property bool flashOn: active && wtype === "thunder"

    ParticleSystem {
        id: sys
        running: root.rainOn || root.snowOn || root.windOn
    }

    ImageParticle {
        system: sys
        groups: ["rain"]
        source: Quickshell.shellDir + "/assets/icons/particle-rain.svg"
        color: root.tint
        alpha: 0.12
        alphaVariation: 0.05
        rotation: -6
    }
    Emitter {
        system: sys
        group: "rain"
        enabled: root.rainOn
        x: 0; y: -24
        width: parent.width; height: 1
        emitRate: 32
        lifeSpan: 1500
        size: 22; sizeVariation: 6
        velocity: PointDirection { x: -24; y: root.height * 0.85; yVariation: root.height * 0.2 }
    }

    ImageParticle {
        system: sys
        groups: ["snow"]
        source: Quickshell.shellDir + "/assets/icons/particle-snow.svg"
        color: root.tint
        alpha: 0.5
        alphaVariation: 0.2
    }
    Emitter {
        system: sys
        group: "snow"
        enabled: root.snowOn
        x: 0; y: -12
        width: parent.width; height: 1
        emitRate: 12
        lifeSpan: 9000
        size: 10; sizeVariation: 5
        velocity: PointDirection { y: root.height / 7; yVariation: root.height / 18; xVariation: 20 }
    }
    Wander {
        system: sys
        groups: ["snow"]
        xVariance: 60
        pace: 40
    }

    ImageParticle {
        system: sys
        groups: ["wind"]
        source: Quickshell.shellDir + "/assets/icons/particle-wind.svg"
        color: root.tint
        alpha: 0.09
        alphaVariation: 0.04
    }
    Emitter {
        system: sys
        group: "wind"
        enabled: root.windOn
        x: -28; y: 0
        width: 1; height: parent.height
        emitRate: 9
        lifeSpan: 1100
        size: 30; sizeVariation: 10
        velocity: PointDirection { x: root.width * 1.1; xVariation: root.width * 0.25 }
    }

    Rectangle {
        id: flash
        anchors.fill: parent
        color: "#ffffff"
        opacity: 0
        visible: root.flashOn
    }
    SequentialAnimation {
        id: flashAnim
        NumberAnimation { target: flash; property: "opacity"; to: 0.2; duration: 60 }
        NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 140 }
        PauseAnimation { duration: 110 }
        NumberAnimation { target: flash; property: "opacity"; to: 0.11; duration: 50 }
        NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 260 }
    }
    Timer {
        running: root.flashOn
        repeat: true
        interval: 3500 + Math.random() * 6000
        onTriggered: {
            interval = 3500 + Math.random() * 6000
            flashAnim.restart()
        }
    }
}
