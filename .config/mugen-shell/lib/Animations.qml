import QtQuick

QtObject {
    id: animations

    readonly property int durationInstant: 0
    readonly property int durationFastest: 150
    readonly property int durationFast: 200
    readonly property int durationQuick: 300
    readonly property int durationNormal: 400
    readonly property int durationSlow: 600
    readonly property int durationSlower: 800
    readonly property int durationSlowest: 1000

    readonly property int easingLinear: Easing.Linear
    readonly property int easingInCubic: Easing.InCubic
    readonly property int easingOutCubic: Easing.OutCubic
    readonly property int easingInOutCubic: Easing.InOutCubic
    readonly property int easingInQuad: Easing.InQuad
    readonly property int easingOutQuad: Easing.OutQuad
    readonly property int easingInOutQuad: Easing.InOutQuad
    readonly property int easingInSine: Easing.InSine
    readonly property int easingOutSine: Easing.OutSine
    readonly property int easingInOutSine: Easing.InOutSine
    readonly property int easingOutExpo: Easing.OutExpo
    readonly property int easingOutBack: Easing.OutBack
    readonly property int easingOutElastic: Easing.OutElastic

    readonly property var fade: QtObject {
        property int duration: animations.durationNormal
        property int easing: animations.easingOutCubic
    }
    
    readonly property var hover: QtObject {
        property int opacityDuration: animations.durationNormal
        property int scaleDuration: animations.durationSlow
        property int easing: animations.easingOutCubic
    }
    
    readonly property var scale: QtObject {
        property int duration: animations.durationSlow
        property int easing: animations.easingOutCubic
    }
    
    readonly property var color: QtObject {
        property int duration: animations.durationNormal
        property int easing: animations.easingOutCubic
    }
    
    readonly property var modeSwitch: QtObject {
        property int duration: animations.durationSlowest
        property int easing: animations.easingOutExpo
    }
    
    readonly property var quick: QtObject {
        property int duration: animations.durationQuick
        property int easing: animations.easingOutCubic
    }

    Component.onCompleted: {
    }
}

