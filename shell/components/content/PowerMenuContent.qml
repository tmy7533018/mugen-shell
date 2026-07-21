import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../ui" as UI
import "../../lib" as Theme

FocusScope {
    id: root

    required property var modeManager
    required property var icons
    
    property int currentButtonIndex: -1
    readonly property var requiredBarSize: ({
        "height": modeManager.scale(120),
        "leftMargin": modeManager.scale(620),
        "rightMargin": modeManager.scale(620),
        "topMargin": modeManager.normalBarSize.topMargin,
        "bottomMargin": modeManager.normalBarSize.bottomMargin
    })
    
    function resetAutoCloseTimer() {
        if (modeManager.isMode("powermenu")) modeManager.bump()
    }

    Connections {
        target: modeManager
        function onCurrentModeChanged() {
            if (modeManager.isMode("powermenu")) {
                root.currentButtonIndex = -1
                buttonsRow.updateButtonFocus()
                focusTimer.restart()
            } else {
                root.currentButtonIndex = -1
            }
        }
    }


    Timer {
        id: focusTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            if (buttonsRow) {
                buttonsRow.forceActiveFocus()
                buttonsRow.updateButtonFocus()
            }
        }
    }
    
    MouseArea {
        id: powerMenuBackground
        anchors.fill: parent
        z: 1.5
        enabled: modeManager.isMode("powermenu")
        visible: enabled
        hoverEnabled: true
        
        onClicked: {
            modeManager.closeAllModes()
        }
        
        onPositionChanged: {
            if (modeManager.isMode("powermenu")) {
                modeManager.bump()
            }
        }
    }
    
    RowLayout {
        id: powerMenuLayer
        anchors.fill: parent
        anchors.leftMargin: modeManager.scale(32)
        anchors.rightMargin: modeManager.scale(32)
        anchors.topMargin: 0
        anchors.bottomMargin: 0
        spacing: modeManager.scale(12)
        z: 2
        opacity: 0
        visible: opacity > 0.01
        
        states: [
            State {
                name: "visible"
                when: modeManager.isMode("powermenu")
                PropertyChanges { target: powerMenuLayer; opacity: 1.0 }
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
        
        Item { Layout.fillWidth: true }
        
        RowLayout {
            id: buttonsRow
            spacing: modeManager.scale(16)
            Layout.alignment: Qt.AlignVCenter
            focus: modeManager.isMode("powermenu")
            
            Keys.onPressed: (event) => {
                if (modeManager.isMode("powermenu")) {
                    modeManager.bump()
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.currentButtonIndex >= 0) {
                        executeCurrentButton()
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    modeManager.closeAllModes()
                    event.accepted = true
                } else if (event.key === Qt.Key_Left ||
                          event.key === Qt.Key_H ||
                          (event.key === Qt.Key_Tab && event.modifiers & Qt.ShiftModifier) ||
                          event.key === Qt.Key_Backtab) {
                    if (root.currentButtonIndex < 0) {
                        root.currentButtonIndex = 5
                    } else if (root.currentButtonIndex > 0) {
                        root.currentButtonIndex--
                    } else {
                        root.currentButtonIndex = 5
                    }
                    updateButtonFocus()
                    event.accepted = true
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab) {
                    if (root.currentButtonIndex < 0) {
                        root.currentButtonIndex = 0
                    } else if (root.currentButtonIndex < 5) {
                        root.currentButtonIndex++
                    } else {
                        root.currentButtonIndex = 0
                    }
                    updateButtonFocus()
                    event.accepted = true
                } else {
                    event.accepted = false
                }
            }

            function executeCurrentButton() {
                switch(root.currentButtonIndex) {
                    case 0:
                        lockButton.clicked()
                        break
                    case 1:
                        logoutButton.clicked()
                        break
                    case 2:
                        sleepButton.clicked()
                        break
                    case 3:
                        rebootButton.clicked()
                        break
                    case 4:
                        shutdownButton.clicked()
                        break
                    case 5:
                        settingsButton.clicked()
                        break
                }
            }

            function updateButtonFocus() {
                lockButton.isFocused = (root.currentButtonIndex === 0)
                logoutButton.isFocused = (root.currentButtonIndex === 1)
                sleepButton.isFocused = (root.currentButtonIndex === 2)
                rebootButton.isFocused = (root.currentButtonIndex === 3)
                shutdownButton.isFocused = (root.currentButtonIndex === 4)
                settingsButton.isFocused = (root.currentButtonIndex === 5)
            }

            Component.onCompleted: {
                updateButtonFocus()
            }

            UI.PowerButton {
                id: lockButton
                modeManager: root.modeManager
                icon: icons.iconData.lock.type === "text" ? icons.iconData.lock.value : ""
                iconSource: icons.iconData.lock.type === "svg" ? icons.iconData.lock.value : ""
                label: "Lock"
                color: Qt.rgba(0.45, 0.65, 0.90, 1.0)
                onClicked: {
                    root.resetAutoCloseTimer()
                    Theme.Hypr.exec("hyprlock")
                    modeManager.closeAllModes()
                }
            }

            UI.PowerButton {
                id: logoutButton
                modeManager: root.modeManager
                icon: icons.iconData.logout.type === "text" ? icons.iconData.logout.value : ""
                iconSource: icons.iconData.logout.type === "svg" ? icons.iconData.logout.value : ""
                label: "Logout"
                color: Qt.rgba(0.65, 0.55, 0.85, 1.0)
                onClicked: {
                    root.resetAutoCloseTimer()
                    Theme.Hypr.exit()
                }
            }

            UI.PowerButton {
                id: sleepButton
                modeManager: root.modeManager
                icon: icons.iconData.sleep.type === "text" ? icons.iconData.sleep.value : ""
                iconSource: icons.iconData.sleep.type === "svg" ? icons.iconData.sleep.value : ""
                label: "Sleep"
                color: Qt.rgba(0.55, 0.75, 0.85, 1.0)
                onClicked: {
                    root.resetAutoCloseTimer()
                    Theme.Hypr.exec("systemctl suspend")
                    modeManager.closeAllModes()
                }
            }

            UI.PowerButton {
                id: rebootButton
                modeManager: root.modeManager
                icon: icons.iconData.reboot.type === "text" ? icons.iconData.reboot.value : ""
                iconSource: icons.iconData.reboot.type === "svg" ? icons.iconData.reboot.value : ""
                label: "Reboot"
                color: Qt.rgba(0.85, 0.65, 0.45, 1.0)
                onClicked: {
                    root.resetAutoCloseTimer()
                    rebootProcess.running = true
                }
            }

            UI.PowerButton {
                id: shutdownButton
                modeManager: root.modeManager
                icon: icons.iconData.shutdown.type === "text" ? icons.iconData.shutdown.value : ""
                iconSource: icons.iconData.shutdown.type === "svg" ? icons.iconData.shutdown.value : ""
                label: "Shutdown"
                color: Qt.rgba(0.90, 0.45, 0.55, 1.0)
                onClicked: {
                    root.resetAutoCloseTimer()
                    shutdownProcess.running = true
                }
            }

            UI.PowerButton {
                id: settingsButton
                modeManager: root.modeManager
                icon: icons.iconData.settings.type === "text" ? icons.iconData.settings.value : ""
                iconSource: icons.iconData.settings.type === "svg" ? icons.iconData.settings.value : ""
                label: "Settings"
                color: Qt.rgba(0.72, 0.72, 0.82, 1.0)
                onClicked: {
                    if (modeManager) modeManager.closeAllModes()
                    Theme.Hypr.exec("~/.config/quickshell/mugen-shell/scripts/toggle-settings.sh")
                }
            }
        }
        
        Item { Layout.fillWidth: true }
    }
    
    Process {
        id: rebootProcess
        command: ["bash", "-c", "systemctl reboot"]
        running: false
    }
    
    Process {
        id: shutdownProcess
        command: ["bash", "-c", "systemctl poweroff"]
        running: false
    }
    
    Component.onCompleted: {
        if (modeManager) {
            modeManager.registerMode("powermenu", root)
            if (modeManager.isMode("powermenu")) {
                modeManager.bump()
                root.currentButtonIndex = -1
                buttonsRow.updateButtonFocus()
                focusTimer.restart()
            }
        }
    }
}
