import QtQuick
import Qt5Compat.GraphicalEffects

Row {
    id: root

    property var typo
    property color tint: "white"
    property string iconsBase: ""
    property real unit: 13

    // Layouts that split the corners need the same row twice, showing one half
    // each, rather than a second component that drifts from this one.
    property bool showWeather: true
    property bool showSystem: true

    property bool weatherReady: false
    property string weatherText: ""

    property bool wifiAvailable: false
    property bool wifiConnected: false
    property string ssid: ""
    property real ssidMaxWidth: 200

    property bool batteryPresent: false
    property int batteryPercent: 0

    spacing: unit * 2.1

    Row {
        spacing: root.unit * 0.55
        visible: root.showWeather && root.weatherReady
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            width: root.unit * 0.75
            height: width
            radius: width / 2
            color: "#f0b27f"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.weatherText
            color: root.tint
            font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
            font.pixelSize: root.unit
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        spacing: root.unit * 0.55
        visible: root.showSystem && root.wifiAvailable
        opacity: root.wifiConnected ? 1 : 0.35
        anchors.verticalCenter: parent.verticalCenter

        Item {
            width: root.unit * 1.3
            height: root.unit
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: wifiGlyph
                anchors.fill: parent
                source: root.iconsBase
                    + (root.wifiConnected ? "/wifi.svg" : "/wifi-off.svg")
                sourceSize.width: width
                sourceSize.height: height
                visible: false
            }

            ColorOverlay {
                anchors.fill: wifiGlyph
                source: wifiGlyph
                color: root.tint
            }
        }

        Text {
            text: root.ssid
            color: root.tint
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.ssidMaxWidth)
            font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
            font.pixelSize: root.unit
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        spacing: root.unit * 0.55
        visible: root.showSystem && root.batteryPresent
        anchors.verticalCenter: parent.verticalCenter

        Item {
            width: root.unit * 1.7
            height: root.unit * 0.85
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: batteryBody
                width: root.unit * 1.55
                height: parent.height
                radius: root.unit * 0.23
                color: "transparent"
                border.width: Math.max(1, root.unit * 0.11)
                border.color: root.tint
            }

            Rectangle {
                anchors.verticalCenter: batteryBody.verticalCenter
                x: root.unit * 0.19
                width: Math.max(1, (root.unit * 1.16) * (root.batteryPercent / 100))
                height: root.unit * 0.46
                radius: root.unit * 0.11
                color: root.tint
            }

            Rectangle {
                anchors.verticalCenter: batteryBody.verticalCenter
                x: batteryBody.width + root.unit * 0.04
                width: root.unit * 0.15
                height: root.unit * 0.38
                radius: root.unit * 0.08
                color: root.tint
            }
        }

        Text {
            text: root.batteryPercent + "%"
            color: root.tint
            font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
            font.pixelSize: root.unit
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
