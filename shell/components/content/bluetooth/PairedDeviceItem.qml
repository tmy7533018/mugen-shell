import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../../ui" as UI

Rectangle {
    id: deviceItem

    required property var modelData
    required property int index
    required property var theme
    required property var icons
    required property var modeManager
    required property var bluetoothManager
    required property int connectingDeviceIndex

    signal connectRequested()

    height: 60
    color: deviceMouseArea.containsMouse
        ? (theme ? theme.surfaceInsetCardHover : Qt.rgba(0, 0, 0, 0.75))
        : (theme ? theme.surfaceInsetCard : Qt.rgba(0, 0, 0, 0.65))
    radius: height / 2
    border.width: 0

    layer.enabled: true
    layer.effect: Glow {
        samples: 12
        radius: 6
        spread: 0.3
        color: deviceItem.theme ? Qt.rgba(deviceItem.theme.glowPrimary.r, deviceItem.theme.glowPrimary.g, deviceItem.theme.glowPrimary.b, 0.15) : Qt.rgba(0.65, 0.55, 0.85, 0.15)
        transparentBorder: true
    }

    Behavior on color {
        ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: deviceItem.modeManager ? deviceItem.modeManager.scale(20) : 20
        anchors.rightMargin: deviceItem.modeManager ? deviceItem.modeManager.scale(20) : 20
        spacing: 12

        UI.SvgIcon {
            width: 20
            height: 20
            source: deviceItem.icons ? (deviceItem.modelData.connected ? deviceItem.icons.bluetoothConnectedSvg : deviceItem.icons.bluetoothSvg) : ""
            color: deviceItem.modelData.connected
                ? (deviceItem.theme ? deviceItem.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
                : (deviceItem.theme ? deviceItem.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90))
            opacity: 0.8

            Behavior on source {
                SequentialAnimation {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: 150
                    }
                    PropertyAction { property: "source" }
                    NumberAnimation {
                        property: "opacity"
                        to: 0.8
                        duration: 150
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: deviceItem.modelData.name
                color: (deviceItem.theme ? deviceItem.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))
                font.pixelSize: 14
                font.family: "M PLUS 2"
                elide: Text.ElideRight
            }

            Text {
                text: deviceItem.modelData.connected ? "Connected" : "Saved"
                color: deviceItem.modelData.connected
                    ? (deviceItem.theme ? deviceItem.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
                    : (deviceItem.theme ? deviceItem.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70))
                font.pixelSize: 11
                font.family: "M PLUS 2"
            }
        }

        Rectangle {
            width: 80
            height: 28
            radius: height / 2
            color: {
                if (!connectButtonArea.enabled) {
                    return Qt.rgba(0.5, 0.5, 0.5, 0.2)
                } else if (deviceItem.modelData.connected) {
                    return Qt.rgba(0.90, 0.45, 0.55, connectButtonArea.containsMouse ? 0.4 : 0.3)
                } else {
                    return (deviceItem.theme ? deviceItem.theme.accent : Qt.rgba(0.65, 0.55, 0.85, connectButtonArea.containsMouse ? 0.4 : 0.3))
                }
            }

            Behavior on color {
                ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Text {
                anchors.centerIn: parent
                text: {
                    if (deviceItem.bluetoothManager.isConnecting && deviceItem.connectingDeviceIndex === deviceItem.index) {
                        return "Connecting..."
                    } else if (deviceItem.modelData.connected) {
                        return "Disconnect"
                    } else {
                        return "Connect"
                    }
                }
                color: (deviceItem.theme ? deviceItem.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))
                font.pixelSize: 11
                font.weight: Font.Medium
                font.family: "M PLUS 2"
                opacity: connectButtonArea.enabled ? 1.0 : 0.5
            }

            MouseArea {
                id: connectButtonArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                z: 1
                enabled: !deviceItem.bluetoothManager.isConnecting || (deviceItem.connectingDeviceIndex === deviceItem.index) || deviceItem.modelData.connected
                onClicked: deviceItem.connectRequested()
            }
        }
    }

    MouseArea {
        id: deviceMouseArea
        anchors.fill: parent
        anchors.rightMargin: 90
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        z: -1
        propagateComposedEvents: false
    }
}
