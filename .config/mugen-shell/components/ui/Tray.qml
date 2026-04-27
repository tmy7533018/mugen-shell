import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

RowLayout {
    id: root

    property var modeManager
    property var theme

    // Items whose id or title contains any of these (case-insensitive) are hidden
    // because mugen-shell already exposes them as dedicated bar widgets.
    property var blockedKeywords: ["nm-applet", "networkmanager", "blueman", "bluetooth", "fcitx"]

    property bool expanded: false

    function isBlocked(item) {
        if (!item) return false
        const id = (item.id || "").toLowerCase()
        const title = (item.title || "").toLowerCase()
        for (const kw of blockedKeywords) {
            const k = kw.toLowerCase()
            if (id.includes(k) || title.includes(k)) return true
        }
        return false
    }

    function scaled(v) { return modeManager ? modeManager.scale(v) : v }

    spacing: scaled(8)
    Layout.alignment: Qt.AlignVCenter

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayDelegate
            required property var modelData

            readonly property bool blocked: root.isBlocked(modelData)
            readonly property bool shouldShow: root.expanded && !blocked

            Layout.preferredWidth: shouldShow ? root.scaled(20) : 0
            Layout.preferredHeight: root.scaled(20)
            Layout.alignment: Qt.AlignVCenter
            opacity: shouldShow ? 1.0 : 0.0
            visible: opacity > 0.01

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Image {
                anchors.fill: parent
                source: trayDelegate.modelData.icon
                fillMode: Image.PreserveAspectFit
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                smooth: true
                opacity: trayMouse.containsMouse ? 1.0 : 0.75
                scale: trayMouse.containsMouse ? 1.15 : 1.0

                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                id: trayMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                enabled: trayDelegate.shouldShow

                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        trayDelegate.modelData.activate()
                    } else if (mouse.button === Qt.MiddleButton) {
                        trayDelegate.modelData.secondaryActivate()
                    } else if (mouse.button === Qt.RightButton) {
                        if (trayDelegate.modelData.hasMenu) {
                            trayMenuAnchor.menu = trayDelegate.modelData.menu
                            trayMenuAnchor.open()
                        }
                    }
                }

                onWheel: (event) => {
                    trayDelegate.modelData.scroll(event.angleDelta.y, false)
                }
            }
        }
    }

    Item {
        id: chevronButton
        Layout.preferredWidth: root.scaled(24)
        Layout.preferredHeight: root.scaled(24)
        Layout.alignment: Qt.AlignVCenter

        SvgIcon {
            id: chevronIcon
            anchors.centerIn: parent
            width: root.scaled(20)
            height: root.scaled(20)
            source: Quickshell.shellDir + (root.expanded
                ? "/assets/icons/chevron-double-right.svg"
                : "/assets/icons/chevron-double-left.svg")
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            opacity: chevronMouse.containsMouse ? 1.0 : 0.6

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: chevronMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    QsMenuAnchor {
        id: trayMenuAnchor
    }
}
