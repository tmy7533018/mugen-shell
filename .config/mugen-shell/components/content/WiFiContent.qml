import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../common" as Common
import "../ui" as UI

Item {
    id: root
    
    required property var modeManager
    required property var wifiManager
    property var theme
    property var icons
    
    readonly property var requiredBarSize: ({
        "height": modeManager.scale(420),
        "leftMargin": modeManager.scale(700),
        "rightMargin": modeManager.scale(700),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })
    
    property int connectingNetworkIndex: -1

    Connections {
        target: wifiManager

        function onIsConnectingChanged() {
            if (!wifiManager.isConnecting && wifiManager.connectionError === "") {
                root.connectingNetworkIndex = -1
                networkList.expandedIndex = -1
                modeManager.closeAllModes()
            }
        }
    }
    
    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("wifi")) wifiManager.fullRefresh()
        }
    }


    MouseArea {
        anchors.fill: parent
        z: 1.5
        enabled: modeManager.isMode("wifi")
        visible: enabled
        hoverEnabled: true
        
        onClicked: {
            modeManager.closeAllModes()
        }

        onPositionChanged: {
            if (modeManager.isMode("wifi")) {
                modeManager.bump()
            }
        }
    }
    
    Item {
        id: wifiLayer
        anchors.fill: parent
        anchors.leftMargin: modeManager.scale(32)
        anchors.rightMargin: modeManager.scale(32)
        z: 3  // Must be above the background click area (z: 1.5)
        
        focus: modeManager.isMode("wifi")
        Keys.onPressed: (event) => {
            if (modeManager.isMode("wifi")) {
                modeManager.bump()
            }
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
            }
        }
        
        opacity: 0
        visible: true
        
        states: [
            State {
                name: "visible"
                when: modeManager.isMode("wifi")
                PropertyChanges { target: wifiLayer; opacity: 1.0 }
            }
        ]
        
        transitions: [
            Transition {
                from: "visible"
                to: ""
                NumberAnimation {
                    property: "opacity"
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: ""
                to: "visible"
                SequentialAnimation {
                    PauseAnimation { duration: 300 }
                    NumberAnimation {
                        property: "opacity"
                        duration: 400
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
                    text: "WiFi"
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
                        color: wifiManager.isPowered
                            ? Qt.rgba(0.45, 0.75, 0.55, powerToggleArea.containsMouse ? 0.4 : 0.3)
                            : Qt.rgba(0.75, 0.45, 0.45, powerToggleArea.containsMouse ? 0.4 : 0.3)
                        
                        Behavior on color {
                            ColorAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }
                        
                        UI.SvgIcon {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: icons ? (wifiManager.isPowered ? icons.wifiSvg : icons.wifiOffSvg) : ""
                            color: wifiManager.isPowered
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
                                wifiManager.togglePower()
                                modeManager.bump()
                            }
                        }
                    }
                    
                    Rectangle {
                        id: refreshButton
                        property real baseWidth: 32
                        property real animatedWidth: wifiManager.isPowered ? baseWidth : 0
                        Layout.preferredWidth: animatedWidth
                        Layout.fillWidth: false
                        height: 32
                        radius: height / 2
                        color: Qt.rgba(0.45, 0.65, 0.90, refreshArea.containsMouse ? 0.4 : 0.3)
                        opacity: wifiManager.isPowered ? (wifiManager.isRefreshing ? 0.8 : 1.0) : 0.0
                        visible: opacity > 0.01
                        
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
                            id: refreshIcon
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: icons ? icons.refreshOutlineSvg : ""
                            color: Qt.rgba(0.55, 0.75, 0.95, refreshArea.containsMouse ? 1.0 : 0.9)
                            opacity: refreshArea.containsMouse ? 1.0 : 0.9
                            scale: refreshArea.containsMouse ? 1.2 : 1.0
                            
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
                                        target: refreshIcon
                                        property: "opacity"
                                        to: 0
                                        duration: 150
                                    }
                                    PropertyAction { target: refreshIcon; property: "source" }
                                    NumberAnimation {
                                        target: refreshIcon
                                        property: "opacity"
                                        to: 1
                                        duration: 150
                                    }
                                }
                            }
                            
                            transform: Rotation {
                                origin.x: refreshIcon.width / 2
                                origin.y: refreshIcon.height / 2
                                angle: 0
                                
                                SequentialAnimation on angle {
                                    loops: Animation.Infinite
                                    running: wifiManager.isRefreshing
                                    
                                    NumberAnimation {
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        easing.type: Easing.Linear
                                    }
                                }
                            }
                        }
                        
                        MouseArea {
                            id: refreshArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !wifiManager.isRefreshing && wifiManager.isPowered
                            onClicked: {
                                wifiManager.fullRefresh()
                                modeManager.bump()
                            }
                        }
                    }
                }
            }
            
            Rectangle {
                Layout.preferredWidth: modeManager.scale(420)
                // Fixed height to keep layout stable when content changes
                Layout.preferredHeight: modeManager.scale(60)
                color: Qt.rgba(0, 0, 0, 0.25)
                radius: 16
                
                opacity: wifiManager.isPowered ? 1.0 : 0.0
                visible: true  // Always true to reserve layout space
                
                Behavior on opacity {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }
                
                layer.enabled: true
                layer.effect: Glow {
                    samples: 24
                    radius: 12
                    spread: 0.5
                    color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.20) : Qt.rgba(0.65, 0.55, 0.85, 0.20)
                    transparentBorder: true
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: modeManager.scale(20)
                    anchors.rightMargin: modeManager.scale(20)
                    spacing: 12
                    
                    UI.SvgIcon {
                        width: 24
                        height: 24
                        source: icons ? (wifiManager.isConnected ? icons.wifiSvg : icons.wifiOffSvg) : ""
                        color: wifiManager.isConnected ? (theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)) : (theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60))
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        
                        Text {
                            text: wifiManager.isConnected ? wifiManager.currentSsid : "未接続"
                            color: Qt.rgba(0.92, 0.92, 0.96, 0.90)
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            font.family: "M PLUS 2"
                        }
                        
                        Text {
                            text: wifiManager.isConnected ? ("Signal: " + wifiManager.signalStrength + "%") : "Not connected to any network"
                            color: Qt.rgba(0.72, 0.72, 0.82, 0.70)
                            font.pixelSize: 12
                            font.family: "M PLUS 2"
                        }
                    }
                }
            }
            
            Item {
                Layout.preferredWidth: modeManager.scale(420)
                Layout.preferredHeight: modeManager.scale(220)
                clip: true
                
                Text {
                    anchors.centerIn: parent
                    text: "WiFi is turned off"
                    color: Qt.rgba(0.72, 0.72, 0.82, 0.70)
                    font.pixelSize: 14
                    font.family: "M PLUS 2"
                    opacity: wifiManager.isPowered ? 0.0 : 1.0
                    visible: opacity > 0.01
                    
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                
                ListView {
                    id: networkList
                    anchors.fill: parent
                    spacing: 8
                    clip: true
                    
                    model: wifiManager.availableNetworks
                    
                    reuseItems: false
                    
                    property int expandedIndex: -1

                    opacity: wifiManager.isPowered && !wifiManager.isRefreshing ? 1.0 : 0.0
                    visible: opacity > 0.01
                    
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 300
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
                    
                    displaced: Transition {
                        NumberAnimation {
                            property: "y"
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    delegate: Item {
                        id: delegateItem
                        width: networkList.width
                        
                        // Explicit properties to pass into the custom component
                        property var itemData: modelData
                        property int itemIndex: index
                        
                        implicitHeight: networkItem.implicitHeight
                        height: implicitHeight
                        
                        UI.NetworkItem {
                            id: networkItem
                            width: delegateItem.width
                            modelData: delegateItem.itemData
                            index: delegateItem.itemIndex
                            theme: root.theme
                            icons: root.icons
                            wifiManager: root.wifiManager
                            isExpanded: networkList.expandedIndex === delegateItem.itemIndex
                            isConnecting: root.wifiManager.isConnecting
                            connectingNetworkIndex: root.connectingNetworkIndex
                            
                            onToggleExpanded: () => {
                                if (networkList.expandedIndex === delegateItem.itemIndex) {
                                    networkList.expandedIndex = -1
                                } else {
                                    networkList.expandedIndex = delegateItem.itemIndex
                                }
                            }
                            
                            onResetAutoCloseTimer: () => {
                                modeManager.bump()
                            }
                            
                            onConnectToNetwork: (ssid, password) => {
                                root.connectingNetworkIndex = delegateItem.itemIndex
                                root.wifiManager.connectToNetwork(ssid, password)
                            }
                        }
                    }
                }
                
                Item {
                    anchors.centerIn: parent
                    width: 80
                    height: 20
                    opacity: wifiManager.isRefreshing ? 1.0 : 0.0
                    visible: opacity > 0.01
                    
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 12
                        
                        Repeater {
                            model: 3
                            
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                                
                                property real dotOpacity: 0.3
                                opacity: dotOpacity
                                
                                SequentialAnimation on dotOpacity {
                                    loops: Animation.Infinite
                                    running: wifiManager.isRefreshing
                                    
                                    PauseAnimation { duration: index * 200 }
                                    NumberAnimation {
                                        from: 0.3
                                        to: 1.0
                                        duration: 600
                                        easing.type: Easing.InOutSine
                                    }
                                    NumberAnimation {
                                        from: 1.0
                                        to: 0.3
                                        duration: 600
                                        easing.type: Easing.InOutSine
                                    }
                                    PauseAnimation { duration: (2 - index) * 200 }
                                }
                            }
                        }
                    }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "No networks found"
                    color: Qt.rgba(0.72, 0.72, 0.82, 0.50)
                    font.pixelSize: 14
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    opacity: (wifiManager.availableNetworks.length === 0 && wifiManager.isPowered && !wifiManager.isRefreshing) ? 1.0 : 0.0
                    visible: opacity > 0.01 && wifiManager.isPowered
                    
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
            modeManager.registerMode("wifi", root)
            if (modeManager.isMode("wifi")) {
                modeManager.bump()
                wifiManager.fullRefresh()
            }
        }
    }
}

