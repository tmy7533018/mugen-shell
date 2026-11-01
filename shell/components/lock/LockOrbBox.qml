pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects

LockBox {
    id: root

    property real cellH: 0
    property string faceFontFamily: "M PLUS 2"
    property color clockColor: "#f2f3ff"
    property color errorColor: "#ff9db0"
    property string iconsBase: ""

    property string faultText: ""
    property string noticeText: ""
    property bool unlocking: false
    property bool noticeShown: false
    property bool passwordHintShown: false

    Item {
        id: lockIcon

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.cellH * 0.17
        width: root.cellH * 0.13
        height: width

        property real glyphOpacity: root.unlocking ? 0.85 : 0.4

        Behavior on glyphOpacity {
            NumberAnimation { duration: 200 }
        }

        // Under the body, so the feet hide when closed and show as it swings.
        Item {
            width: parent.width
            height: parent.height

            // Lifted first, or the free foot sweeps through the body.
            y: root.unlocking ? -height * 0.15 : 0

            Behavior on y {
                NumberAnimation {
                    duration: 260; easing.type: Easing.OutCubic
                }
            }

            transform: Rotation {
                // Swung about the standing foot, as a shackle clears its body.
                origin.x: lockIcon.width * (9 / 24)
                origin.y: lockIcon.height * (8 / 24)
                // Upright: a tilted axis lands the half turn skewed, not mirrored.
                axis: Qt.vector3d(0, 1, 0)
                angle: root.unlocking ? 180 : 0

                Behavior on angle {
                    NumberAnimation {
                        duration: 380; easing.type: Easing.OutCubic
                    }
                }
            }

            Image {
                id: shackleGlyph
                anchors.fill: parent
                source: root.iconsBase + "/lock-shackle.svg"
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                mipmap: true
                visible: false
            }

            ColorOverlay {
                anchors.fill: parent
                source: shackleGlyph
                color: root.clockColor
                opacity: lockIcon.glyphOpacity
            }
        }

        Image {
            id: bodyGlyph
            anchors.fill: parent
            source: root.iconsBase + "/lock-body.svg"
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            mipmap: true
            visible: false
        }

        ColorOverlay {
            anchors.fill: parent
            source: bodyGlyph
            color: root.clockColor
            opacity: lockIcon.glyphOpacity
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.cellH * 0.17
        width: parent.width * 0.82
        text: root.faultText
        visible: root.faultText !== ""
        color: root.errorColor
        opacity: 0.9
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.family: root.faceFontFamily
        font.pixelSize: Math.round(root.cellH * 0.13)
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.cellH * 0.17
        width: parent.width * 0.9
        text: root.noticeText
        textFormat: Text.PlainText
        color: root.errorColor
        opacity: root.noticeShown ? 0.9 : 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.family: root.faceFontFamily
        font.pixelSize: Math.round(root.cellH * 0.09)

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.cellH * 0.17
        text: "PASSWORD"
        color: root.clockColor
        opacity: root.passwordHintShown ? lockIcon.glyphOpacity : 0
        font.family: root.faceFontFamily
        font.pixelSize: Math.round(root.cellH * 0.09)
        font.letterSpacing: root.cellH * 0.09 * 0.18

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
        }
    }
}
