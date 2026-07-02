import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

Item {
    id: brightnessContainer

    required property var theme
    required property var typo
    required property var modeManager
    required property var brightnessManager

    function scaled(v) { return modeManager ? modeManager.scale(v) : v }

    visible: brightnessManager && brightnessManager.isAvailable
    implicitWidth: visible ? scaled(24) : 0
    implicitHeight: scaled(24)
    Layout.alignment: Qt.AlignVCenter

    state: mouseArea.containsMouse ? "hovered" : "normal"

    states: [
        State {
            name: "normal"
            PropertyChanges { target: icon; opacity: 0.6; scale: 1.0 }
            PropertyChanges { target: percentText; opacity: 0; scale: 1.0 }
        },
        State {
            name: "hovered"
            PropertyChanges { target: icon; opacity: 0; scale: 0.8 }
            PropertyChanges { target: percentText; opacity: 1.0; scale: 1.3 }
        }
    ]

    transitions: Transition {
        PropertyAnimation { properties: "opacity,scale"; duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
    }

    Canvas {
        id: icon
        anchors.centerIn: parent
        width: scaled(20)
        height: scaled(20)

        property real animatedIntensity: brightnessManager ? brightnessManager.brightness / 100 : 0
        Behavior on animatedIntensity { NumberAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic } }

        onAnimatedIntensityChanged: requestPaint()
        onWidthChanged: requestPaint()
        Component.onCompleted: requestPaint()

        Connections {
            target: theme
            function onTextPrimaryChanged() { icon.requestPaint() }
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

    Text {
        id: percentText
        anchors.centerIn: parent
        text: brightnessManager ? brightnessManager.brightness : 0
        color: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        font.family: typo ? typo.clockStyle.family : "M PLUS 2"
        font.pixelSize: scaled(typo ? typo.clockStyle.size : 14)
        font.weight: typo ? typo.clockStyle.weight : Font.Normal
        font.letterSpacing: typo ? typo.clockStyle.letterSpacing : 0
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (modeManager) modeManager.switchMode("brightness", true)
    }
}
