import QtQuick
import QtQuick.Layouts

Item {
    id: root
    
    property var model: []
    property int currentIndex: 0
    property var theme
    
    signal activated(int index)
    
    implicitWidth: 200
    implicitHeight: 36
    
    readonly property int itemCount: root.model.length > 0 ? root.model.length : 1
    readonly property real segmentWidth: root.width / root.itemCount
    
    Rectangle {
        anchors.fill: parent
        color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.1) : Qt.rgba(0.65, 0.55, 0.85, 0.1)
        radius: 18
        border.width: 1
        border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)
    }
    
    Rectangle {
        id: indicator
        width: root.segmentWidth - 4
        height: parent.height - 4
        anchors.verticalCenter: parent.verticalCenter
        x: root.currentIndex * root.segmentWidth + 2
        color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.3) : Qt.rgba(0.65, 0.55, 0.85, 0.3)
        radius: 16
        border.width: 1
        border.color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
        visible: root.model.length > 0
        
        Behavior on x {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
        
        Behavior on color {
            ColorAnimation { duration: 200 }
        }
    }
    
    Row {
        anchors.fill: parent
        anchors.margins: 2
        visible: root.model.length > 0
        
        Repeater {
            model: root.model
            
            Rectangle {
                width: root.segmentWidth - 4
                height: parent.height
                color: "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: index === root.currentIndex
                        ? (theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
                        : (theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                    font.weight: index === root.currentIndex ? Font.Medium : Font.Normal
                    elide: Text.ElideRight
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                    
                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (index !== root.currentIndex) {
                            root.currentIndex = index
                            root.activated(index)
                        }
                    }
                }
            }
        }
    }
    
    Text {
        anchors.centerIn: parent
        text: "Loading..."
        color: theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.90)
        font.pixelSize: 12
        font.family: "M PLUS 2"
        visible: root.model.length === 0
    }
}

