pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property real cornerRadius: 24

    default property alias content: contentHost.data

    Rectangle {
        id: plate
        anchors.fill: parent
        radius: root.cornerRadius
        color: Qt.rgba(0.06, 0.06, 0.09, 0.55)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)
    }

    Item {
        id: contentHost
        anchors.fill: parent
    }
}
