import QtQuick
import Quickshell
import Quickshell.Io
import "../../lib" as Theme

Item {
    id: root

    required property var theme
    required property var imeStatus
    property var modeManager

    function scaled(val) {
        if (modeManager) return modeManager.scale(val)
        return val
    }

    signal clicked()

    property Process toggleProcess: Process {
        command: ["fcitx5-remote", "-t"]
        running: false
    }

    implicitWidth: scaled(23)
    implicitHeight: scaled(23)

    property bool hovered: false
    property real hoverScale: 1.0
    property real pulseScale: 1.0
    
    Behavior on hoverScale {
        NumberAnimation { duration: Theme.Motion.slow; easing.type: Easing.OutCubic }
    }



    SequentialAnimation {
        id: pulseAnimation
        running: false
        alwaysRunToEnd: true
        loops: 1

        PropertyAnimation {
            target: root
            property: "pulseScale"
            to: 1.12
            duration: 130
            easing.type: Easing.OutCubic
        }
        PropertyAnimation {
            target: root
            property: "pulseScale"
            to: 1.0
            duration: Theme.Motion.fast
            easing.type: Easing.InCubic
        }
    }

    Connections {
        target: root.imeStatus
        function onDisplayTextChanged() {
            pulseAnimation.restart()
        }
        function onTextChanged() {
            pulseAnimation.restart()
        }
    }

    readonly property string japaneseIcon: Quickshell.shellDir + "/assets/icons/japanese-aquare.svg"
    readonly property string englishIcon: Quickshell.shellDir + "/assets/icons/english-aquare.svg"
    readonly property string fallbackIcon: englishIcon

    function resolveIconSource() {
        if (!root.imeStatus || !root.imeStatus.displayText) {
            return fallbackIcon
        }
        const text = root.imeStatus.displayText
        if (text === "あ") {
            return japaneseIcon
        }
        if (text === "JP" || text === "US") {
            return englishIcon
        }
        return fallbackIcon
    }

    SvgIcon {
        id: frameIcon
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        source: resolveIconSource()
        color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        opacity: root.hovered ? 1.0 : 0.6
        
        // Scaled here, not on root, so the blob doesn't scale with it
        scale: root.hoverScale * root.pulseScale

        Behavior on opacity {
            NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: {
            root.hovered = true
            root.hoverScale = 1.2
        }
        onExited: {
            root.hovered = false
            root.hoverScale = 1.0
        }
        onCanceled: {
            root.hovered = false
            root.hoverScale = 1.0
        }
        onClicked: {
            root.toggleProcess.running = true
            root.clicked()
        }
    }

    Component.onCompleted: {
        hoverScale = 1.0
        pulseScale = 1.0
    }
}

