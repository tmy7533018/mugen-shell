pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import "../content" as Content

LockBox {
    id: root

    property real cellH: 0
    property string faceFontFamily: "M PLUS 2"
    property color clockColor: "#f2f3ff"
    property color subtleColor: Qt.rgba(235 / 255, 238 / 255, 1, 0.55)
    property color accentColor: "#a68cd9"
    property bool reduceMotion: false
    property bool uiVisible: false

    property var weatherPalette: null

    property string weatherIconSource: ""
    property string weatherText: ""
    property string weatherHighLow: ""
    property string weatherCondition: ""
    property string weatherLocation: ""
    property string weatherParticleType: "clouds"
    property real weatherWind: 0

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.weatherPalette ? root.weatherPalette.bg2 : "transparent"
            }
            GradientStop {
                position: 0.55
                color: root.weatherPalette ? root.weatherPalette.bg1 : "transparent"
            }
            GradientStop {
                position: 1
                color: root.weatherPalette ? root.weatherPalette.bg3 : "transparent"
            }
        }
        opacity: root.weatherPalette ? 0.65 : 0

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
        }
    }

    Rectangle {
        id: weatherMask
        anchors.fill: parent
        radius: root.cornerRadius
        color: "white"
        antialiasing: true
        visible: false
        layer.enabled: true
    }

    Content.WeatherParticles {
        anchors.fill: parent
        wtype: root.weatherParticleType
        windKmh: root.weatherWind
        tint: root.weatherPalette ? root.weatherPalette.accent : root.accentColor
        // A ParticleSystem does not stop just because its surface is hidden.
        active: !root.reduceMotion && root.uiVisible
        layer.enabled: true
        layer.effect: OpacityMask { maskSource: weatherMask }
    }

    LockWeatherBox {
        anchors.fill: parent
        anchors.margins: root.cellH * 0.2
        fontFamily: root.faceFontFamily
        tint: root.clockColor
        faintTint: root.subtleColor
        unit: Math.round(root.cellH * 0.2)
        iconSource: root.weatherIconSource
        temperature: root.weatherText
        highLow: root.weatherHighLow
        condition: root.weatherCondition
        location: root.weatherLocation
    }
}
