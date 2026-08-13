import QtQuick
import Quickshell
import Qt5Compat.GraphicalEffects

// The brand mark, assembled from the parts of the logo so each can move on its
// own. Timings and easings are the "2c" variant of the design's animation study.
Item {
    id: mark

    property bool animated: true
    property int startDelay: 500

    // Everything below is authored in the logo's own 200-unit space.
    readonly property real k: width / 200
    readonly property string assets: Quickshell.shellDir + "/assets/branding/"

    // Every animation carries an explicit `from`, or a replay resumes from wherever it ended.
    signal replay()
    signal settle()

    implicitWidth: 168
    implicitHeight: 168
    height: width

    function play() {
        entrance.stop()
        if (mark.animated) {
            // Back to the first frame before the lead-in, or a replay holds the finished mark.
            tile.opacity = 0
            shine.opacity = 0
            moon.turn = -34; moon.grow = 0.9; moon.opacity = 0
            cluster.turn = -34; cluster.grow = 0.86
            mark.replay()
            entrance.start()
        } else {
            tile.opacity = 1
            shine.opacity = 0
            moon.turn = 0; moon.grow = 1; moon.opacity = 1
            cluster.turn = 0; cluster.grow = 1
            mark.settle()
        }
    }

    Component.onCompleted: play()

    Item {
        id: tile
        anchors.fill: parent
        opacity: 0

        Image {
            id: tileArt
            anchors.fill: parent
            sourceSize.width: mark.width * 2
            sourceSize.height: mark.height * 2
            source: mark.assets + "logo-tile.svg"
            smooth: true
        }

        // An Image declared inline as maskSource is never rendered, so the mask comes out square.
        Image {
            id: tileMask
            anchors.fill: parent
            sourceSize.width: mark.width * 2
            sourceSize.height: mark.height * 2
            source: mark.assets + "logo-tile.svg"
            smooth: true
            visible: false
            layer.enabled: true
        }

        // Masked by the tile so the sweep keeps the rounded corners.
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask { maskSource: tileMask }

            Rectangle {
                id: shine
                width: 44 * mark.k
                height: 300 * mark.k
                x: -80 * mark.k
                y: -50 * mark.k
                opacity: 0
                rotation: 16
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#00ffffff" }
                    GradientStop { position: 0.5; color: "#80ffffff" }
                    GradientStop { position: 1.0; color: "#00ffffff" }
                }
            }
        }
    }

    Image {
        id: moon
        anchors.fill: parent
        sourceSize.width: mark.width * 2
        sourceSize.height: mark.height * 2
        source: mark.assets + "logo-moon.svg"
        smooth: true
        opacity: 0

        property real turn: -34
        property real grow: 0.9

        transform: [
            Rotation { origin.x: 105 * mark.k; origin.y: 97 * mark.k; angle: moon.turn },
            Scale {
                origin.x: 105 * mark.k; origin.y: 97 * mark.k
                xScale: moon.grow; yScale: moon.grow
            }
        ]
    }

    Item {
        id: cluster
        anchors.fill: parent

        property real turn: -34
        property real grow: 0.86

        transform: [
            Rotation { origin.x: 123 * mark.k; origin.y: 95 * mark.k; angle: cluster.turn },
            Scale {
                origin.x: 123 * mark.k; origin.y: 95 * mark.k
                xScale: cluster.grow; yScale: cluster.grow
            }
        ]

        Repeater {
            model: 5

            Image {
                id: petal
                required property int index
                anchors.fill: parent
                sourceSize.width: mark.width * 2
                sourceSize.height: mark.height * 2
                source: mark.assets + "logo-petal-" + index + ".svg"
                smooth: true
                opacity: 0

                property real grow: 0.28

                // Every petal is drawn from the cluster centre, so they all scale about it.
                transform: Scale {
                    origin.x: 123 * mark.k; origin.y: 95 * mark.k
                    xScale: petal.grow; yScale: petal.grow
                }

                SequentialAnimation {
                    id: bloom
                    PauseAnimation { duration: mark.startDelay + 600 + 150 * petal.index }
                    ParallelAnimation {
                        NumberAnimation {
                            target: petal; property: "grow"; from: 0.28; to: 1.0; duration: 780
                            easing.type: Easing.Bezier
                            easing.bezierCurve: [0.16, 0.84, 0.3, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: petal; property: "opacity"; from: 0.0; to: 1.0; duration: 780
                            easing.type: Easing.Bezier
                            easing.bezierCurve: [0.16, 0.84, 0.3, 1, 1, 1]
                        }
                    }
                }

                Connections {
                    target: mark
                    function onReplay() {
                        petal.grow = 0.28
                        petal.opacity = 0
                        bloom.restart()
                    }
                    function onSettle() {
                        bloom.stop()
                        petal.grow = 1.0
                        petal.opacity = 1.0
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: entrance

        // The plate is there from the first frame; only what sits on it waits.
        NumberAnimation {
            target: tile; property: "opacity"; from: 0.0; to: 1.0; duration: 700
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            PauseAnimation { duration: mark.startDelay }

            ParallelAnimation {
                SequentialAnimation {
                    PauseAnimation { duration: 300 }
                    ParallelAnimation {
                        NumberAnimation {
                            target: shine; property: "x"
                            from: -80 * mark.k; to: 220 * mark.k; duration: 1400
                            easing.type: Easing.Bezier
                            easing.bezierCurve: [0.4, 0, 0.4, 1, 1, 1]
                        }
                        SequentialAnimation {
                            NumberAnimation { target: shine; property: "opacity"; from: 0.0; to: 1.0; duration: 308 }
                            NumberAnimation { target: shine; property: "opacity"; to: 0.0; duration: 1092 }
                        }
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: moon; property: "turn"; from: -34; to: 0; duration: 1200
                        easing.type: Easing.Bezier
                        easing.bezierCurve: [0.2, 0.9, 0.25, 1, 1, 1]
                    }
                    NumberAnimation {
                        target: moon; property: "grow"; from: 0.9; to: 1.0; duration: 1200
                        easing.type: Easing.Bezier
                        easing.bezierCurve: [0.2, 0.9, 0.25, 1, 1, 1]
                    }
                    NumberAnimation {
                        target: moon; property: "opacity"; from: 0.0; to: 1.0; duration: 1200
                        easing.type: Easing.Bezier
                        easing.bezierCurve: [0.2, 0.9, 0.25, 1, 1, 1]
                    }
                }

                SequentialAnimation {
                    PauseAnimation { duration: 500 }
                    ParallelAnimation {
                        NumberAnimation {
                            target: cluster; property: "turn"; from: -34; to: 0; duration: 1400
                            easing.type: Easing.Bezier
                            easing.bezierCurve: [0.18, 0.9, 0.24, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: cluster; property: "grow"; from: 0.86; to: 1.0; duration: 1400
                            easing.type: Easing.Bezier
                            easing.bezierCurve: [0.18, 0.9, 0.24, 1, 1, 1]
                        }
                    }
                }
            }
        }
    }
}
