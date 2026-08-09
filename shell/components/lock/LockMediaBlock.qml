import QtQuick
import Qt5Compat.GraphicalEffects
import "../common" as Common

Item {
    id: root

    property string fontFamily: "M PLUS 2"
    property color tint: "white"
    property color faintTint: Qt.rgba(1, 1, 1, 0.5)
    property string iconsBase: ""
    property color accent: "#a68cd9"
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

    readonly property real designPx: height / 221

    readonly property real progress: duration > 0
        ? Math.min(1, Math.max(0, position / duration)) : 0

    function clock(seconds) {
        if (!isFinite(seconds) || seconds < 0) return "00:00"
        const whole = Math.floor(seconds)
        return String(Math.floor(whole / 60)).padStart(2, "0")
            + ":" + String(whole % 60).padStart(2, "0")
    }

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

    // The accent stands in until art arrives; a flat panel reads as unfinished.
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        opacity: root.artUrl === "" ? 1 : 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.20)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.04)
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
        }
    }

    Rectangle {
        id: art
        width: 181 * root.designPx
        height: width
        radius: 14 * root.designPx
        color: Qt.rgba(1, 1, 1, 0.08)
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 24 * root.designPx

        // `clip` ignores the radius and cuts a square, so this needs a mask.
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

    Item {
        id: details

        anchors.left: art.right
        anchors.leftMargin: 36 * root.designPx
        anchors.right: controls.left
        anchors.rightMargin: 36 * root.designPx
        anchors.verticalCenter: parent.verticalCenter
        height: titleLabel.height + artistLabel.height + timeline.height
            + 9 * root.designPx + 20 * root.designPx

        Text {
            id: titleLabel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            text: root.title
            color: root.tint
            elide: Text.ElideRight
            font.family: root.fontFamily
            font.weight: Font.Medium
            font.pixelSize: 30 * root.designPx
        }

        Text {
            id: artistLabel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: titleLabel.bottom
            anchors.topMargin: 9 * root.designPx
            text: root.artist
            color: root.faintTint
            elide: Text.ElideRight
            font.family: root.fontFamily
            font.pixelSize: 12 * root.designPx
            font.letterSpacing: 12 * root.designPx * 0.18
        }

        Item {
            id: timeline

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: artistLabel.bottom
            anchors.topMargin: 20 * root.designPx
            height: 12 * root.designPx

            Text {
                id: elapsedLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 36 * root.designPx
                text: root.clock(root.position)
                color: root.tint
                opacity: 0.62
                font.family: root.fontFamily
                font.pixelSize: 10 * root.designPx
            }

            Text {
                id: totalLabel
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 36 * root.designPx
                horizontalAlignment: Text.AlignRight
                text: root.clock(root.duration)
                color: root.faintTint
                font.family: root.fontFamily
                font.pixelSize: 10 * root.designPx
            }

            Rectangle {
                id: track

                anchors.left: elapsedLabel.right
                anchors.leftMargin: 14 * root.designPx
                anchors.right: totalLabel.left
                anchors.rightMargin: 14 * root.designPx
                anchors.verticalCenter: parent.verticalCenter
                height: Math.max(2, 3 * root.designPx)
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.15)

                Rectangle {
                    id: played
                    width: parent.width * root.progress
                    height: parent.height
                    radius: parent.radius
                    color: root.accent

                    Behavior on width {
                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    x: played.width - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(2, 3 * root.designPx)
                    height: 12 * root.designPx
                    radius: width / 2
                    color: root.tint
                }
            }
        }
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.rightMargin: 24 * root.designPx
        anchors.verticalCenter: parent.verticalCenter
        spacing: 26 * root.designPx

        LockMediaButton {
            size: 30 * root.designPx
            tint: root.tint
            source: root.iconsBase + "/track-previous.svg"
            hitPadding: controls.spacing / 2
            anchors.verticalCenter: parent.verticalCenter
            onActivated: root.previousRequested()
        }

        LockMediaButton {
            size: 46 * root.designPx
            tint: root.accent
            source: root.iconsBase + (root.isPlaying ? "/pause.svg" : "/play.svg")
            hitPadding: controls.spacing / 2
            anchors.verticalCenter: parent.verticalCenter
            onActivated: root.playPauseRequested()
        }

        LockMediaButton {
            size: 30 * root.designPx
            tint: root.tint
            source: root.iconsBase + "/track-next.svg"
            hitPadding: controls.spacing / 2
            anchors.verticalCenter: parent.verticalCenter
            onActivated: root.nextRequested()
        }
    }
}
