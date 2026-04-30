import QtQuick
import QtQuick.Layouts
import "../../ui" as UI

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

    Text {
        id: volumeTextMeasure
        visible: false
        text: "100%"
        font.family: volumeContainer.typo ? volumeContainer.typo.clockStyle.family : "M PLUS 2"
        font.pixelSize: volumeContainer.typo ? volumeContainer.typo.clockStyle.size : 14
        font.weight: volumeContainer.typo ? volumeContainer.typo.clockStyle.weight : Font.Normal
        font.letterSpacing: volumeContainer.typo ? volumeContainer.typo.clockStyle.letterSpacing : 0
    }

    readonly property real volumePercentTextWidth: Math.ceil(volumeTextMeasure.implicitWidth * 1.05)

    state: volumeMouseArea.containsMouse ? "hovered" : "normal"

    states: [
        State {
            name: "normal"
            PropertyChanges { target: volumeIconSvg; opacity: 0.6; scale: 1.0 }
            PropertyChanges { target: volumeIcon; opacity: 0.6; scale: 1.0 }
            PropertyChanges { target: volumePercentText; opacity: 0; scale: 1.0 }
        },
        State {
            name: "hovered"
            PropertyChanges { target: volumeIconSvg; opacity: 0; scale: 0.8 }
            PropertyChanges { target: volumeIcon; opacity: 0; scale: 0.8 }
            PropertyChanges { target: volumePercentText; opacity: 1.0; scale: 1.3 }
        }
    ]

    transitions: [
        Transition {
            from: "normal"; to: "hovered"
            PropertyAnimation {
                target: volumeIconSvg
                properties: "opacity,scale"
                duration: 300
                easing.type: Easing.OutCubic
            }
            PropertyAnimation {
                target: volumeIcon
                properties: "opacity,scale"
                duration: 300
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                PauseAnimation { duration: 150 }
                ParallelAnimation {
                    PropertyAnimation {
                        target: volumePercentText
                        property: "opacity"
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                    PropertyAnimation {
                        target: volumePercentText
                        property: "scale"
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
            }
        },
        Transition {
            from: "hovered"; to: "normal"
            PropertyAnimation {
                targets: [volumeIconSvg, volumeIcon, volumePercentText]
                properties: "opacity,scale"
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
    ]

    property string currentIconSource: ""
    property string currentIconText: ""
    property bool currentIconIsSvg: true
    property bool isInitialized: false

    function updateIcon(animate) {
        if (!volumeContainer.icons || !volumeContainer.audioManager) return

        let iconData = volumeContainer.icons.getVolumeIcon(
            volumeContainer.audioManager.volume,
            volumeContainer.audioManager.isMuted,
            volumeContainer.audioManager.isHeadphone
        )

        let newSource = iconData.type === "svg" ? iconData.value : ""
        let newText = iconData.type === "text" ? iconData.value : ""
        let newIsSvg = iconData.type === "svg"

        if (newSource !== currentIconSource || newText !== currentIconText || newIsSvg !== currentIconIsSvg) {
            if (animate && isInitialized) {
                iconChangeAnimation.start()
            } else {
                currentIconSource = newSource
                currentIconText = newText
                currentIconIsSvg = newIsSvg
                volumeIconSvg.opacity = volumeContainer.state === "hovered" ? 0 : 0.6
                volumeIcon.opacity = volumeContainer.state === "hovered" ? 0 : 0.6
            }
        }
    }

    SequentialAnimation {
        id: iconChangeAnimation
        running: false

        ParallelAnimation {
            NumberAnimation {
                target: volumeIconSvg
                property: "opacity"
                from: volumeIconSvg.opacity
                to: 0
                duration: 200
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: volumeIcon
                property: "opacity"
                from: volumeIcon.opacity
                to: 0
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }

        PropertyAction {
            target: volumeContainer
            property: "currentIconSource"
            value: {
                if (!volumeContainer.icons || !volumeContainer.audioManager) return ""
                let iconData = volumeContainer.icons.getVolumeIcon(
                    volumeContainer.audioManager.volume,
                    volumeContainer.audioManager.isMuted,
                    volumeContainer.audioManager.isHeadphone
                )
                return iconData.type === "svg" ? iconData.value : ""
            }
        }
        PropertyAction {
            target: volumeContainer
            property: "currentIconText"
            value: {
                if (!volumeContainer.icons || !volumeContainer.audioManager) return ""
                let iconData = volumeContainer.icons.getVolumeIcon(
                    volumeContainer.audioManager.volume,
                    volumeContainer.audioManager.isMuted,
                    volumeContainer.audioManager.isHeadphone
                )
                return iconData.type === "text" ? iconData.value : ""
            }
        }
        PropertyAction {
            target: volumeContainer
            property: "currentIconIsSvg"
            value: {
                if (!volumeContainer.icons || !volumeContainer.audioManager) return true
                let iconData = volumeContainer.icons.getVolumeIcon(
                    volumeContainer.audioManager.volume,
                    volumeContainer.audioManager.isMuted,
                    volumeContainer.audioManager.isHeadphone
                )
                return iconData.type === "svg"
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: volumeIconSvg
                property: "opacity"
                from: 0
                to: volumeContainer.state === "hovered" ? 0 : 0.6
                duration: 200
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: volumeIcon
                property: "opacity"
                from: 0
                to: volumeContainer.state === "hovered" ? 0 : 0.6
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }
    }

    Component.onCompleted: {
        if (volumeContainer.audioManager && volumeContainer.audioManager.headphoneReady) {
            updateIcon(false)
        }
        isInitialized = true
    }

    Connections {
        target: volumeContainer.audioManager
        function onVolumeChanged() { volumeContainer.updateIcon(true) }
        function onIsMutedChanged() { volumeContainer.updateIcon(true) }
        function onIsHeadphoneChanged() { volumeContainer.updateIcon(true) }
        function onHeadphoneReadyChanged() { volumeContainer.updateIcon(false) }
    }

    UI.SvgIcon {
        id: volumeIconSvg
        anchors.centerIn: parent
        width: volumeContainer.scaled(24)
        height: volumeContainer.scaled(24)
        source: volumeContainer.currentIconSource
        color: volumeContainer.theme ? volumeContainer.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        visible: volumeContainer.currentIconIsSvg && volumeContainer.currentIconSource !== ""
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
        color: volumeContainer.theme ? volumeContainer.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        visible: !volumeContainer.currentIconIsSvg && volumeContainer.currentIconText !== ""
    }

    Text {
        id: volumePercentText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: volumeContainer.scaled(-1)
        text: volumeContainer.audioManager ? (volumeContainer.audioManager.isMuted ? "—" : volumeContainer.audioManager.volume.toString()) : "0"
        color: volumeContainer.theme ? volumeContainer.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
        font.family: volumeContainer.typo ? volumeContainer.typo.clockStyle.family : "M PLUS 2"
        font.pixelSize: volumeContainer.scaled(volumeContainer.typo ? volumeContainer.typo.clockStyle.size : 14)
        font.weight: volumeContainer.typo ? volumeContainer.typo.clockStyle.weight : Font.Normal
        font.letterSpacing: volumeContainer.typo ? volumeContainer.typo.clockStyle.letterSpacing : 0
        font.hintingPreference: volumeContainer.typo ? volumeContainer.typo.clockStyle.hinting : Font.PreferDefaultHinting
        font.kerning: volumeContainer.typo ? volumeContainer.typo.clockStyle.kerning : true

        Behavior on color {
            ColorAnimation { duration: 400; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        id: volumeMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (volumeContainer.modeManager) {
                volumeContainer.modeManager.switchMode("volume")
            }
        }
    }
}
