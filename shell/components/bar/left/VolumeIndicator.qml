import QtQuick
import QtQuick.Layouts
import "../../common" as Common
import "../../../lib" as Theme

Item {
    id: volumeContainer

    required property var theme
    required property var typo
    required property var icons
    required property var modeManager
    required property var audioManager

    function scaled(v) { return modeManager ? modeManager.scale(v) : v }

    implicitWidth: scaled(24)
    implicitHeight: scaled(24)
    Layout.alignment: Qt.AlignVCenter
    Layout.leftMargin: 0
    Layout.rightMargin: 0

    property string currentVariant: ""
    property string currentIconText: ""
    property bool currentIconIsSvg: true
    property bool isInitialized: false

    readonly property color iconColor: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)

    function iconData() {
        if (!icons || !audioManager) return null
        return icons.getVolumeIcon(audioManager.volume, audioManager.isMuted, audioManager.isHeadphone)
    }

    function applyIcon() {
        const data = iconData()
        if (!data) return
        currentIconIsSvg = data.type === "svg"
        currentVariant = data.type === "svg" ? data.variant : ""
        currentIconText = data.type === "text" ? data.value : ""
    }

    function iconChanged() {
        const data = iconData()
        if (!data) return false
        const variant = data.type === "svg" ? data.variant : ""
        const text = data.type === "text" ? data.value : ""
        return variant !== currentVariant || text !== currentIconText || (data.type === "svg") !== currentIconIsSvg
    }

    function updateIcon(animate) {
        if (!iconChanged()) return
        if (animate && isInitialized) {
            iconChangeAnimation.start()
        } else {
            applyIcon()
        }
    }

    function ring() {
        if (rigLoader.item) rigLoader.item.play()
    }

    function ringIfIdle() {
        if (rigLoader.item && !rigLoader.item.playing) rigLoader.item.play()
    }

    Component {
        id: waveRig
        Common.VolumeRig {
            color: volumeContainer.iconColor
            variant: volumeContainer.currentVariant
        }
    }
    Component {
        id: muteRig
        Common.ShakeRig {
            color: volumeContainer.iconColor
            source: volumeContainer.icons ? volumeContainer.icons.volumeMutedSvg : ""
        }
    }

    Item {
        id: iconStack
        anchors.fill: parent

        Loader {
            id: rigLoader
            anchors.centerIn: parent
            width: volumeContainer.scaled(24)
            height: volumeContainer.scaled(24)
            active: volumeContainer.currentIconIsSvg && volumeContainer.currentVariant !== ""
            sourceComponent: volumeContainer.currentVariant === "muted" ? muteRig : waveRig
            opacity: volumeMouseArea.containsMouse ? 1.0 : 0.6

            Behavior on opacity {
                NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic }
            }
        }

        Text {
            id: volumeIcon
            anchors.centerIn: parent
            text: volumeContainer.currentIconText
            font.family: volumeContainer.typo ? volumeContainer.typo.clockStyle.family : "M PLUS 2"
            font.pixelSize: volumeContainer.scaled(volumeContainer.typo ? volumeContainer.typo.clockStyle.size : 14)
            font.weight: volumeContainer.typo ? volumeContainer.typo.clockStyle.weight : Font.Normal
            font.letterSpacing: volumeContainer.typo ? volumeContainer.typo.clockStyle.letterSpacing : 0
            font.hintingPreference: volumeContainer.typo ? volumeContainer.typo.clockStyle.hinting : Font.PreferDefaultHinting
            font.kerning: volumeContainer.typo ? volumeContainer.typo.clockStyle.kerning : true
            color: volumeContainer.iconColor
            visible: !volumeContainer.currentIconIsSvg && volumeContainer.currentIconText !== ""
            opacity: volumeMouseArea.containsMouse ? 1.0 : 0.6

            Behavior on opacity {
                NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic }
            }
        }
    }

    SequentialAnimation {
        id: iconChangeAnimation
        running: false

        NumberAnimation {
            target: iconStack
            property: "opacity"
            to: 0
            duration: Theme.Motion.fast
            easing.type: Easing.InOutQuad
        }
        ScriptAction { script: volumeContainer.applyIcon() }
        NumberAnimation {
            target: iconStack
            property: "opacity"
            to: 1
            duration: Theme.Motion.fast
            easing.type: Easing.InOutQuad
        }
        ScriptAction { script: volumeContainer.ring() }
    }

    Component.onCompleted: {
        if (volumeContainer.audioManager && volumeContainer.audioManager.headphoneReady) {
            updateIcon(false)
        }
        isInitialized = true
    }

    Connections {
        target: volumeContainer.audioManager
        function onVolumeChanged() {
            volumeContainer.updateIcon(true)
            if (!iconChangeAnimation.running) volumeContainer.ringIfIdle()
        }
        function onIsMutedChanged() {
            volumeContainer.updateIcon(true)
            if (!iconChangeAnimation.running) volumeContainer.ringIfIdle()
        }
        function onIsHeadphoneChanged() { volumeContainer.updateIcon(true) }
        function onHeadphoneReadyChanged() { volumeContainer.updateIcon(false) }
    }

    MouseArea {
        id: volumeMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: volumeContainer.ring()
        onClicked: {
            if (volumeContainer.modeManager) {
                volumeContainer.modeManager.switchMode("volume")
            }
        }
    }
}
