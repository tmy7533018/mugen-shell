pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property real cornerRadius: 24
    property real fillStrength: 0.55
    property Component background: null

    default property alias content: contentHost.data

    Rectangle {
        id: plate
        anchors.fill: parent
        radius: root.cornerRadius
        color: Qt.rgba(0.06, 0.06, 0.09, root.fillStrength)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)
    }

    Loader {
        anchors.fill: parent
        active: root.background !== null
        sourceComponent: root.background
    }

    Item {
        id: contentHost
        anchors.fill: parent
    }
}
