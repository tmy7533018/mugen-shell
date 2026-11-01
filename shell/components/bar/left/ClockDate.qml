import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../lib" as Theme
import "../../ui" as UI

ColumnLayout {
    id: root

    property var theme
    property var typo
    property var modeManager
    property var settingsManager

    function scaled(val) {
        if (root.modeManager) return root.modeManager.barScale(val)
        return val
    }

    Layout.alignment: Qt.AlignVCenter
    spacing: root.scaled(-2)

    property color glowColor: root.theme
        ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.6)
        : Qt.rgba(0.65, 0.55, 0.85, 0.6)

    Item {
        id: clockContainer
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: clockComponent.implicitWidth
        Layout.preferredHeight: clockComponent.implicitHeight

        UI.Clock {
            id: clockComponent
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            modeManager: root.modeManager
            theme: root.theme
            typo: root.typo
            showSeconds: root.settingsManager ? root.settingsManager.clockShowSeconds : false
            use24Hour: root.settingsManager ? root.settingsManager.clockShow24Hour : true
            reduceMotion: root.settingsManager ? root.settingsManager.reduceMotion : false
            glowColor: root.glowColor
            opacity: clockMouseArea.containsMouse ? 1.0 : 0.6
            scale: clockMouseArea.containsMouse ? 1.15 : 1.0

            Behavior on opacity {
                NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: Theme.Motion.slow; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: clockMouseArea
            anchors.fill: parent
            anchors.margins: root.scaled(-4)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.modeManager) root.modeManager.switchMode("timer")
            }
        }
    }

    Item {
        id: dateContainer
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: dateComponent.implicitWidth
        Layout.preferredHeight: dateComponent.implicitHeight

        UI.DateLabel {
            id: dateComponent
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            modeManager: root.modeManager
            theme: root.theme
            typo: root.typo
            format: root.settingsManager ? root.settingsManager.dateFormat : "ddd M/d"
            opacity: dateMouseArea.containsMouse ? 1.0 : 0.6
            scale: dateMouseArea.containsMouse ? 1.15 : 1.0

            Behavior on opacity {
                NumberAnimation { duration: Theme.Motion.gentle; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: Theme.Motion.slow; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: dateMouseArea
            anchors.fill: parent
            anchors.margins: root.scaled(-4)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.modeManager) root.modeManager.closeAllModes()
                Theme.Hypr.exec(Quickshell.shellDir + "/scripts/toggle-calendar.sh")
            }
        }
    }
}
