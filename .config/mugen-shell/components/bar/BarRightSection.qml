import QtQuick
import QtQuick.Layouts
import Quickshell
import "../ui" as UI
import "../common" as Common

RowLayout {
    id: root
    
    function scaled(val) {
        if (modeManager) return modeManager.scale(val)
        return val
    }
    
    spacing: scaled(4)
    Layout.alignment: Qt.AlignVCenter
    
    component Separator: UI.SvgIcon {
        width: 1
        height: scaled(16)
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: scaled(-4)  // Negate parent RowLayout spacing
        Layout.rightMargin: scaled(-4)  // Negate parent RowLayout spacing
        source: Quickshell.shellDir + "/assets/icons/divider.svg"
        color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.40)
        opacity: 0.5
    }
    
    property var theme
    property var typo
    property var icons
    property var notificationManager
    property var modeManager
    property var wifiManager
    property var bluetoothManager
    property var imeStatus
    property var idleInhibitorManager

    UI.Tray {
        modeManager: root.modeManager
        theme: root.theme
    }

    Separator {}

    Item {
        id: notificationIconContainer
        implicitWidth: scaled(24)
        implicitHeight: scaled(24)
        Layout.alignment: Qt.AlignVCenter
        
        property bool hasUnreadNotifications: root.notificationManager ? root.notificationManager.unreadCount > 0 : false
        
        property color notificationBlueColor: {
            if (!root.theme) return Qt.rgba(0.65, 0.55, 0.85, 0.9)
            let accentBase = root.theme.accent
            let h = accentBase.hsvHue
            let s = accentBase.hsvSaturation
            let v = accentBase.hsvValue
            let a = accentBase.a
            let themedHueShift = -0.35
            let themedH = (h + themedHueShift + 1.0) % 1.0
            
            let isLightMode = root.theme.themeMode === "light"
            let finalV = isLightMode
                ? Math.max(0.0, v - 0.2)
                : Math.min(1.0, v + 0.5)
            
            return Qt.hsva(themedH, s, finalV, a)
        }
        
        Item {
            id: notificationRippleContainer
            anchors.centerIn: parent
            width: scaled(60)
            height: scaled(60)
            visible: notificationIconContainer.hasUnreadNotifications
            z: 0
            
            Repeater {
                model: 3
                
                Rectangle {
                    id: ripple
                    anchors.centerIn: parent
                    width: scaled(20)
                    height: scaled(20)
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: notificationIconContainer.notificationBlueColor
                    
                    property real rippleScale: 1.0
                    property real rippleOpacity: 0.0
                    
                    scale: rippleScale
                    opacity: rippleOpacity
                    
                    SequentialAnimation on rippleScale {
                        loops: Animation.Infinite
                        running: notificationRippleContainer.visible
                        
                        PauseAnimation { duration: index * 300 }
                        NumberAnimation {
                            from: 1.0; to: 2.0
                            duration: 1200
                            easing.type: Easing.OutCubic
                        }
                        PauseAnimation { duration: 4000 - 1200 - index * 300 }
                    }
                    
                    SequentialAnimation on rippleOpacity {
                        loops: Animation.Infinite
                        running: notificationRippleContainer.visible
                        
                        PauseAnimation { duration: index * 300 }
                        NumberAnimation { from: 0.0; to: 0.5; duration: 200; easing.type: Easing.OutCubic }
                        NumberAnimation { from: 0.5; to: 0.0; duration: 1000; easing.type: Easing.OutCubic }
                        PauseAnimation { duration: 4000 - 1200 - index * 300 }
                    }
                }
            }
        }
        
        UI.SvgIcon {
            id: notificationIcon
            anchors.centerIn: parent
            width: scaled(24)
            height: scaled(24)
            source: root.icons 
                ? (root.notificationManager && !root.notificationManager.notificationsEnabled
                    ? root.icons.notificationOffSvg
                    : root.icons.notificationSvg)
                : ""
            // Pulse color between base and themed accent when unread notifications exist
            color: {
                if (!root.theme) {
                    return Qt.rgba(0.92, 0.92, 0.96, 0.90)
                }
                
                if (notificationIconContainer.hasUnreadNotifications) {
                    let base = root.theme.textPrimary
                    
                    let accentBase = root.theme.accent
                    let h = accentBase.hsvHue
                    let s = accentBase.hsvSaturation
                    let v = accentBase.hsvValue
                    let a = accentBase.a
                    
                    let themedHueShift = -0.35
                    let themedH = (h + themedHueShift + 1.0) % 1.0
                    let themed = Qt.hsva(themedH, s, Math.min(1.0, v + 0.5), a)
                    
                    let t = notificationIcon.highlightPulse
                    let r = base.r + (themed.r - base.r) * t
                    let g = base.g + (themed.g - base.g) * t
                    let b = base.b + (themed.b - base.b) * t
                    let finalA = base.a + (themed.a - base.a) * t
                    return Qt.rgba(r, g, b, finalA)
                }
                
                return root.theme.textPrimary
            }
            opacity: notificationMouseArea.containsMouse ? 1.0 : 0.6
            z: 1
            
            property real baseScale: 1.0
            property real hoverScale: notificationMouseArea.containsMouse ? 0.3 : 0.0
            property real gentleScale: 0.0
            property real highlightPulse: 0.0
            
            scale: baseScale + hoverScale + gentleScale
            
            SequentialAnimation on highlightPulse {
                id: highlightBreath
                loops: Animation.Infinite
                running: notificationIconContainer.hasUnreadNotifications && !notificationMouseArea.containsMouse
                
                NumberAnimation { from: 0.0; to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.0; to: 0.0; duration: 1200; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 800 }
            }
            
            Behavior on opacity {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }
            Behavior on hoverScale {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }
        }
        
        MouseArea {
            id: notificationMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            z: 2
            
            onEntered: {
                notificationIcon.gentleScale = 0.0
            }
            onClicked: {
                if (root.modeManager) {
                    root.modeManager.switchMode("notification")
                }
            }
        }
    }

    Separator {}

    UI.ImeIndicator {
        Layout.alignment: Qt.AlignVCenter
        visible: root.imeStatus
        theme: root.theme
        imeStatus: root.imeStatus
        modeManager: root.modeManager
    }

    Common.IconButton {
        id: idleToggleButton
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: root.spacing
        modeManager: root.modeManager
        iconSize: scaled(24)
        opacityDuration: 150
        property bool isBlinking: false
        readonly property color accentColorBase: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
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
            if (!root.icons || !root.idleInhibitorManager) return ""
            if (isBlinking) {
                return root.icons.iconData.eyeClosed.value
            }
            return root.idleInhibitorManager.isInhibited
                    ? root.icons.iconData.eyeOpen.value
                    : root.icons.iconData.eyeClosed.value
        }
        iconColor: root.idleInhibitorManager && root.idleInhibitorManager.isInhibited
            ? accentLightColor
            : (root.theme
                ? root.theme.textPrimary
                : Qt.rgba(0.92, 0.92, 0.96, 0.90))
        
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
            running: root.idleInhibitorManager && root.idleInhibitorManager.isInhibited
            repeat: true
            onRunningChanged: {
                if (running) {
                    interval = 6000 + Math.random() * 5000
                }
            }
            onTriggered: {
                interval = 6000 + Math.random() * 5000
                idleToggleButton.blinkTwice = Math.random() < 0.5
                if (root.idleInhibitorManager && root.idleInhibitorManager.isInhibited && !idleBlinkAnimationSingle.running && !idleBlinkAnimationDouble.running) {
                    idleToggleButton.startBlink()
                }
            }
        }
        
        Component.onCompleted: {
            if (root.idleInhibitorManager && root.idleInhibitorManager.isInhibited) {
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
            target: root.idleInhibitorManager
            function onIsInhibitedChanged() {
                if (!root.idleInhibitorManager || !root.idleInhibitorManager.isInhibited) {
                    idleBlinkAnimationSingle.stop()
                    idleBlinkAnimationDouble.stop()
                    idleToggleButton.isBlinking = false
                } else {
                    idleBlinkTimer.interval = 6000 + Math.random() * 5000
                }
            }
        }
        
        onClicked: {
            if (root.idleInhibitorManager) {
                root.idleInhibitorManager.toggle()
            }
        }
        
        onRightClicked: {
            if (root.idleInhibitorManager) {
                root.idleInhibitorManager.refreshStatus()
            }
        }
    }

    Separator {}

    Item {
        id: wifiContainer
        implicitWidth: scaled(24)
        implicitHeight: scaled(24)
        Layout.alignment: Qt.AlignVCenter
        
        property bool isConnected: root.wifiManager ? root.wifiManager.isConnected : false
        
        UI.SvgIcon {
            id: wifiIconSvg
            anchors.centerIn: parent
            width: scaled(24)
            height: scaled(24)
            source: root.icons ? (parent.isConnected ? root.icons.wifiSvg : root.icons.wifiOffSvg) : ""
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            opacity: wifiMouseArea.containsMouse ? 1.0 : 0.6
            scale: wifiMouseArea.containsMouse ? 1.3 : 1.0
            
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
            id: wifiMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.modeManager) {
                    root.modeManager.switchMode("wifi")
                }
            }
        }
    }
    
    Item {
        id: bluetoothContainer
        implicitWidth: scaled(24)
        implicitHeight: scaled(24)
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: scaled(4)
        
        property bool isPowered: root.bluetoothManager ? root.bluetoothManager.isPowered : false
        property bool isScanning: root.bluetoothManager ? root.bluetoothManager.isScanning : false
        property bool hasConnectedDevices: root.bluetoothManager ? root.bluetoothManager.hasConnectedDevices : false
        
        UI.SvgIcon {
            id: bluetoothIconSvg
            anchors.centerIn: parent
            width: scaled(24)
            height: scaled(24)
            source: {
                if (!root.icons || !root.bluetoothManager) return ""
                let iconData = root.icons.getBluetoothIcon(parent.isPowered, parent.isScanning, parent.hasConnectedDevices)
                return iconData.value
            }
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            opacity: bluetoothMouseArea.containsMouse ? 1.0 : 0.6
            scale: bluetoothMouseArea.containsMouse ? 1.3 : 1.0
            
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
            id: bluetoothMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.modeManager) {
                    root.modeManager.switchMode("bluetooth")
                }
            }
        }
    }
    
    Separator {}

    UI.PowerMenu {
        modeManager: root.modeManager
        accentColor: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
        textColor: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        icons: root.icons
        onClicked: {
            if (root.modeManager) {
                root.modeManager.switchMode("powermenu")
            }
        }
        onRightClicked: {
            if (root.modeManager) {
                root.modeManager.switchMode("settings")
            }
        }
    }
}

