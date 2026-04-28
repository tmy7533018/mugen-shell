import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import "../ui" as UI

Item {
    id: powerMenuRoot

    property var modeManager
    property var theme
    property var batteryManager
    property var settingsManager

    function scaled(val) {
        if (modeManager) return modeManager.scale(val)
        return val
    }

    implicitWidth: scaled(24)
    implicitHeight: scaled(24)

    signal clicked()
    signal rightClicked()

    property color accentColor: Qt.rgba(0.65, 0.55, 0.85, 0.9)
    property color textColor: Qt.rgba(0.92, 0.92, 0.96, 0.90)

    required property var icons

    readonly property bool batteryActive: settingsManager && settingsManager.batteryIndicatorEnabled
        && batteryManager && batteryManager.present

    readonly property color waterColor: {
        if (!batteryManager) return accentColor
        if (batteryManager.isCharging) {
            return theme && theme.glowPrimary
                ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.55)
                : Qt.rgba(0.55, 0.85, 1.0, 0.55)
        }
        if (batteryManager.percentage <= 20) {
            return Qt.rgba(0.95, 0.45, 0.50, 0.55)
        }
        return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.55)
    }

    Item {
        id: waterFill
        anchors.fill: parent
        visible: powerMenuRoot.batteryActive
        z: -1

        scale: mouseArea.pressed ? 0.9 : (mouseArea.containsMouse ? 1.3 : 1.0)
        Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

        Rectangle {
            id: waterMask
            anchors.centerIn: parent
            // Match the SVG circle dimensions: r=6.25, stroke=1.5 in viewBox 16
            // → outer diameter = 21 at icon size 24
            width: scaled(21)
            height: scaled(21)
            radius: width / 2
            antialiasing: true
            color: "white"
            visible: false
            layer.enabled: true
        }

        Item {
            id: waterClip
            anchors.fill: waterMask
            layer.enabled: true
            layer.effect: OpacityMask { maskSource: waterMask }

            property real currentLevel: powerMenuRoot.batteryManager
                ? powerMenuRoot.batteryManager.percentage / 100.0
                : 0
            Behavior on currentLevel {
                NumberAnimation { duration: 800; easing.type: Easing.OutCubic }
            }

            Canvas {
                id: waterCanvas
                anchors.fill: parent

                property real phase: 0

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width
                    const h = height
                    const level = waterClip.currentLevel
                    const top = h * (1.0 - level)
                    const amp = Math.min(1.5, h * 0.08)
                    const k = Math.PI * 2 / Math.max(1, w)

                    ctx.beginPath()
                    ctx.moveTo(0, top)
                    for (let x = 0; x <= w; x++) {
                        const y = top + Math.sin(x * k + phase) * amp
                        ctx.lineTo(x, y)
                    }
                    ctx.lineTo(w, h)
                    ctx.lineTo(0, h)
                    ctx.closePath()
                    ctx.fillStyle = powerMenuRoot.waterColor
                    ctx.fill()
                }

                Connections {
                    target: waterClip
                    function onCurrentLevelChanged() { waterCanvas.requestPaint() }
                }
            }

            Timer {
                interval: 50
                repeat: true
                running: waterFill.visible
                onTriggered: {
                    const speed = powerMenuRoot.batteryManager && powerMenuRoot.batteryManager.isCharging ? 0.25 : 0.08
                    waterCanvas.phase += speed
                    waterCanvas.requestPaint()
                }
            }
        }
    }

    // When the battery indicator is active we draw the outline ourselves so it
    // shares Qt's Rectangle anti-aliasing pipeline with the water mask, keeping
    // them sub-pixel aligned. Otherwise fall back to the SVG icon.
    Rectangle {
        id: batteryOutline
        visible: powerMenuRoot.batteryActive
        anchors.centerIn: parent
        // Match the SVG circle: viewBox 16, r=6.25, stroke=1.5 → at size 24
        // outer diameter is 21 and stroke width is 2.25.
        width: scaled(21)
        height: scaled(21)
        radius: width / 2
        color: "transparent"
        border.color: powerMenuRoot.textColor
        border.width: scaled(2.25)
        antialiasing: true
        opacity: mouseArea.containsMouse ? 1.0 : 0.6
        scale: mouseArea.pressed ? 0.9 : (mouseArea.containsMouse ? 1.3 : 1.0)

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }
    }

    UI.SvgIcon {
        id: menuIconSvg
        anchors.centerIn: parent
        width: scaled(24)
        height: scaled(24)
        source: icons.iconData.menu.type === "svg" ? icons.iconData.menu.value : ""
        color: textColor
        opacity: mouseArea.containsMouse ? 1.0 : 0.6
        scale: mouseArea.pressed ? 0.9 : (mouseArea.containsMouse ? 1.3 : 1.0)
        visible: !powerMenuRoot.batteryActive && icons.iconData.menu.type === "svg"

        Behavior on opacity {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 600
                easing.type: Easing.OutCubic
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: icons.iconData.menu.type === "text" ? icons.iconData.menu.value : ""
        font.pixelSize: scaled(20)
        color: textColor
        visible: icons.iconData.menu.type === "text"
        opacity: mouseArea.containsMouse ? 1.0 : 0.6
        scale: mouseArea.pressed ? 0.9 : (mouseArea.containsMouse ? 1.3 : 1.0)

        Behavior on opacity {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 600
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                powerMenuRoot.rightClicked()
            } else {
                powerMenuRoot.clicked()
            }
        }
    }
}
