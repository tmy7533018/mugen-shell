import QtQuick
import "../../lib" as Theme

Rectangle {
    id: surface

    property var theme

    readonly property color darkBase: Qt.rgba(20/255, 22/255, 26/255, 0.82)
    readonly property color darkBorderColor: Qt.rgba(0.35, 0.35, 0.40, 0.40)

    readonly property color lightBase: Qt.rgba(0.50, 0.48, 0.58, 0.65)
    readonly property color lightBorderColor: Qt.rgba(0.50, 0.45, 0.65, 0.40)

    property color baseColor: (theme && theme.themeMode === "light") ? lightBase : darkBase
    property color borderColor: (theme && theme.themeMode === "light") ? lightBorderColor : darkBorderColor

    property real baseRadius: 24

    // Stacked translucent layers trend opaque and swing mid-fade; pinning the pair to baseColor.a keeps the blur behind steady.
    function baseOpacityUnder(backdropOpacity) {
        var a = baseColor.a;
        var throughBackdrop = 1.0 - a * backdropOpacity;

        return a > 0 && throughBackdrop > 0 ? (1.0 - (1.0 - a) / throughBackdrop) / a : 0.0;
    }

    color: "transparent"
    radius: baseRadius
    border.width: 1
    border.color: borderColor

    Behavior on borderColor {
        ColorAnimation { duration: Theme.Motion.gentle; easing.type: Easing.InOutCubic }
    }

    Rectangle {
        id: baseLayer
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: surface.baseColor
        opacity: surface.baseOpacityUnder(moduleBackgroundLoader.opacity)

        Behavior on color {
            ColorAnimation { duration: Theme.Motion.gentle; easing.type: Easing.InOutCubic }
        }
    }

    property Component moduleBackground: null
    property var moduleContext: null
    property real backdropSpread: 0.06
    property real backdropAlpha: baseColor.a

    Loader {
        id: moduleBackgroundLoader
        anchors.fill: parent
        anchors.margins: 1
        // Binding sourceComponent straight to moduleBackground destroys the item before the fade can run.
        property Component shown: null
        sourceComponent: shown
        opacity: surface.moduleBackground ? 1 : 0

        Behavior on opacity {
            enabled: moduleBackgroundLoader.opacity < 1
            NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.InOutCubic }
        }

        onOpacityChanged: {
            if (opacity === 0 && !surface.moduleBackground) {
                moduleBackgroundLoader.shown = null
            }
        }

        Connections {
            target: surface
            function onModuleBackgroundChanged() {
                if (surface.moduleBackground) {
                    moduleBackgroundLoader.shown = surface.moduleBackground
                }
            }
        }

        Component.onCompleted: if (surface.moduleBackground) shown = surface.moduleBackground
    }

    Binding {
        target: moduleBackgroundLoader.item
        property: "surfaceRadius"
        value: surface.radius - 1
        when: moduleBackgroundLoader.item !== null
    }

    Binding {
        target: moduleBackgroundLoader.item
        property: "faceAlpha"
        value: surface.backdropAlpha
        when: moduleBackgroundLoader.item !== null
    }

    Binding {
        target: moduleBackgroundLoader.item
        property: "spread"
        value: surface.backdropSpread
        when: moduleBackgroundLoader.item !== null
    }

    Binding {
        target: moduleBackgroundLoader.item
        property: "moduleContext"
        value: surface.moduleContext
        when: moduleBackgroundLoader.item !== null
    }
}
