import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../common" as Common
import "../ui" as UI

FocusScope {
    id: root

    required property var modeManager
    required property var bluetoothManager
    property var theme
    property var icons

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(420),
        "leftMargin": modeManager.scale(700),
        "rightMargin": modeManager.scale(700),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })

    property int connectingDeviceIndex: -1
    property int pairingDeviceIndex: -1
    property bool showAvailableDevices: false

    Connections {
        target: bluetoothManager

        function onIsConnectingChanged() {
            if (!bluetoothManager.isConnecting) {
                root.connectingDeviceIndex = -1
            }
        }

        function onIsPairingChanged() {
            if (!bluetoothManager.isPairing) {
                root.pairingDeviceIndex = -1
                if (bluetoothManager.pairingError === "") {
                    root.showAvailableDevices = false
                }
            }
        }
    }

    Timer {
        id: autoCloseTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            if (modeManager.isMode("bluetooth")) {
                modeManager.closeAllModes()
            }
        }
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("bluetooth")) {
                autoCloseTimer.restart()
                bluetoothManager.refreshStatus()
                bluetoothManager.refreshPairedDevices()
                root.showAvailableDevices = false
                Qt.callLater(() => {
                    if (bluetoothLayer) bluetoothLayer.forceActiveFocus()
                })
            } else {
                autoCloseTimer.stop()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 1.5
        enabled: modeManager.isMode("bluetooth")
        visible: enabled
        hoverEnabled: true

        onClicked: {
            modeManager.closeAllModes()
        }

        onPositionChanged: {
            if (modeManager.isMode("bluetooth")) {
                autoCloseTimer.restart()
            }
        }
    }

    Item {
        id: bluetoothLayer
        anchors.fill: parent
        anchors.leftMargin: modeManager.scale(32)
        anchors.rightMargin: modeManager.scale(32)
        z: 2

        focus: modeManager.isMode("bluetooth")
        Keys.onPressed: (event) => {
            if (modeManager.isMode("bluetooth")) {
                autoCloseTimer.restart()
            }
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: modeManager.scale(16)

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: modeManager.scale(420)
                spacing: modeManager.scale(12)

                Common.GlowText {
                    text: "Bluetooth"
                    font.pixelSize: modeManager.scale(20)
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    font.letterSpacing: 1.5
                    color: Qt.rgba(0.95, 0.93, 0.98, 0.95)

                    enableGlow: true
                    glowColor: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.6) : Qt.rgba(0.65, 0.55, 0.85, 0.6)
                    glowSamples: 20
                    glowRadius: 12
                    glowSpread: 0.5
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 12

                    Rectangle {
                        width: 32
                        height: 32
                        radius: width / 2
                        color: bluetoothManager.isPowered
                            ? Qt.rgba(0.45, 0.75, 0.55, powerToggleArea.containsMouse ? 0.4 : 0.3)
                            : Qt.rgba(0.75, 0.45, 0.45, powerToggleArea.containsMouse ? 0.4 : 0.3)

                        Behavior on color {
                            ColorAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }

                        UI.SvgIcon {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: icons ? (bluetoothManager.isPowered ? icons.bluetoothSvg : icons.bluetoothSlashSvg) : ""
                            color: bluetoothManager.isPowered
                                ? Qt.rgba(0.55, 0.95, 0.65, powerToggleArea.containsMouse ? 1.0 : 0.9)
                                : Qt.rgba(0.95, 0.55, 0.65, powerToggleArea.containsMouse ? 1.0 : 0.9)
                            opacity: powerToggleArea.containsMouse ? 1.0 : 0.9
                            scale: powerToggleArea.containsMouse ? 1.2 : 1.0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }
                            }

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
                                        to: powerToggleArea.containsMouse ? 1.0 : 0.9
                                        duration: 150
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: powerToggleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                bluetoothManager.togglePower()
                                autoCloseTimer.restart()
                            }
                        }
                    }

                    Rectangle {
                        id: scanButton
                        property real baseWidth: 32
                        property real animatedWidth: bluetoothManager.isPowered ? baseWidth : 0
                        Layout.preferredWidth: animatedWidth
                        Layout.fillWidth: false
                        height: 32
                        radius: height / 2
                        color: Qt.rgba(0.45, 0.65, 0.90, scanArea.containsMouse ? 0.4 : 0.3)
                        opacity: bluetoothManager.isPowered ? 1.0 : 0.0

                        Behavior on color {
                            ColorAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on animatedWidth {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutCubic
                            }
                        }

                        UI.SvgIcon {
                            id: scanIcon
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: icons ? (bluetoothManager.isScanning ? icons.bluetoothSearchingSvg : icons.refreshOutlineSvg) : ""
                            color: Qt.rgba(0.55, 0.75, 0.95, scanArea.containsMouse ? 1.0 : 0.9)
                            opacity: scanArea.containsMouse ? 1.0 : 0.9
                            scale: scanArea.containsMouse ? 1.2 : 1.0

                            Behavior on color {
                                ColorAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on source {
                                SequentialAnimation {
                                    NumberAnimation {
                                        target: scanIcon
                                        property: "opacity"
                                        to: 0
                                        duration: 150
                                    }
                                    PropertyAction { target: scanIcon; property: "source" }
                                    NumberAnimation {
                                        target: scanIcon
                                        property: "opacity"
                                        to: 1
                                        duration: 150
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: scanArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !bluetoothManager.isScanning && bluetoothManager.isPowered
                            onClicked: {
                                bluetoothManager.startScan()
                                root.showAvailableDevices = true
                                autoCloseTimer.restart()
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: modeManager.scale(420)
                Layout.preferredHeight: modeManager.scale(32)
                spacing: 8
                opacity: bluetoothManager.isPowered ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    Layout.preferredWidth: modeManager.scale(200)
                    Layout.preferredHeight: modeManager.scale(32)
                    radius: height / 2
                    color: !root.showAvailableDevices
                        ? Qt.rgba(0.45, 0.65, 0.90, myDevicesTabArea.containsMouse ? 0.4 : 0.3)
                        : Qt.rgba(0, 0, 0, 0.3)

                    Behavior on color {
                        ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "My Devices (" + bluetoothManager.pairedDevices.length + ")"
                        color: Qt.rgba(0.95, 0.93, 0.98, 0.95)
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.family: "M PLUS 2"
                    }

                    MouseArea {
                        id: myDevicesTabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showAvailableDevices = false
                            autoCloseTimer.restart()
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: modeManager.scale(200)
                    Layout.preferredHeight: modeManager.scale(32)
                    radius: height / 2
                    color: root.showAvailableDevices
                        ? Qt.rgba(0.45, 0.65, 0.90, nearbyTabArea.containsMouse ? 0.4 : 0.3)
                        : Qt.rgba(0, 0, 0, 0.3)

                    Behavior on color {
                        ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Nearby (" + bluetoothManager.availableDevices.length + ")"
                        color: Qt.rgba(0.95, 0.93, 0.98, 0.95)
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.family: "M PLUS 2"
                    }

                    MouseArea {
                        id: nearbyTabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showAvailableDevices = true
                            if (bluetoothManager.availableDevices.length === 0 && !bluetoothManager.isScanning) {
                                bluetoothManager.startScan()
                            }
                            autoCloseTimer.restart()
                        }
                    }
                }
            }

            Item {
                Layout.preferredWidth: modeManager.scale(420)
                Layout.preferredHeight: modeManager.scale(240)
                clip: true

                Text {
                    anchors.centerIn: parent
                    text: "Bluetooth is turned off"
                    color: Qt.rgba(0.72, 0.72, 0.82, 0.70)
                    font.pixelSize: 14
                    font.family: "M PLUS 2"
                    opacity: bluetoothManager.isPowered ? 0.0 : 1.0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                ListView {
                    id: pairedDeviceList
                    anchors.fill: parent
                    spacing: 8
                    clip: true

                    model: bluetoothManager.pairedDevices

                    opacity: (bluetoothManager.isPowered && !root.showAvailableDevices) ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutCubic
                        }
                    }

                    add: Transition {
                        SequentialAnimation {
                            PauseAnimation {
                                duration: ViewTransition.index * 50
                            }
                            ParallelAnimation {
                                NumberAnimation {
                                    property: "opacity"
                                    from: 0.0
                                    to: 1.0
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    property: "scale"
                                    from: 0.9
                                    to: 1.0
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    delegate: Rectangle {
                        width: pairedDeviceList.width
                        height: 60
                        color: deviceMouseArea.containsMouse ? Qt.rgba(0, 0, 0, 0.75) : Qt.rgba(0, 0, 0, 0.65)
                        radius: height / 2
                        border.width: 0

                        layer.enabled: true
                        layer.effect: Glow {
                            samples: 12
                            radius: 6
                            spread: 0.3
                            color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.15) : Qt.rgba(0.65, 0.55, 0.85, 0.15)
                            transparentBorder: true
                        }

                        Behavior on color {
                            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: modeManager.scale(20)
                            anchors.rightMargin: modeManager.scale(20)
                            spacing: 12

                            UI.SvgIcon {
                                width: 20
                                height: 20
                                source: icons ? (modelData.connected ? icons.bluetoothConnectedSvg : icons.bluetoothSvg) : ""
                                color: modelData.connected
                                    ? (theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
                                    : (theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90))
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
                                    text: modelData.name
                                    color: Qt.rgba(0.92, 0.92, 0.96, 0.90)
                                    font.pixelSize: 14
                                    font.family: "M PLUS 2"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: modelData.connected ? "Connected" : "Saved"
                                    color: modelData.connected
                                        ? (theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
                                        : Qt.rgba(0.72, 0.72, 0.82, 0.70)
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
                                    } else if (modelData.connected) {
                                        return Qt.rgba(0.90, 0.45, 0.55, connectButtonArea.containsMouse ? 0.4 : 0.3)
                                    } else {
                                        return (theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, connectButtonArea.containsMouse ? 0.4 : 0.3))
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (bluetoothManager.isConnecting && root.connectingDeviceIndex === index) {
                                            return "Connecting..."
                                        } else if (modelData.connected) {
                                            return "Disconnect"
                                        } else {
                                            return "Connect"
                                        }
                                    }
                                    color: Qt.rgba(0.95, 0.93, 0.98, 0.95)
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
                                    enabled: !bluetoothManager.isConnecting || (root.connectingDeviceIndex === index) || modelData.connected
                                    onClicked: {
                                        if (!modelData.connected) {
                                            root.connectingDeviceIndex = index
                                        }
                                        bluetoothManager.toggleDeviceConnection(
                                            modelData.address,
                                            modelData.name,
                                            modelData.connected
                                        )
                                        autoCloseTimer.restart()
                                    }
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
                }

                ListView {
                    id: availableDeviceList
                    anchors.fill: parent
                    spacing: 8
                    clip: true

                    model: bluetoothManager.availableDevices

                    opacity: (bluetoothManager.isPowered && root.showAvailableDevices) ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutCubic
                        }
                    }

                    add: Transition {
                        SequentialAnimation {
                            PauseAnimation {
                                duration: ViewTransition.index * 50
                            }
                            ParallelAnimation {
                                NumberAnimation {
                                    property: "opacity"
                                    from: 0.0
                                    to: 1.0
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    property: "scale"
                                    from: 0.9
                                    to: 1.0
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    delegate: Rectangle {
                        width: availableDeviceList.width
                        height: 60
                        color: deviceMouseArea2.containsMouse ? Qt.rgba(0, 0, 0, 0.75) : Qt.rgba(0, 0, 0, 0.65)
                        radius: height / 2
                        border.width: 0

                        layer.enabled: true
                        layer.effect: Glow {
                            samples: 12
                            radius: 6
                            spread: 0.3
                            color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.15) : Qt.rgba(0.65, 0.55, 0.85, 0.15)
                            transparentBorder: true
                        }

                        Behavior on color {
                            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: modeManager.scale(20)
                            anchors.rightMargin: modeManager.scale(20)
                            spacing: 12

                            UI.SvgIcon {
                                width: 20
                                height: 20
                                source: icons ? icons.bluetoothSvg : ""
                                color: modelData.paired
                                    ? (theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90))
                                    : (theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
                                opacity: 0.8
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.name || modelData.address
                                    color: Qt.rgba(0.92, 0.92, 0.96, 0.90)
                                    font.pixelSize: 14
                                    font.family: "M PLUS 2"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: modelData.paired ? "Saved" : "New device"
                                    color: modelData.paired
                                        ? Qt.rgba(0.72, 0.72, 0.82, 0.70)
                                        : (theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
                                    font.pixelSize: 11
                                    font.family: "M PLUS 2"
                                }
                            }

                            Rectangle {
                                width: 80
                                height: 28
                                radius: height / 2
                                color: {
                                    if (!pairButtonArea.enabled) {
                                        return Qt.rgba(0.5, 0.5, 0.5, 0.2)
                                    } else if (modelData.paired) {
                                        return Qt.rgba(0.5, 0.5, 0.5, 0.2)
                                    } else {
                                        return (theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, pairButtonArea.containsMouse ? 0.4 : 0.3))
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (bluetoothManager.isPairing && root.pairingDeviceIndex === index) {
                                            return "Pairing..."
                                        } else if (modelData.paired) {
                                            return "Saved"
                                        } else {
                                            return "Pair"
                                        }
                                    }
                                    color: Qt.rgba(0.95, 0.93, 0.98, 0.95)
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    font.family: "M PLUS 2"
                                    opacity: pairButtonArea.enabled && !modelData.paired ? 1.0 : 0.5
                                }

                                MouseArea {
                                    id: pairButtonArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    z: 1
                                    enabled: !modelData.paired && !bluetoothManager.isPairing
                                    onClicked: {
                                        root.pairingDeviceIndex = index
                                        bluetoothManager.pairDevice(
                                            modelData.address,
                                            modelData.name || modelData.address
                                        )
                                        autoCloseTimer.restart()
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: deviceMouseArea2
                            anchors.fill: parent
                            anchors.rightMargin: 90
                            hoverEnabled: true
                            cursorShape: Qt.ArrowCursor
                            z: -1
                            propagateComposedEvents: false
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: bluetoothManager.isScanning ? "Scanning..." : "No devices"
                    color: Qt.rgba(0.72, 0.72, 0.82, 0.50)
                    font.pixelSize: 14
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    opacity: (bluetoothManager.pairedDevices.length === 0 && bluetoothManager.isPowered && !root.showAvailableDevices) ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: bluetoothManager.isScanning ? "Scanning..." : "No devices found"
                    color: Qt.rgba(0.72, 0.72, 0.82, 0.50)
                    font.pixelSize: 14
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    opacity: (bluetoothManager.availableDevices.length === 0 && bluetoothManager.isPowered && root.showAvailableDevices && !bluetoothManager.isScanning) ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("bluetooth", root)
            if (modeManager.isMode("bluetooth")) {
                autoCloseTimer.restart()
                bluetoothManager.refreshStatus()
                bluetoothManager.refreshPairedDevices()
                root.showAvailableDevices = false
                Qt.callLater(() => {
                    if (bluetoothLayer) bluetoothLayer.forceActiveFocus()
                })
            }
        }
    }
}
