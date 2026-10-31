import QtQuick

Item {
    id: ghost

    property var app: null
    property var iconResolver
    property var theme
    property var typo

    width: 88
    height: 98
    rotation: -3
    scale: 1.06
    transformOrigin: Item.Center

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 10
        radius: 15
        color: Qt.rgba(0, 0, 0, 0.45)
    }

    Rectangle {
        anchors.fill: parent
        radius: 15
        color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)

        Column {
            anchors.centerIn: parent
            spacing: 8

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 40
                height: 40
                fillMode: Image.PreserveAspectFit
                smooth: true
                sourceSize: Qt.size(96, 96)
                source: {
                    if (!ghost.app || !ghost.app.icon) return ""
                    let paths = ghost.iconResolver.resolveIconPath(ghost.app.icon)
                    return paths && paths.length > 0 ? "file://" + paths[0] : ""
                }
            }

            Text {
                width: 76
                text: ghost.app ? ghost.app.name : ""
                textFormat: Text.PlainText
                color: ghost.theme ? ghost.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: ghost.typo ? ghost.typo.sizeSmall : 11
                font.family: ghost.typo ? ghost.typo.fontFamily : "M PLUS 2"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }
}
