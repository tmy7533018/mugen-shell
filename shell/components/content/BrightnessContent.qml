import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import "../common" as Common
import "../../lib" as Theme

Item {
    id: root

    required property var modeManager
    required property var brightnessManager
    required property var theme
    required property var typo

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(60),
        "leftMargin": modeManager.scale(800),
        "rightMargin": modeManager.scale(800),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })

    readonly property int currentBrightness: brightnessManager ? brightnessManager.brightness : 0

    Connections {
        target: brightnessManager
        function onUserChanged() {
            if (modeManager.isMode("brightness")) startChangeTimer()
        }
    }

    function setCurrent(v) {
        if (brightnessManager) brightnessManager.setBrightness(v)
    }

    Component.onCompleted: modeManager.registerMode("brightness", root)

    Timer {
        id: changeTimer
        interval: 2000
        repeat: false
        onTriggered: if (modeManager.isMode("brightness")) modeManager.closeAllModes()
    }

    function resetAutoClose() {
        if (modeManager.isMode("brightness")) {
            modeManager.bump()
            changeTimer.stop()
        }
    }

    function startChangeTimer() {
        if (modeManager.isMode("brightness")) changeTimer.restart()
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (!modeManager.isMode("brightness")) changeTimer.stop()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 1
        enabled: modeManager.isMode("brightness")
        visible: enabled
        hoverEnabled: true
        onClicked: modeManager.closeAllModes()
        onPositionChanged: if (modeManager.isMode("brightness")) modeManager.bump()
    }

    Item {
        id: contentLayer
        anchors.fill: parent
        z: 2

        opacity: 0
        visible: opacity > 0.01

        states: State {
            name: "visible"
            when: modeManager.isMode("brightness")
            PropertyChanges { target: contentLayer; opacity: 1.0 }
        }

        transitions: [
            Transition {
                from: "visible"
                to: ""
                NumberAnimation { property: "opacity"; duration: Theme.Motion.fast; easing.type: Easing.InOutQuad }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: Theme.Motion.fast }
                    NumberAnimation { property: "opacity"; duration: 350; easing.type: Easing.InOutCubic }
                }
            }
        ]

        Item {
            id: row
            anchors.centerIn: parent
            width: modeManager.scale(280)
            height: modeManager.scale(38)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: modeManager.scale(16)
                anchors.rightMargin: modeManager.scale(16)
                spacing: modeManager.scale(12)

                Canvas {
                    id: sunIcon
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: modeManager.scale(20)
                    Layout.preferredHeight: modeManager.scale(20)
                    width: modeManager.scale(20)
                    height: width

                    property real animatedIntensity: root.currentBrightness / 100
                    Behavior on animatedIntensity { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }

                    onAnimatedIntensityChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    Component.onCompleted: requestPaint()

                    Connections {
                        target: theme
                        function onTextPrimaryChanged() { sunIcon.requestPaint() }
                    }

                    onPaint: {
                        let ctx = getContext("2d")
                        ctx.reset()
                        let cx = width / 2
                        let cy = height / 2
                        let coreR = width * 0.20
                        let rayInner = width * 0.32
                        let rayOuter = width * 0.32 + width * 0.16 * animatedIntensity
                        let rayWidth = width * 0.08
                        let col = theme ? theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)

                        ctx.fillStyle = col
                        ctx.beginPath()
                        ctx.arc(cx, cy, coreR, 0, Math.PI * 2)
                        ctx.fill()

                        if (animatedIntensity > 0.01) {
                            ctx.globalAlpha = animatedIntensity
                            ctx.lineWidth = rayWidth
                            ctx.lineCap = "round"
                            ctx.strokeStyle = col
                            for (let i = 0; i < 8; i++) {
                                let a = i * Math.PI / 4
                                let sx = cx + Math.cos(a) * rayInner
                                let sy = cy + Math.sin(a) * rayInner
                                let ex = cx + Math.cos(a) * rayOuter
                                let ey = cy + Math.sin(a) * rayOuter
                                ctx.beginPath()
                                ctx.moveTo(sx, sy)
                                ctx.lineTo(ex, ey)
                                ctx.stroke()
                            }
                        }
                    }
                }

                Item {
                    id: slider
                    Layout.fillWidth: true
                    Layout.preferredHeight: modeManager.scale(14)
                    Layout.alignment: Qt.AlignVCenter

                    readonly property real ratio: root.currentBrightness / 100

                    function valueAt(x) {
                        const w = Math.max(1, width)
                        const r = Math.max(0, Math.min(1, x / w))
                        return Math.round(r * 100)
                    }

                    Rectangle {
                        id: track
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: modeManager.scale(3)
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, sliderMouse.containsMouse || sliderMouse.pressed ? 0.22 : 0.15)
                        Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

                        Rectangle {
                            id: filled
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * slider.ratio
                            radius: parent.radius
                            color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55)

                            layer.enabled: true
                            layer.effect: Glow {
                                samples: 32
                                radius: 14
                                spread: 0.5
                                color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.55) : Qt.rgba(0.65, 0.55, 0.85, 0.55)
                                transparentBorder: true
                            }

                            Behavior on width {
                                enabled: !sliderMouse.pressed
                                NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    MouseArea {
                        id: sliderMouse
                        anchors.fill: parent
                        anchors.margins: -modeManager.scale(6)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true

                        onPressed: (m) => {
                            root.setCurrent(slider.valueAt(m.x + sliderMouse.x))
                            root.resetAutoClose()
                        }
                        onPositionChanged: (m) => {
                            if (pressed) {
                                root.setCurrent(slider.valueAt(m.x + sliderMouse.x))
                                root.resetAutoClose()
                            }
                        }
                        onReleased: root.startChangeTimer()
                        onWheel: (w) => {
                            let delta = w.angleDelta.y > 0 ? 2 : -2
                            root.setCurrent(root.currentBrightness + delta)
                            root.startChangeTimer()
                        }
                    }
                }

                Text {
                    Layout.preferredWidth: modeManager.scale(40)
                    Layout.alignment: Qt.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                    text: root.currentBrightness + "%"
                    color: theme ? theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                    font.family: typo.fontFamily
                    font.pixelSize: modeManager.scale(13)
                    font.weight: typo.weightLight
                }
            }
        }
    }
}
