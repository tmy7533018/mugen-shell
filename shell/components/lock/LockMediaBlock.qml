import QtQuick
import Qt5Compat.GraphicalEffects
import "../common" as Common

Item {
    id: root

    property var typo
    property color tint: "white"
    property color faintTint: Qt.rgba(1, 1, 1, 0.5)
    property string iconsBase: ""
    property real cornerRadius: 24

    property bool isPlaying: false
    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property real position: 0
    property real duration: 0

    signal previousRequested
    signal playPauseRequested
    signal nextRequested

    readonly property real unit: height

    // Same treatment as the bar's music module: a blurred, cross-fading album
    // art behind a scrim rather than a flat panel.
    Common.CrossfadeArt {
        id: artBackdrop
        anchors.fill: parent
        visible: false
        source: root.artUrl
        frameWidth: root.width
        frameHeight: root.height
        blurRadius: 64
        blurTexels: 96
    }

    OpacityMask {
        anchors.fill: parent
        source: artBackdrop
        opacity: root.artUrl === "" ? 0 : 1
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.cornerRadius
        }

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: Qt.rgba(0.05, 0.04, 0.08, 0.55)
    }

    Rectangle {
        id: art
        width: root.unit * 0.56
        height: width
        radius: root.unit * 0.09
        color: Qt.rgba(1, 1, 1, 0.08)
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.unit * 0.14

        // `clip` ignores the radius and cuts a square, so the rounded thumbnail
        // needs a mask of its own.
        Image {
            id: artImage
            anchors.fill: parent
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        OpacityMask {
            anchors.fill: parent
            source: artImage
            visible: artImage.status === Image.Ready
            maskSource: Rectangle {
                width: art.width
                height: art.height
                radius: art.radius
            }
        }
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: root.unit * 0.14
        anchors.right: controls.left
        anchors.rightMargin: root.unit * 0.14
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.unit * 0.045

        Text {
            width: parent.width
            text: root.title
            color: root.tint
            elide: Text.ElideRight
            font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
            font.pixelSize: root.unit * 0.145
        }

        Text {
            width: parent.width
            text: root.artist
            color: root.faintTint
            elide: Text.ElideRight
            font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
            font.pixelSize: root.unit * 0.115
        }

        Item { width: 1; height: root.unit * 0.06 }

        Rectangle {
            width: parent.width
            height: Math.max(2, root.unit * 0.018)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.15)

            Rectangle {
                width: parent.width * (root.duration > 0
                    ? Math.min(1, Math.max(0, root.position / root.duration)) : 0)
                height: parent.height
                radius: parent.radius
                color: root.tint
                opacity: 0.8

                Behavior on width {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.rightMargin: root.unit * 0.18
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.unit * 0.11

        LockMediaButton {
            size: root.unit * 0.15
            tint: root.tint
            source: root.iconsBase + "/track-previous.svg"
            anchors.verticalCenter: parent.verticalCenter
            onActivated: root.previousRequested()
        }

        LockMediaButton {
            size: root.unit * 0.18
            tint: root.tint
            source: root.iconsBase + (root.isPlaying ? "/pause.svg" : "/play.svg")
            anchors.verticalCenter: parent.verticalCenter
            onActivated: root.playPauseRequested()
        }

        LockMediaButton {
            size: root.unit * 0.15
            tint: root.tint
            source: root.iconsBase + "/track-next.svg"
            anchors.verticalCenter: parent.verticalCenter
            onActivated: root.nextRequested()
        }
    }
}
