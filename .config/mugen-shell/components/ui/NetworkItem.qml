import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../ui" as UI

Rectangle {
    id: root

    required property var modelData
    required property int index
    required property var theme
    required property var icons
    required property var wifiManager
    required property bool isExpanded
    required property bool isConnecting
    required property int connectingNetworkIndex

    signal toggleExpanded()
    signal resetAutoCloseTimer()
    signal connectToNetwork(string ssid, string password)

    width: parent ? parent.width : (ListView.view ? ListView.view.width : 420)

    // Explicit properties (not bindings) so each item animates independently
    property int targetHeight: 50
    implicitHeight: targetHeight
    height: targetHeight

    color: networkMouseArea.containsMouse ? Qt.rgba(0, 0, 0, 0.75) : Qt.rgba(0, 0, 0, 0.65)
    radius: root.isExpanded ? 20 : (height / 2)
    border.width: 0

    layer.enabled: true
    layer.effect: Glow {
        samples: 12
        radius: 6
        spread: 0.3
        color: root.theme ? Qt.rgba(root.theme.glowPrimary.r, root.theme.glowPrimary.g, root.theme.glowPrimary.b, 0.15) : Qt.rgba(0.65, 0.55, 0.85, 0.15)
        transparentBorder: true
    }

    Behavior on targetHeight {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    onIsExpandedChanged: {
        if (root.isExpanded) {
            targetHeight = 140
        } else {
            targetHeight = 50
        }
    }

    Component.onCompleted: {
        if (root.isExpanded) {
            targetHeight = 140
        } else {
            targetHeight = 50
        }
    }

    Behavior on radius {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    Behavior on color {
        ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

                Item {
                    width: 20
                    height: 20

                    UI.SvgIcon {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: root.icons && root.modelData ? (root.modelData.secured ? root.icons.iconData.lock.value : root.icons.wifiSvg) : (root.icons ? root.icons.wifiSvg : "")
                        color: root.theme ? root.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                        opacity: 0.8
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.modelData && root.modelData.ssid ? root.modelData.ssid : ""
                    color: Qt.rgba(0.92, 0.92, 0.96, 0.90)
                    font.pixelSize: 14
                    font.family: "M PLUS 2"
                    elide: Text.ElideRight
                }

                Text {
                    text: root.modelData && root.modelData.signal !== undefined ? (root.modelData.signal + "%") : ""
                    color: Qt.rgba(0.72, 0.72, 0.82, 0.70)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                }

            Item {
                width: 20
                height: 20

                UI.SvgIcon {
                    id: chevronIcon
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: root.icons ? root.icons.chevronDownSvg : ""
                    color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                    opacity: chevronMouseArea.containsMouse ? 1.0 : 0.6

                    rotation: root.isExpanded ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    id: chevronMouseArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.toggleExpanded()
                        root.resetAutoCloseTimer()
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            visible: root.isExpanded
            opacity: root.isExpanded ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: "transparent"
                    border.color: root.theme ? root.theme.surfaceBorder : Qt.rgba(0.70, 0.65, 0.90, 0.3)
                    border.width: 1
                    radius: 8

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        TextInput {
                            id: passwordInput
                            Layout.fillWidth: true

                            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                            font.pixelSize: 14
                            font.family: "M PLUS 2"
                            echoMode: showPasswordButton.checked ? TextInput.Normal : TextInput.Password

                            selectByMouse: true
                            selectionColor: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.4)

                            Text {
                                anchors.fill: parent
                                text: "Enter password..."
                                color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                                font: passwordInput.font
                                visible: passwordInput.text.length === 0
                                opacity: 0.5
                            }

                            onTextChanged: {
                                root.resetAutoCloseTimer()
                            }

                            Keys.onReturnPressed: {
                                connectButton.clicked()
                            }
                        }

                        Item {
                            width: 20
                            height: 20

                            property bool checked: false
                            id: showPasswordButton

                            UI.SvgIcon {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                source: root.icons ? (showPasswordButton.checked ? root.icons.iconData.eyeOpen.value : root.icons.iconData.eyeClosed.value) : ""
                                color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                                opacity: showPasswordMouseArea.containsMouse ? 1.0 : 0.6

                                Behavior on opacity {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                            }

                            MouseArea {
                                id: showPasswordMouseArea
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    showPasswordButton.checked = !showPasswordButton.checked
                                    root.resetAutoCloseTimer()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: connectButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: height / 2
                    color: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, connectMouseArea.containsMouse ? 0.4 : 0.3)

                    signal clicked()

                    Behavior on color {
                        ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: (root.wifiManager.isConnecting && root.connectingNetworkIndex === root.index) ? "Connecting..." : "Connect"
                        color: Qt.rgba(0.95, 0.93, 0.98, 0.95)
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        font.family: "M PLUS 2"
                    }

                        MouseArea {
                            id: connectMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.wifiManager.isConnecting && root.modelData
                            onClicked: {
                                if (root.modelData && passwordInput.text.length > 0) {
                                    root.connectToNetwork(root.modelData.ssid, passwordInput.text)
                                    passwordInput.text = ""
                                }
                            }
                        }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: -4
                    text: root.wifiManager.connectionError
                    color: Qt.rgba(0.90, 0.45, 0.55, 1.0)
                    font.pixelSize: 11
                    font.family: "M PLUS 2"
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.WordWrap
                    visible: root.wifiManager.connectionError !== "" && root.connectingNetworkIndex === root.index
                }
            }
        }
    }

    MouseArea {
        id: networkMouseArea
        anchors.fill: parent
        anchors.bottomMargin: root.isExpanded ? 88 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: (mouse) => {
            let chevronX = parent.width - 32
            if (mouse.x >= chevronX) {
                mouse.accepted = false
            }
        }

        onClicked: {
            if (!root.modelData) {
                return
            }

            if (wifiManager.isConnected && root.modelData.ssid === wifiManager.currentSsid) {
                return
            }

            if (!root.modelData.secured) {
                root.connectToNetwork(root.modelData.ssid, "")
            } else {
                root.toggleExpanded()
            }
            root.resetAutoCloseTimer()
        }
    }
}
