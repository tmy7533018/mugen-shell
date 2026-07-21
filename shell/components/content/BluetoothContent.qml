import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../common" as Common
import "../ui" as UI
import "./bluetooth" as Bluetooth
import "../../lib" as Theme

Item {
    id: root

    required property var modeManager
    required property var bluetoothManager
    property var theme
    property var icons

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(420),
        "leftMargin": modeManager.scale(700),
        "rightMargin": modeManager.scale(700),
        "topMargin": modeManager.normalBarSize.topMargin,
        "bottomMargin": modeManager.normalBarSize.bottomMargin
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

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("bluetooth")) {
                bluetoothManager.refreshStatus()
                bluetoothManager.refreshPairedDevices()
                root.showAvailableDevices = false
                pairedDeviceList.currentIndex = -1
                availableDeviceList.currentIndex = -1
                focusTimer.restart()
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: {
            if (bluetoothLayer && modeManager.isMode("bluetooth")) {
                bluetoothLayer.forceActiveFocus()
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
                modeManager.bump()
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
                modeManager.bump()
            }
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_P && !(event.modifiers & Qt.ControlModifier)) {
                bluetoothManager.togglePower()
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_R && !(event.modifiers & Qt.ControlModifier)) {
                if (bluetoothManager.isPowered && !bluetoothManager.isScanning) {
                    bluetoothManager.startScan()
                    root.showAvailableDevices = true
                }
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Tab) {
                root.showAvailableDevices = !root.showAvailableDevices
                event.accepted = true
                return
            }

            if (!bluetoothManager.isPowered) return

            let activeList = root.showAvailableDevices ? availableDeviceList : pairedDeviceList
            let count = activeList.count
            if (count === 0) return

            if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                let next = activeList.currentIndex + 1
                if (next >= count) next = 0
                activeList.currentIndex = next
                activeList.positionViewAtIndex(next, ListView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                let prev = activeList.currentIndex - 1
                if (prev < 0) prev = count - 1
                activeList.currentIndex = prev
                activeList.positionViewAtIndex(prev, ListView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Home) {
                activeList.currentIndex = 0
                activeList.positionViewAtIndex(0, ListView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_End) {
                activeList.currentIndex = count - 1
                activeList.positionViewAtIndex(count - 1, ListView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                let idx = activeList.currentIndex
                if (idx < 0) return
                if (root.showAvailableDevices) {
                    let dev = bluetoothManager.availableDevices[idx]
                    if (dev) {
                        root.pairingDeviceIndex = idx
                        bluetoothManager.pairDevice(dev.address, dev.name || dev.address)
                    }
                } else {
                    let dev = bluetoothManager.pairedDevices[idx]
                    if (dev) {
                        if (!dev.connected) root.connectingDeviceIndex = idx
                        bluetoothManager.toggleDeviceConnection(dev.address, dev.name, dev.connected)
                    }
                }
                event.accepted = true
            }
        }

        opacity: 0
        visible: opacity > 0.01

        states: [
            State {
                name: "visible"
                when: modeManager.isMode("bluetooth")
                PropertyChanges { target: bluetoothLayer; opacity: 1.0 }
            }
        ]

        transitions: [
            Transition {
                from: "visible"
                to: ""
                NumberAnimation {
                    property: "opacity"
                    duration: Theme.Motion.standard
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: Theme.Motion.standard }
                    NumberAnimation {
                        property: "opacity"
                        duration: Theme.Motion.gentle
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        ]

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
                    color: (theme ? theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))

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
                            ColorAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
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
                                    duration: Theme.Motion.standard
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.Motion.standard
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on source {
                                SequentialAnimation {
                                    NumberAnimation {
                                        property: "opacity"
                                        to: 0
                                        duration: Theme.Motion.micro
                                    }
                                    PropertyAction { property: "source" }
                                    NumberAnimation {
                                        property: "opacity"
                                        to: powerToggleArea.containsMouse ? 1.0 : 0.9
                                        duration: Theme.Motion.micro
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
                                modeManager.bump()
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
                            ColorAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.Motion.gentle
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on animatedWidth {
                            NumberAnimation {
                                duration: Theme.Motion.gentle
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
                                ColorAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.Motion.standard
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.Motion.standard
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on source {
                                SequentialAnimation {
                                    NumberAnimation {
                                        target: scanIcon
                                        property: "opacity"
                                        to: 0
                                        duration: Theme.Motion.micro
                                    }
                                    PropertyAction { target: scanIcon; property: "source" }
                                    NumberAnimation {
                                        target: scanIcon
                                        property: "opacity"
                                        to: 1
                                        duration: Theme.Motion.micro
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
                                modeManager.bump()
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
                    NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    Layout.preferredWidth: modeManager.scale(200)
                    Layout.preferredHeight: modeManager.scale(32)
                    radius: height / 2
                    color: !root.showAvailableDevices
                        ? Qt.rgba(0.45, 0.65, 0.90, myDevicesTabArea.containsMouse ? 0.4 : 0.3)
                        : (theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.3))

                    Behavior on color {
                        ColorAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "My Devices (" + bluetoothManager.pairedDevices.length + ")"
                        color: (theme ? theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))
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
                            modeManager.bump()
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: modeManager.scale(200)
                    Layout.preferredHeight: modeManager.scale(32)
                    radius: height / 2
                    color: root.showAvailableDevices
                        ? Qt.rgba(0.45, 0.65, 0.90, nearbyTabArea.containsMouse ? 0.4 : 0.3)
                        : (theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.3))

                    Behavior on color {
                        ColorAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Nearby (" + bluetoothManager.availableDevices.length + ")"
                        color: (theme ? theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95))
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
                            modeManager.bump()
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
                    color: (theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.70))
                    font.pixelSize: 14
                    font.family: "M PLUS 2"
                    opacity: bluetoothManager.isPowered ? 0.0 : 1.0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.Motion.gentle
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
                    currentIndex: -1

                    opacity: (bluetoothManager.isPowered && !root.showAvailableDevices) ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.Motion.gentle
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
                                    duration: Theme.Motion.gentle
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    property: "scale"
                                    from: 0.9
                                    to: 1.0
                                    duration: Theme.Motion.gentle
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    delegate: Bluetooth.PairedDeviceItem {
                        width: pairedDeviceList.width
                        theme: root.theme
                        icons: root.icons
                        modeManager: root.modeManager
                        bluetoothManager: root.bluetoothManager
                        connectingDeviceIndex: root.connectingDeviceIndex
                        onConnectRequested: {
                            if (!modelData.connected) {
                                root.connectingDeviceIndex = index
                            }
                            bluetoothManager.toggleDeviceConnection(
                                modelData.address,
                                modelData.name,
                                modelData.connected
                            )
                            modeManager.bump()
                        }
                    }
                }

                ListView {
                    id: availableDeviceList
                    anchors.fill: parent
                    spacing: 8
                    clip: true

                    model: bluetoothManager.availableDevices
                    currentIndex: -1

                    opacity: (bluetoothManager.isPowered && root.showAvailableDevices) ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.Motion.gentle
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
                                    duration: Theme.Motion.gentle
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    property: "scale"
                                    from: 0.9
                                    to: 1.0
                                    duration: Theme.Motion.gentle
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    delegate: Bluetooth.AvailableDeviceItem {
                        width: availableDeviceList.width
                        theme: root.theme
                        icons: root.icons
                        modeManager: root.modeManager
                        bluetoothManager: root.bluetoothManager
                        pairingDeviceIndex: root.pairingDeviceIndex
                        onPairRequested: {
                            root.pairingDeviceIndex = index
                            bluetoothManager.pairDevice(
                                modelData.address,
                                modelData.name || modelData.address
                            )
                            modeManager.bump()
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: bluetoothManager.isScanning ? "Scanning..." : "No devices"
                    color: (theme ? theme.textFaint : Qt.rgba(0.72, 0.72, 0.82, 0.50))
                    font.pixelSize: 14
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    opacity: (bluetoothManager.pairedDevices.length === 0 && bluetoothManager.isPowered && !root.showAvailableDevices) ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.Motion.gentle
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: bluetoothManager.isScanning ? "Scanning..." : "No devices found"
                    color: (theme ? theme.textFaint : Qt.rgba(0.72, 0.72, 0.82, 0.50))
                    font.pixelSize: 14
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    opacity: (bluetoothManager.availableDevices.length === 0 && bluetoothManager.isPowered && root.showAvailableDevices && !bluetoothManager.isScanning) ? 1.0 : 0.0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.Motion.gentle
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
                modeManager.bump()
                bluetoothManager.refreshStatus()
                bluetoothManager.refreshPairedDevices()
                root.showAvailableDevices = false
                focusTimer.restart()
            }
        }
    }
}
