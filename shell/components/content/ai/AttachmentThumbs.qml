import QtQuick
import Qt5Compat.GraphicalEffects
import "../../../lib" as Theme

Row {
    id: root

    required property var modeManager
    required property var theme
    property var paths: []
    property real thumbSize: modeManager.scale(96)
    property bool removable: false

    signal removeRequested(int index)

    spacing: modeManager.scale(8)

    Repeater {
        model: root.paths

        delegate: Item {
            id: thumb
            required property string modelData
            required property int index

            readonly property string fileName: thumb.modelData.split("/").pop()
            readonly property bool isImage: /\.(png|jpe?g|webp|gif)$/i.test(thumb.modelData)

            width: root.thumbSize
            height: root.thumbSize

            Image {
                id: image
                anchors.fill: parent
                source: thumb.isImage ? "file://" + thumb.modelData : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: root.thumbSize * 2
                asynchronous: true
                smooth: true
                visible: false
            }

            OpacityMask {
                anchors.fill: image
                source: image
                visible: image.status === Image.Ready
                maskSource: Rectangle {
                    width: image.width
                    height: image.height
                    radius: root.modeManager.scale(12)
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: root.modeManager.scale(12)
                visible: !thumb.isImage || image.status === Image.Error
                color: root.theme ? root.theme.surfaceInsetCard : Qt.rgba(0.12, 0.12, 0.18, 0.95)

                Text {
                    anchors.centerIn: parent
                    width: parent.width - root.modeManager.scale(10)
                    horizontalAlignment: Text.AlignHCenter
                    text: thumb.isImage ? "missing" : thumb.fileName
                    elide: Text.ElideMiddle
                    maximumLineCount: 2
                    wrapMode: Text.WrapAnywhere
                    color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.6)
                    font.pixelSize: root.modeManager.scale(10)
                    font.family: "M PLUS 2"
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: root.modeManager.scale(12)
                color: "transparent"
                border.width: 1
                border.color: root.theme ? root.theme.chipInactiveBorder : Qt.rgba(0.55, 0.55, 0.68, 0.25)
            }

            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: -root.modeManager.scale(3)
                width: root.modeManager.scale(18)
                height: width
                radius: width / 2
                visible: root.removable
                color: root.theme ? root.theme.surfaceInsetCard : Qt.rgba(0.12, 0.12, 0.18, 0.95)
                border.width: 1
                border.color: root.theme ? root.theme.chipInactiveBorder : Qt.rgba(0.55, 0.55, 0.68, 0.25)
                opacity: removeHover.hovered ? 1.0 : 0.75

                Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: root.theme ? root.theme.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.95)
                    font.pixelSize: root.modeManager.scale(9)
                    font.family: "M PLUS 2"
                }

                HoverHandler {
                    id: removeHover
                    cursorShape: Qt.PointingHandCursor
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.removeRequested(thumb.index)
                }
            }
        }
    }
}
