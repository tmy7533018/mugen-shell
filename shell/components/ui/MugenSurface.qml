import QtQuick
import "../../lib" as Theme

Rectangle {
    id: surface

    property var theme
    property bool gradientEnabled: true

    // Must not read the effective `visible` here: under the Yura panel's mask it
    // is opacity-driven, which forms a binding loop.
    readonly property bool gradientsAnimating: gradientEnabled

    readonly property color darkBase: Qt.rgba(20/255, 22/255, 26/255, 0.82)
    readonly property color darkBorderColor: Qt.rgba(0.35, 0.35, 0.40, 0.40)

    readonly property color lightBase: Qt.rgba(0.50, 0.48, 0.58, 0.65)
    readonly property color lightBorderColor: Qt.rgba(0.50, 0.45, 0.65, 0.40)

    property color baseColor: (theme && theme.themeMode === "light") ? lightBase : darkBase
    property color borderColor: (theme && theme.themeMode === "light") ? lightBorderColor : darkBorderColor

    // Dims the sliding accent gradients in dark mode so they don't fight the deep base.
    property real gradientStrength: (theme && theme.themeMode === "dark") ? 0.75 : 1.0

    property color gradientColor1: Qt.rgba(0.65, 0.55, 0.85, 1.0)
    property color gradientColor2: Qt.rgba(0.45, 0.60, 0.90, 1.0)
    property color gradientColor3: Qt.rgba(0.75, 0.55, 0.80, 1.0)

    function enhanceColorForDark(baseColor, darkenFactor) {
        var darkened = Qt.darker(baseColor, darkenFactor);

        var h = darkened.hslHue;
        var s = Math.min(1.0, darkened.hslSaturation * 2.2);
        var l = Math.max(0.15, darkened.hslLightness);

        // Hue shift (~29deg) so the surface reads as distinct from the wallpaper
        h = (h + 0.08) % 1.0;

        return Qt.hsla(h, s, l, 1.0);
    }

    function enhanceColorForLight(baseColor) {
        var h = baseColor.hslHue;
        var s = Math.min(0.6, baseColor.hslSaturation * 1.5);
        var l = Math.min(0.5, baseColor.hslLightness * 0.7);

        // Hue shift (~29deg) so the surface reads as distinct from the wallpaper
        h = (h + 0.08) % 1.0;

        return Qt.hsla(h, s, l, 1.0);
    }

    function enhanceColor(baseColor) {
        if (theme && theme.themeMode === "light") {
            return enhanceColorForLight(baseColor)
        } else {
            return enhanceColorForDark(baseColor, 1.3)
        }
    }

    property color _cachedGradient1: enhanceColor(gradientColor1)
    property color _cachedGradient2: enhanceColor(gradientColor2)
    property color _cachedGradient3: enhanceColor(gradientColor3)

    function recalculateGradients() {
        _cachedGradient1 = enhanceColor(gradientColor1)
        _cachedGradient2 = enhanceColor(gradientColor2)
        _cachedGradient3 = enhanceColor(gradientColor3)
    }

    onGradientColor1Changed: {
        _cachedGradient1 = enhanceColor(gradientColor1)
    }
    onGradientColor2Changed: {
        _cachedGradient2 = enhanceColor(gradientColor2)
    }
    onGradientColor3Changed: {
        _cachedGradient3 = enhanceColor(gradientColor3)
    }

    onBaseColorChanged: {
        recalculateGradients()
    }

    onThemeChanged: {
        if (theme) {
            recalculateGradients()
        }
    }

    Connections {
        target: surface.theme
        enabled: surface.theme !== null
        function onThemeModeChanged() {
            surface.recalculateGradients()
        }
    }

    property color enhancedGradient1: _cachedGradient1
    property color enhancedGradient2: _cachedGradient2
    property color enhancedGradient3: _cachedGradient3

    function calculateStopOpacity(position, baseOpacity) {
        var scaled = baseOpacity * gradientStrength;

        if (position >= 0.0 && position <= 1.0) {
            return scaled;
        }

        var distance = position < 0.0 ? -position : position - 1.0;

        // 5.0 = 1/0.2, so the fade reaches fully transparent at 0.2 distance
        return distance > 0.2 ? 0.0 : scaled * (1.0 - distance * 5.0);
    }

    // Overshoots [0,1] on purpose: stops must keep sliding past the edge so
    // calculateStopOpacity can fade them out, which clamping to [0,1] prevents.
    function clampPosition(position) {
        return Math.max(-0.1, Math.min(1.1, position));
    }

    function calculateGradientVisibility(centerPosition, width) {
        var halfWidth = width * 0.5;
        var leftEdge = centerPosition - halfWidth;
        var rightEdge = centerPosition + halfWidth;

        if (rightEdge < -0.1 || leftEdge > 1.1) {
            return 0.0;
        }

        if (leftEdge >= -0.1 && rightEdge <= 1.1) {
            return 1.0;
        }

        var visibleWidth = Math.min(1.1, rightEdge) - Math.max(-0.1, leftEdge);
        return Math.max(0.0, Math.min(1.0, visibleWidth / width));
    }

    property real baseRadius: 24

    color: "transparent"
    radius: baseRadius
    border.width: 1
    border.color: borderColor

    Rectangle {
        id: baseLayer
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: surface.baseColor

        Behavior on color {
            ColorAnimation { duration: Theme.Motion.gentle; easing.type: Easing.InOutCubic }
        }
    }

    Behavior on borderColor {
        ColorAnimation { duration: Theme.Motion.gentle; easing.type: Easing.InOutCubic }
    }

    Rectangle {
        id: gradient1
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        visible: surface.gradientEnabled

        property real slidePosition: 0.0
        property real dynamicOpacity: 0.0

        property real visibilityFactor: surface.calculateGradientVisibility(gradient1.slidePosition, 0.5)

        opacity: dynamicOpacity * visibilityFactor

        SequentialAnimation on slidePosition {
            loops: Animation.Infinite
            running: surface.gradientsAnimating
            NumberAnimation {
                from: -0.3;
                to: 0.5;
                duration: 8500;
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.25, 0.1, 0.25, 1.0]
            }
            NumberAnimation {
                from: 0.5;
                to: -0.3;
                duration: 8500;
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.25, 0.1, 0.25, 1.0]
            }
        }

        SequentialAnimation on dynamicOpacity {
            loops: Animation.Infinite
            running: surface.gradientsAnimating
            PauseAnimation { duration: 500 }
            NumberAnimation { to: 1.0; duration: 1800; easing.type: Easing.InOutCubic }
            PauseAnimation { duration: 1200 }
            NumberAnimation { to: 0.0; duration: 1800; easing.type: Easing.InOutCubic }
        }

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: surface.clampPosition(gradient1.slidePosition - 0.15)
                color: "transparent"
            }

            GradientStop {
                position: surface.clampPosition(gradient1.slidePosition)
                color: Qt.rgba(
                    surface.enhancedGradient1.r,
                    surface.enhancedGradient1.g,
                    surface.enhancedGradient1.b,
                    surface.calculateStopOpacity(gradient1.slidePosition, 0.22)
                )
            }

            GradientStop {
                position: surface.clampPosition(gradient1.slidePosition + 0.12)
                color: Qt.rgba(
                    surface.enhancedGradient1.r * 0.75,
                    surface.enhancedGradient1.g * 0.75,
                    surface.enhancedGradient1.b * 0.75,
                    surface.calculateStopOpacity(gradient1.slidePosition + 0.12, 0.14)
                )
            }

            GradientStop {
                position: surface.clampPosition(gradient1.slidePosition + 0.15)
                color: Qt.rgba(
                    surface.enhancedGradient1.r * 0.5,
                    surface.enhancedGradient1.g * 0.5,
                    surface.enhancedGradient1.b * 0.5,
                    surface.calculateStopOpacity(gradient1.slidePosition + 0.15, 0.08)
                )
            }

            GradientStop {
                position: surface.clampPosition(gradient1.slidePosition + 0.35)
                color: "transparent"
            }
        }
    }

    Rectangle {
        id: gradient2
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        visible: surface.gradientEnabled

        property real slidePosition: 0.15
        property real dynamicOpacity: 0.0

        property real visibilityFactor: surface.calculateGradientVisibility(gradient2.slidePosition, 0.5)

        opacity: dynamicOpacity * visibilityFactor

        SequentialAnimation on slidePosition {
            loops: Animation.Infinite
            running: surface.gradientsAnimating
            NumberAnimation {
                from: -0.1;
                to: 0.4;
                duration: 9500;
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.42, 0, 0.58, 1]
            }
            NumberAnimation {
                from: 0.4;
                to: -0.1;
                duration: 9500;
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.42, 0, 0.58, 1]
            }
        }

        SequentialAnimation on dynamicOpacity {
            loops: Animation.Infinite
            running: surface.gradientsAnimating
            PauseAnimation { duration: 1750 }
            NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutCubic }
            PauseAnimation { duration: 1100 }
            NumberAnimation { to: 0.0; duration: 2000; easing.type: Easing.InOutCubic }
        }

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: surface.clampPosition(gradient2.slidePosition - 0.25)
                color: "transparent"
            }

            GradientStop {
                position: surface.clampPosition(gradient2.slidePosition - 0.1)
                color: Qt.rgba(
                    surface.enhancedGradient2.r * 0.6,
                    surface.enhancedGradient2.g * 0.6,
                    surface.enhancedGradient2.b * 0.6,
                    surface.calculateStopOpacity(gradient2.slidePosition - 0.1, 0.08)
                )
            }

            GradientStop {
                position: surface.clampPosition(gradient2.slidePosition)
                color: Qt.rgba(
                    surface.enhancedGradient2.r,
                    surface.enhancedGradient2.g,
                    surface.enhancedGradient2.b,
                    surface.calculateStopOpacity(gradient2.slidePosition, 0.24)
                )
            }

            GradientStop {
                position: surface.clampPosition(gradient2.slidePosition + 0.1)
                color: Qt.rgba(
                    surface.enhancedGradient2.r * 0.6,
                    surface.enhancedGradient2.g * 0.6,
                    surface.enhancedGradient2.b * 0.6,
                    surface.calculateStopOpacity(gradient2.slidePosition + 0.1, 0.08)
                )
            }

            GradientStop {
                position: surface.clampPosition(gradient2.slidePosition + 0.25)
                color: "transparent"
            }
        }

    }

    Rectangle {
        id: gradient3
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        visible: surface.gradientEnabled

        property real slidePosition: 0.85
        property real dynamicOpacity: 0.0

        property real visibilityFactor: surface.calculateGradientVisibility(gradient3.slidePosition, 0.5)

        opacity: dynamicOpacity * visibilityFactor

        SequentialAnimation on slidePosition {
            loops: Animation.Infinite
            running: surface.gradientsAnimating
            NumberAnimation {
                from: 1.1;
                to: 0.6;
                duration: 7500;
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.68, -0.55, 0.265, 1.55]
            }
            NumberAnimation {
                from: 0.6;
                to: 1.1;
                duration: 7500;
                easing.type: Easing.Bezier
                easing.bezierCurve: [0.68, -0.55, 0.265, 1.55]
            }
        }

        SequentialAnimation on dynamicOpacity {
            loops: Animation.Infinite
            running: surface.gradientsAnimating
            PauseAnimation { duration: 3000 }
            NumberAnimation { to: 1.0; duration: 2200; easing.type: Easing.InOutCubic }
            PauseAnimation { duration: 1300 }
            NumberAnimation { to: 0.0; duration: 2200; easing.type: Easing.InOutCubic }
        }

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: surface.clampPosition(gradient3.slidePosition - 0.25)
                color: "transparent"
            }

            GradientStop {
                position: surface.clampPosition(gradient3.slidePosition - 0.12)
                color: Qt.rgba(
                    surface.enhancedGradient3.r * 0.5,
                    surface.enhancedGradient3.g * 0.5,
                    surface.enhancedGradient3.b * 0.5,
                    surface.calculateStopOpacity(gradient3.slidePosition - 0.12, 0.06)
                )
            }

            GradientStop {
                position: surface.clampPosition(gradient3.slidePosition)
                color: Qt.rgba(
                    surface.enhancedGradient3.r,
                    surface.enhancedGradient3.g,
                    surface.enhancedGradient3.b,
                    surface.calculateStopOpacity(gradient3.slidePosition, 0.16)
                )
            }

            GradientStop {
                position: surface.clampPosition(gradient3.slidePosition + 0.12)
                color: Qt.rgba(
                    surface.enhancedGradient3.r * 0.5,
                    surface.enhancedGradient3.g * 0.5,
                    surface.enhancedGradient3.b * 0.5,
                    surface.calculateStopOpacity(gradient3.slidePosition + 0.12, 0.06)
                )
            }

            GradientStop {
                position: surface.clampPosition(gradient3.slidePosition + 0.25)
                color: "transparent"
            }
        }
    }
}
