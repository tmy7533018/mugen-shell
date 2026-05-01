import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    
    property bool checked: false
    property var theme
    
    signal toggled()
    
    width: 52
    height: 30
    radius: height / 2
    color: checked 
        ? (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.5) : Qt.rgba(0.65, 0.55, 0.85, 0.5))
        : (theme ? Qt.rgba(theme.textFaint.r, theme.textFaint.g, theme.textFaint.b, 0.2) : Qt.rgba(0.62, 0.62, 0.72, 0.2))
    border.width: 1
    border.color: checked
        ? (theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4))
        : (theme ? Qt.rgba(theme.textFaint.r, theme.textFaint.g, theme.textFaint.b, 0.3) : Qt.rgba(0.62, 0.62, 0.72, 0.3))
    
    Behavior on color {
        ColorAnimation { duration: 250; easing.type: Easing.OutCubic }
    }
    
    Behavior on border.color {
        ColorAnimation { duration: 250; easing.type: Easing.OutCubic }
    }
    
    Rectangle {
        id: thumb
        width: 24
        height: 24
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: checked ? parent.width - width - 3 : 3
        color: checked
            ? (theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
            : (theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.9))
        
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 4
            height: parent.height + 4
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: checked && theme
                ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.3)
                : (checked ? Qt.rgba(0.65, 0.55, 0.85, 0.3) : "transparent")
            opacity: checked ? 1.0 : 0.0
            
            Behavior on opacity {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
        }
        
        Behavior on x {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
        
        Behavior on color {
            ColorAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked
            root.toggled()
        }
    }
}

