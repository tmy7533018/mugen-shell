import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import "../../lib" as Theme
import "../ui" as UI

Rectangle {
    id: notificationItem
    
    property var modelData
    property var theme
    property var icons
    property var removingNotifications
    property var notifications
    property int index

    signal removeRequested(var notificationId)
    signal swipeRemoved(var notificationId)
    signal actionRequested(var notif)
    
    width: parent ? parent.width : 0
    height: shouldCollapseHeight ? 0 : (isExpanded && !notificationItem.isRemoving ? contentColumn.implicitHeight + 24 : 65)
    color: theme ? theme.surfaceInsetCard : Qt.rgba(0, 0, 0, 0.65)
    radius: isExpanded ? 20 : 32.5
    border.width: 0
    clip: true
    
    property bool isExpanded: notificationItem.ListView.isCurrentItem && !notificationItem.isRemoving
    property bool showFullText: isExpanded

    // Delayed so quick hover in/out doesn't flicker the text
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
    
    property bool isRemoving: modelData
        && removingNotifications[String(modelData.id)] !== undefined
    property int removalIndex: {
        if (!isRemoving) return 0
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i].id === modelData.id) return i
        }
        return 0
    }
    
    property bool shouldCollapseHeight: false

    readonly property real swipeThreshold: width * 0.25
    readonly property real swipeProgress: width > 0 ? Math.min(1, Math.abs(x) / width) : 0

    // Written, not bound: the view's add transition animates opacity and would sever a binding for good.
    onXChanged: opacity = 1 - swipeProgress * 0.85

    // Delayed so the fade-out is visible before the height collapse eats it
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
            duration: Theme.Motion.fast
            easing.type: Easing.OutCubic
        }
    }
    
    SequentialAnimation on scale {
        running: notificationItem.isRemoving
        alwaysRunToEnd: true
        NumberAnimation {
            from: 1.0
            to: 0.8
            duration: Theme.Motion.standard
            easing.type: Easing.InCubic
        }
    }
    
    SequentialAnimation on opacity {
        running: notificationItem.isRemoving
        alwaysRunToEnd: true
        NumberAnimation {
            to: 0.0
            duration: Theme.Motion.standard
            easing.type: Easing.InCubic
        }
    }

    NumberAnimation {
        id: swipeSpringBack
        target: notificationItem
        property: "x"
        to: 0
        duration: Theme.Motion.standard
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: swipeFlyOut
        target: notificationItem
        property: "x"
        duration: Theme.Motion.fast
        easing.type: Easing.OutCubic
        onStopped: {
            // The view snaps a delegate's x back to 0 on relayout, so hide before anything triggers one.
            notificationItem.visible = false
            if (notificationItem.ListView.view)
                notificationItem.ListView.view.currentIndex = -1
            if (notificationItem.modelData)
                notificationItem.swipeRemoved(notificationItem.modelData.id)
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

    Theme.IconResolver { id: iconResolver }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 4
        z: 3
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter

                property var iconPaths: {
                    if (!modelData) return []
                    let candidates = []
                    if (modelData.desktopEntry && modelData.desktopEntry.length > 0) candidates.push(modelData.desktopEntry)
                    if (modelData.appName && modelData.appName.length > 0) candidates.push(modelData.appName.toLowerCase())
                    let paths = []
                    for (let i = 0; i < candidates.length; i++) {
                        let resolved = iconResolver.resolveIconPath(candidates[i])
                        for (let j = 0; j < resolved.length; j++) paths.push(resolved[j])
                    }
                    return paths
                }
                property int currentPathIndex: 0
                property string directImage: modelData && modelData.image ? modelData.image : ""

                Image {
                    id: itemAppIcon
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                    cache: false
                    visible: status === Image.Ready
                    source: {
                        if (parent.directImage.length > 0) return parent.directImage
                        if (parent.iconPaths.length > 0 && parent.currentPathIndex < parent.iconPaths.length) {
                            return "file://" + parent.iconPaths[parent.currentPathIndex]
                        }
                        return ""
                    }
                    onStatusChanged: {
                        if (status === Image.Error) {
                            let p = parent
                            if (p.currentPathIndex + 1 < p.iconPaths.length) {
                                p.currentPathIndex++
                            }
                        }
                    }
                }

                UI.SvgIcon {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    visible: !itemAppIcon.visible
                    source: notificationItem.icons ? notificationItem.icons.notificationSvg : ""
                    color: theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                    opacity: 0.85
                }
            }

            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: notificationItem.modelData ? notificationItem.modelData.title : ""
                color: (theme ? theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.90))
                font.pixelSize: 14
                font.weight: Font.Medium
                font.family: "M PLUS 2"
                elide: notificationItem.showFullText ? Text.ElideNone : Text.ElideRight
                maximumLineCount: notificationItem.showFullText ? 999 : 1
                wrapMode: notificationItem.showFullText ? Text.WordWrap : Text.NoWrap
            }

            Text {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                text: notificationItem.modelData ? notificationItem.modelData.time : ""
                color: Qt.rgba(0.72, 0.72, 0.82, 0.60)
                font.pixelSize: 11
                font.weight: Font.Light
                font.family: "M PLUS 2"
            }
        }
        
        Text {
            textFormat: Text.PlainText
            text: notificationItem.modelData ? notificationItem.modelData.message : ""
            color: Qt.rgba(0.80, 0.80, 0.85, 0.75)
            font.pixelSize: 12
            font.weight: Font.Light
            font.family: "M PLUS 2"
            wrapMode: notificationItem.showFullText ? Text.WordWrap : Text.NoWrap
            elide: notificationItem.showFullText ? Text.ElideNone : Text.ElideRight
            maximumLineCount: notificationItem.showFullText ? 999 : 1
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 8
            visible: notificationItem.isExpanded

            Item { Layout.fillWidth: true }

            Rectangle {
                id: openBtn
                Layout.preferredWidth: openText.implicitWidth + 20
                Layout.preferredHeight: 24
                visible: modelData && modelData.desktopEntry && String(modelData.desktopEntry).length > 0
                color: openBtnArea.containsMouse
                    ? (theme ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, 0.18) : Qt.rgba(0.65, 0.55, 0.85, 0.18))
                    : "transparent"
                border.width: 1
                border.color: theme
                    ? Qt.rgba(theme.glowPrimary.r, theme.glowPrimary.g, theme.glowPrimary.b, openBtnArea.containsMouse ? 0.65 : 0.3)
                    : Qt.rgba(0.65, 0.55, 0.85, openBtnArea.containsMouse ? 0.65 : 0.3)
                radius: 12
                z: 3

                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                Behavior on border.color { ColorAnimation { duration: Theme.Motion.micro } }

                Text {
                    id: openText
                    anchors.centerIn: parent
                    text: "Open"
                    color: theme ? theme.glowPrimary : Qt.rgba(0.65, 0.55, 0.85, 1)
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.family: "M PLUS 2"
                    font.letterSpacing: 0.3
                }

                MouseArea {
                    id: openBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: notificationItem.actionRequested(modelData)
                }
            }

            Rectangle {
                id: dismissBtn
                Layout.preferredWidth: dismissText.implicitWidth + 20
                Layout.preferredHeight: 24
                color: dismissBtnArea.containsMouse
                    ? Qt.rgba(1, 0.5, 0.55, 0.18)
                    : "transparent"
                border.width: 1
                border.color: dismissBtnArea.containsMouse
                    ? Qt.rgba(1, 0.5, 0.55, 0.6)
                    : Qt.rgba(0.55, 0.55, 0.62, 0.3)
                radius: 12
                z: 3

                Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                Behavior on border.color { ColorAnimation { duration: Theme.Motion.micro } }

                Text {
                    id: dismissText
                    anchors.centerIn: parent
                    text: "Dismiss"
                    color: dismissBtnArea.containsMouse
                        ? Qt.rgba(1, 0.55, 0.6, 1)
                        : Qt.rgba(0.75, 0.75, 0.8, 0.85)
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.family: "M PLUS 2"
                    font.letterSpacing: 0.3

                    Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }
                }

                MouseArea {
                    id: dismissBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: notificationItem.removeRequested(modelData.id)
                }
            }
        }
    }
    
    states: [
        State {
            name: "hovered"
            when: notificationItem.ListView.isCurrentItem && !notificationItem.isRemoving
            PropertyChanges { target: notificationItem; color: theme ? theme.surfaceInsetCardHover : Qt.rgba(0, 0, 0, 0.75) }
        }
    ]
    
    transitions: [
        Transition {
            ColorAnimation {
                duration: Theme.Motion.fast
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

        drag.target: notificationItem
        drag.axis: Drag.XAxis
        drag.minimumX: -notificationItem.width
        drag.maximumX: notificationItem.width

        property bool swiped: false

        onEntered: {
            // Rows sliding under a stationary cursor get synthetic hover; expanding them mid-removal fights the collapse.
            if (Object.keys(notificationItem.removingNotifications).length > 0) return
            if (notificationItem.ListView.view) {
                notificationItem.ListView.view.currentIndex = notificationItem.index
            }
        }

        onPressed: {
            swiped = false
            swipeSpringBack.stop()
        }

        onPositionChanged: if (drag.active) swiped = true

        onReleased: {
            if (!swiped) return
            if (Math.abs(notificationItem.x) < notificationItem.swipeThreshold) {
                swipeSpringBack.start()
            } else {
                swipeFlyOut.to = notificationItem.x < 0 ? -notificationItem.width
                                                        : notificationItem.width
                swipeFlyOut.start()
            }
        }

        onClicked: function(mouse) {
            if (swiped) return
            if (mouse.button === Qt.LeftButton) {
                actionRequested(modelData)
            } else if (mouse.button === Qt.RightButton) {
                removeRequested(modelData.id)
            }
        }
    }
}

