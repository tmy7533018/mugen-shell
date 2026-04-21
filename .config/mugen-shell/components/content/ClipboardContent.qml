import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import "../ui" as UI
import "../common" as Common

FocusScope {
    id: root
    
    required property var modeManager
    required property var clipboardManager
    property var theme
    property var icons
    
    readonly property var requiredBarSize: ({
        "height": modeManager.scale(420),
        "leftMargin": modeManager.scale(700),
        "rightMargin": modeManager.scale(700),
        "topMargin": modeManager.scale(6),
        "bottomMargin": modeManager.scale(6)
    })
    
    property var history: clipboardManager ? clipboardManager.history : []
    property int currentIndex: -1

    Timer {
        id: autoCloseTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            if (modeManager.isMode("clipboard")) {
                modeManager.closeAllModes()
            }
        }
    }
    
    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("clipboard")) {
                clipboardManager.loadHistory()
                currentIndex = -1
                autoCloseTimer.restart()
                focusTimer.restart()
            } else {
                autoCloseTimer.stop()
                currentIndex = -1
            }
        }
    }
    
    Timer {
        id: focusTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (clipboardLayer) {
                clipboardLayer.forceActiveFocus()
            }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        z: 1.5
        enabled: modeManager.isMode("clipboard")
        visible: enabled
        hoverEnabled: true
        
        onClicked: {
            modeManager.closeAllModes()
        }
        
        onPositionChanged: {
            if (modeManager.isMode("clipboard")) {
                autoCloseTimer.restart()
            }
        }
    }
    
    Item {
        id: clipboardLayer
        anchors.fill: parent
        anchors.leftMargin: modeManager.scale(32)
        anchors.rightMargin: modeManager.scale(32)
        z: 2
        
        focus: modeManager.isMode("clipboard")
        
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                modeManager.closeAllModes()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (currentIndex >= 0 && currentIndex < history.length) {
                    let item = history[currentIndex]
                    clipboardManager.selectItem(item.id)
                    modeManager.closeAllModes()
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                if (currentIndex < 0 && history.length > 0) {
                    currentIndex = 0
                } else if (currentIndex < history.length - 1) {
                    currentIndex++
                } else {
                    currentIndex = 0
                }
                clipboardList.positionViewAtIndex(currentIndex, ListView.Contain)
                event.accepted = true
                autoCloseTimer.restart()
            } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_Backtab && event.modifiers & Qt.ShiftModifier)) {
                if (currentIndex < 0 && history.length > 0) {
                    currentIndex = history.length - 1
                } else if (currentIndex > 0) {
                    currentIndex--
                } else {
                    currentIndex = history.length - 1
                }
                clipboardList.positionViewAtIndex(currentIndex, ListView.Contain)
                event.accepted = true
                autoCloseTimer.restart()
            } else if (event.key === Qt.Key_Home) {
                if (history.length > 0) {
                    currentIndex = 0
                    clipboardList.positionViewAtIndex(0, ListView.Contain)
                }
                event.accepted = true
                autoCloseTimer.restart()
            } else if (event.key === Qt.Key_End) {
                if (history.length > 0) {
                    currentIndex = history.length - 1
                    clipboardList.positionViewAtIndex(currentIndex, ListView.Contain)
                }
                event.accepted = true
                autoCloseTimer.restart()
            }
        }
        
        opacity: 0
        visible: opacity > 0.01
        
        states: [
            State {
                name: "visible"
                when: modeManager.isMode("clipboard")
                PropertyChanges { target: clipboardLayer; opacity: 1.0 }
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
            spacing: 16
            
            Common.GlowText {
                Layout.alignment: Qt.AlignHCenter
                text: "Clipboard"
                font.pixelSize: 20
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
            
            Item {
                Layout.preferredWidth: modeManager.scale(420)
                Layout.preferredHeight: modeManager.scale(320)
                clip: true
                
                Text {
                    anchors.centerIn: parent
                    text: history.length === 0 ? (clipboardManager.isLoading ? "Loading..." : "No clipboard items") : ""
                    color: Qt.rgba(0.72, 0.72, 0.82, 0.50)
                    font.pixelSize: 16
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    visible: history.length === 0
                }
                
                ListView {
                    id: clipboardList
                    anchors.fill: parent
                    spacing: 8
                    clip: true
                    model: history
                    
                    onCurrentIndexChanged: {
                        if (root.currentIndex !== currentIndex && currentIndex >= 0) {
                            root.currentIndex = currentIndex
                        }
                    }
                    
                    Connections {
                        target: root
                        function onCurrentIndexChanged() {
                            if (clipboardList.currentIndex !== root.currentIndex && root.currentIndex >= 0) {
                                clipboardList.currentIndex = root.currentIndex
                            }
                        }
                    }
                    
                    add: Transition {
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
                    
                    displaced: Transition {
                        NumberAnimation {
                            property: "y"
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                    
                    delegate: Rectangle {
                        id: delegateRoot
                        width: clipboardList.width
                        height: 60
                        
                        readonly property bool isCurrent: root.currentIndex === index
                        readonly property bool isActive: isCurrent || itemMouseArea.containsMouse
                        
                        color: isActive ? Qt.rgba(0, 0, 0, 0.75) : Qt.rgba(0, 0, 0, 0.65)
                        radius: isActive ? 20 : height / 2
                        border.width: 0
                        
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        Behavior on radius {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        layer.enabled: true
                        layer.effect: Glow {
                            samples: 12
                            radius: 6
                            spread: 0.3
                            color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.15) : Qt.rgba(0.65, 0.55, 0.85, 0.15)
                            transparentBorder: true
                        }
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: modeManager.scale(20)
                            anchors.rightMargin: modeManager.scale(20)
                            spacing: 12
                            
                            UI.SvgIcon {
                                width: 20
                                height: 20
                                source: icons ? icons.iconData.clipboard.value : ""
                                color: theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                                opacity: 0.8
                                visible: icons && icons.iconData.clipboard.type === "svg"
                            }
                            
                            Text {
                                text: "📋"
                                font.pixelSize: 20
                                opacity: 0.8
                                visible: !icons || icons.iconData.clipboard.type !== "svg"
                            }
                            
                            Text {
                                Layout.fillWidth: true
                                text: modelData ? modelData.preview : ""
                                color: Qt.rgba(0.92, 0.92, 0.96, 0.90)
                                font.pixelSize: 14
                                font.family: "M PLUS 2"
                                elide: Text.ElideRight
                            }
                        }
                        
                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: {
                                if (modelData) {
                                    clipboardManager.selectItem(modelData.id)
                                    modeManager.closeAllModes()
                                }
                            }
                            
                            onPositionChanged: {
                                root.currentIndex = index
                                autoCloseTimer.restart()
                            }
                        }
                    }
                }
            }
        }
    }
    
    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("clipboard", root)
            if (modeManager.isMode("clipboard")) {
                clipboardManager.loadHistory()
                currentIndex = -1
                autoCloseTimer.restart()
                focusTimer.restart()
            }
        }
    }
}

