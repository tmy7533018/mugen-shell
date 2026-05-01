import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io

Rectangle {
    id: notificationItem
    
    property var modelData
    property var theme
    property var removingNotifications
    property var notifications
    property int index

    signal removeRequested(var notificationId)
    signal actionRequested(var notif)
    
    width: parent ? parent.width : 0
    // Ignore expansion height changes while removal animation is running
    height: shouldCollapseHeight ? 0 : (isExpanded && !notificationItem.isRemoving ? contentColumn.implicitHeight + 24 : 65)
    color: theme ? theme.surfaceInsetCard : Qt.rgba(0, 0, 0, 0.65)
    radius: isExpanded ? 20 : 32.5
    border.width: 0
    clip: true
    
    property bool isExpanded: notifMouseArea.containsMouse && !notificationItem.isRemoving
    property bool showFullText: isExpanded

    // Delay text collapse to prevent visual flicker during hover transitions
    Timer {
        id: collapseTextTimer
        interval: 250
        onTriggered: {
            if (!notificationItem.isExpanded) {
                notificationItem.showFullText = false
            }
        }
    }
    
    onIsExpandedChanged: {
        if (isExpanded) {
            showFullText = true
            collapseTextTimer.stop()
        } else {
            collapseTextTimer.restart()
        }
    }
    
    property bool isRemoving: removingNotifications[String(modelData.id)] !== undefined
    property int removalIndex: {
        if (!isRemoving) return 0
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i].id === modelData.id) return i
        }
        return 0
    }
    
    property bool shouldCollapseHeight: false

    // Brief delay before collapsing height so fade-out starts visibly first
    Timer {
        id: collapseHeightTimer
        interval: 150
        running: notificationItem.isRemoving
        onTriggered: {
            notificationItem.shouldCollapseHeight = true
        }
    }


    Behavior on height {
        NumberAnimation {
            duration: shouldCollapseHeight ? 350 : 300
            easing.type: shouldCollapseHeight ? Easing.InOutCubic : Easing.OutCubic
        }
    }
    
    Behavior on radius {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }
    
    SequentialAnimation on scale {
        running: notificationItem.isRemoving
        alwaysRunToEnd: true
        NumberAnimation {
            from: 1.0
            to: 0.8
            duration: 300
            easing.type: Easing.InCubic
        }
    }
    
    SequentialAnimation on opacity {
        running: notificationItem.isRemoving
        alwaysRunToEnd: true
        NumberAnimation {
            from: 1.0
            to: 0.0
            duration: 300
            easing.type: Easing.InCubic
        }
    }
    
    layer.enabled: true
    layer.effect: Glow {
        samples: 12
        radius: 6
        spread: 0.3
        color: theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.15) : Qt.rgba(0.65, 0.55, 0.85, 0.15)
        transparentBorder: true
    }
    
    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 4
        
        Row {
            Layout.fillWidth: true
            spacing: 8
            
            Text {
                text: modelData.title
                color: (theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.90))
                font.pixelSize: 14
                font.weight: Font.Medium
                font.family: "M PLUS 2"
                elide: notificationItem.showFullText ? Text.ElideNone : Text.ElideRight
                maximumLineCount: notificationItem.showFullText ? 999 : 1
                Layout.fillWidth: true
                wrapMode: notificationItem.showFullText ? Text.WordWrap : Text.NoWrap
            }
            
            Text {
                text: modelData.time
                color: Qt.rgba(0.72, 0.72, 0.82, 0.60)
                font.pixelSize: 11
                font.weight: Font.Light
                font.family: "M PLUS 2"
            }
        }
        
        Text {
            text: modelData.message
            color: Qt.rgba(0.80, 0.80, 0.85, 0.75)
            font.pixelSize: 12
            font.weight: Font.Light
            font.family: "M PLUS 2"
            wrapMode: notificationItem.showFullText ? Text.WordWrap : Text.NoWrap
            elide: notificationItem.showFullText ? Text.ElideNone : Text.ElideRight
            maximumLineCount: notificationItem.showFullText ? 999 : 1
            Layout.fillWidth: true
        }
    }
    
    states: [
        State {
            name: "hovered"
            when: notifMouseArea.containsMouse && !notificationItem.isRemoving
            PropertyChanges { target: notificationItem; color: theme ? theme.surfaceInsetCardHover : Qt.rgba(0, 0, 0, 0.75) }
        }
    ]
    
    transitions: [
        Transition {
            ColorAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    ]
    
    MouseArea {
        id: notifMouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: !notificationItem.isRemoving
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        z: 2
        
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                actionRequested(modelData)
            } else if (mouse.button === Qt.RightButton) {
                removeRequested(modelData.id)
            }
        }
    }
}

