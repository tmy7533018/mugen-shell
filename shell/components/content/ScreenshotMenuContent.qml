import QtQuick
import QtQuick.Layouts
import "../ui" as UI
import "../../lib" as Theme

FocusScope {
    id: root

    required property var modeManager
    required property var screenshotManager
    required property var icons
    property var theme

    readonly property var requiredBarSize: ({
        "height": modeManager.scale(120),
        "leftMargin": modeManager.scale(700),
        "rightMargin": modeManager.scale(700),
        "topMargin": modeManager.normalBarSize.topMargin,
        "bottomMargin": modeManager.normalBarSize.bottomMargin
    })

    property int currentIndex: -1

    function choose(mode) {
        if (mode === "") {
            modeManager.switchMode("screenshot-gallery")
            return
        }
        screenshotManager.capture(mode)
        modeManager.closeAllModes()
    }

    function enter() {
        currentIndex = -1
        focusTimer.restart()
        modeManager.bump()
    }

    // The loader activates because the mode changed, so the signal below is already past on open.
    Component.onCompleted: {
        modeManager.registerMode("screenshot-menu", root)
        if (modeManager.isMode("screenshot-menu")) enter()
    }

    Connections {
        target: root.modeManager
        function onCurrentModeChanged() {
            if (root.modeManager.isMode("screenshot-menu")) root.enter()
        }
    }

    Timer {
        id: focusTimer
        interval: 500
        onTriggered: buttonsRow.forceActiveFocus()
    }

    MouseArea {
        anchors.fill: parent
        z: 1.5
        enabled: root.modeManager.isMode("screenshot-menu")
        visible: enabled
        hoverEnabled: true

        onClicked: root.modeManager.closeAllModes()
        onPositionChanged: root.modeManager.bump()
    }

    // Above the closing layer so a click on the panel itself only keeps it awake.
    MouseArea {
        anchors.fill: parent
        anchors.topMargin: root.requiredBarSize.topMargin
        anchors.bottomMargin: root.requiredBarSize.bottomMargin
        anchors.leftMargin: root.requiredBarSize.leftMargin
        anchors.rightMargin: root.requiredBarSize.rightMargin
        z: 1.8
        enabled: root.modeManager.isMode("screenshot-menu")
        visible: enabled
        hoverEnabled: true

        onClicked: root.modeManager.bump()
        onPositionChanged: root.modeManager.bump()
    }

    RowLayout {
        id: buttonsRow
        anchors.centerIn: parent
        z: 2
        spacing: root.modeManager.scale(16)
        focus: root.modeManager.isMode("screenshot-menu")

        opacity: 0
        visible: opacity > 0.01

        states: [
            State {
                name: "visible"
                when: root.modeManager.isMode("screenshot-menu")
                PropertyChanges { target: buttonsRow; opacity: 1.0 }
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
                    // The bar is still growing; the content would otherwise appear mid-morph.
                    PauseAnimation { duration: Theme.Motion.standard }
                    NumberAnimation {
                        property: "opacity"
                        duration: Theme.Motion.gentle
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        ]

        Keys.onPressed: (event) => {
            root.modeManager.bump()
            if (event.key === Qt.Key_Escape) {
                root.modeManager.closeAllModes()
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.currentIndex === 0) regionButton.clicked()
                else if (root.currentIndex === 1) windowButton.clicked()
                else if (root.currentIndex === 2) screenButton.clicked()
                else if (root.currentIndex === 3) galleryButton.clicked()
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab) {
                root.currentIndex = root.currentIndex < 3 ? root.currentIndex + 1 : 0
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Backtab) {
                root.currentIndex = root.currentIndex <= 0 ? 3 : root.currentIndex - 1
            } else {
                event.accepted = false
                return
            }
            event.accepted = true
        }

        UI.PowerButton {
            id: regionButton
            modeManager: root.modeManager
            label: "Region"
            iconSource: root.icons ? root.icons.captureRegionSvg : ""
            color: Qt.rgba(0.45, 0.65, 0.90, 1.0)
            isFocused: root.currentIndex === 0
            onClicked: root.choose("region")
        }

        UI.PowerButton {
            id: windowButton
            modeManager: root.modeManager
            label: "Window"
            iconSource: root.icons ? root.icons.captureWindowSvg : ""
            color: Qt.rgba(0.65, 0.55, 0.85, 1.0)
            isFocused: root.currentIndex === 1
            onClicked: root.choose("window")
        }

        UI.PowerButton {
            id: screenButton
            modeManager: root.modeManager
            label: "Full Screen"
            iconSource: root.icons ? root.icons.captureScreenSvg : ""
            color: Qt.rgba(0.55, 0.75, 0.85, 1.0)
            isFocused: root.currentIndex === 2
            onClicked: root.choose("screen")
        }

        UI.PowerButton {
            id: galleryButton
            modeManager: root.modeManager
            label: "Gallery"
            iconSource: root.icons ? root.icons.captureGallerySvg : ""
            color: Qt.rgba(0.88, 0.74, 0.48, 1.0)
            isFocused: root.currentIndex === 3
            onClicked: root.choose("")
        }
    }
}
