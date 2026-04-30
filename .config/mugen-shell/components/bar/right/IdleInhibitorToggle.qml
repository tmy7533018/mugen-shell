import QtQuick
import QtQuick.Layouts
import "../../common" as Common

Common.IconButton {
    id: idleToggleButton

    required property var theme
    required property var icons
    required property var modeManager
    required property var idleInhibitorManager
    required property real spacing

    function scaled(v) { return modeManager ? modeManager.scale(v) : v }

    Layout.alignment: Qt.AlignVCenter
    Layout.leftMargin: spacing
    modeManager: idleToggleButton.modeManager
    iconSize: scaled(24)
    opacityDuration: 150

    property bool isBlinking: false
    readonly property color accentColorBase: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
    readonly property real hueShift: 0.2
    readonly property real brightnessBoost: 0.25
    readonly property color accentLightColor: {
        let h = accentColorBase.hsvHue
        let s = accentColorBase.hsvSaturation
        let v = accentColorBase.hsvValue
        let a = accentColorBase.a

        let shiftedH = (h + hueShift) % 1.0
        let finalV = Math.min(1.0, v + brightnessBoost)

        return Qt.hsva(shiftedH, s, finalV, a)
    }
    iconSource: {
        if (!idleToggleButton.icons || !idleToggleButton.idleInhibitorManager) return ""
        if (isBlinking) {
            return idleToggleButton.icons.iconData.eyeClosed.value
        }
        return idleToggleButton.idleInhibitorManager.isInhibited
                ? idleToggleButton.icons.iconData.eyeOpen.value
                : idleToggleButton.icons.iconData.eyeClosed.value
    }
    iconColor: idleToggleButton.idleInhibitorManager && idleToggleButton.idleInhibitorManager.isInhibited
        ? accentLightColor
        : (idleToggleButton.theme ? idleToggleButton.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))

    property bool blinkTwice: false

    function startBlink() {
        if (idleToggleButton.blinkTwice) {
            idleBlinkAnimationDouble.start()
        } else {
            idleBlinkAnimationSingle.start()
        }
    }

    Timer {
        id: idleBlinkTimer
        interval: 7000
        running: idleToggleButton.idleInhibitorManager && idleToggleButton.idleInhibitorManager.isInhibited
        repeat: true
        onRunningChanged: {
            if (running) {
                interval = 6000 + Math.random() * 5000
            }
        }
        onTriggered: {
            interval = 6000 + Math.random() * 5000
            idleToggleButton.blinkTwice = Math.random() < 0.5
            if (idleToggleButton.idleInhibitorManager && idleToggleButton.idleInhibitorManager.isInhibited && !idleBlinkAnimationSingle.running && !idleBlinkAnimationDouble.running) {
                idleToggleButton.startBlink()
            }
        }
    }

    Component.onCompleted: {
        if (idleToggleButton.idleInhibitorManager && idleToggleButton.idleInhibitorManager.isInhibited) {
            idleBlinkTimer.interval = 6000 + Math.random() * 5000
        }
    }

    SequentialAnimation {
        id: idleBlinkAnimationSingle
        running: false
        PropertyAction {
            target: idleToggleButton
            property: "isBlinking"
            value: true
        }
        PauseAnimation { duration: 150 }
        PropertyAction {
            target: idleToggleButton
            property: "isBlinking"
            value: false
        }
    }

    SequentialAnimation {
        id: idleBlinkAnimationDouble
        running: false
        PropertyAction {
            target: idleToggleButton
            property: "isBlinking"
            value: true
        }
        PauseAnimation { duration: 150 }
        PropertyAction {
            target: idleToggleButton
            property: "isBlinking"
            value: false
        }
        PauseAnimation { duration: 100 }
        PropertyAction {
            target: idleToggleButton
            property: "isBlinking"
            value: true
        }
        PauseAnimation { duration: 150 }
        PropertyAction {
            target: idleToggleButton
            property: "isBlinking"
            value: false
        }
    }

    Connections {
        target: idleToggleButton.idleInhibitorManager
        function onIsInhibitedChanged() {
            if (!idleToggleButton.idleInhibitorManager || !idleToggleButton.idleInhibitorManager.isInhibited) {
                idleBlinkAnimationSingle.stop()
                idleBlinkAnimationDouble.stop()
                idleToggleButton.isBlinking = false
            } else {
                idleBlinkTimer.interval = 6000 + Math.random() * 5000
            }
        }
    }

    onClicked: {
        if (idleToggleButton.idleInhibitorManager) {
            idleToggleButton.idleInhibitorManager.toggle()
        }
    }

    onRightClicked: {
        if (idleToggleButton.idleInhibitorManager) {
            idleToggleButton.idleInhibitorManager.refreshStatus()
        }
    }
}
