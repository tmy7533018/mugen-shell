import QtQuick
import QtQuick.Layouts

Item {
    id: selector

    required property var theme
    required property var modeManager
    required property string currentModel
    required property var availableModels
    property bool isOpen: false

    signal toggled()
    signal modelChosen(string name)

    Layout.preferredWidth: modelLabel.width + (modeManager ? modeManager.scale(20) : 20)
    Layout.preferredHeight: modeManager ? modeManager.scale(26) : 26
    z: 100

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: modelSelectorMouse.containsMouse
            ? (selector.theme ? selector.theme.chipActiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.25))
            : (selector.theme ? selector.theme.chipInactiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.12))
        border.color: selector.theme ? selector.theme.chipInactiveBorder : Qt.rgba(0.55, 0.55, 0.68, 0.15)
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Text {
            id: modelLabel
            anchors.centerIn: parent
            text: selector.currentModel + (selector.isOpen ? "  ▴" : "  ▾")
            color: selector.theme ? selector.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            font.pixelSize: selector.modeManager ? selector.modeManager.scale(11) : 11
            font.family: "M PLUS 2"
            opacity: modelSelectorMouse.containsMouse ? 1.0 : 0.7

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }

        MouseArea {
            id: modelSelectorMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: selector.toggled()
        }
    }

    Column {
        visible: selector.isOpen
        anchors.top: parent.bottom
        anchors.topMargin: selector.modeManager ? selector.modeManager.scale(4) : 4
        anchors.horizontalCenter: parent.horizontalCenter
        z: 10

        Rectangle {
            width: modelDropdownCol.width + (selector.modeManager ? selector.modeManager.scale(12) : 12)
            height: modelDropdownCol.height + (selector.modeManager ? selector.modeManager.scale(12) : 12)
            radius: selector.modeManager ? selector.modeManager.scale(10) : 10
            color: selector.theme
                ? Qt.rgba(selector.theme.surfaceGlass.r, selector.theme.surfaceGlass.g, selector.theme.surfaceGlass.b, 0.9)
                : Qt.rgba(0.08, 0.05, 0.15, 0.9)
            border.color: selector.theme ? selector.theme.surfaceBorder : Qt.rgba(0.55, 0.55, 0.68, 0.2)
            border.width: 1

            Column {
                id: modelDropdownCol
                anchors.centerIn: parent
                spacing: selector.modeManager ? selector.modeManager.scale(2) : 2

                Repeater {
                    model: selector.availableModels

                    Rectangle {
                        required property string modelData
                        required property int index
                        width: dropdownItemText.implicitWidth + (selector.modeManager ? selector.modeManager.scale(24) : 24)
                        height: dropdownItemText.implicitHeight + (selector.modeManager ? selector.modeManager.scale(10) : 10)
                        radius: selector.modeManager ? selector.modeManager.scale(6) : 6
                        color: dropdownItemMouse.containsMouse
                            ? (selector.theme ? selector.theme.chipActiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.3))
                            : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        Text {
                            id: dropdownItemText
                            anchors.centerIn: parent
                            text: modelData
                            color: modelData === selector.currentModel
                                ? (selector.theme ? selector.theme.accent : Qt.rgba(0.65, 0.85, 1.0, 1.0))
                                : (selector.theme ? selector.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90))
                            font.pixelSize: selector.modeManager ? selector.modeManager.scale(11) : 11
                            font.family: "M PLUS 2"
                            font.weight: modelData === selector.currentModel ? Font.Medium : Font.Normal
                        }

                        MouseArea {
                            id: dropdownItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: selector.modelChosen(modelData)
                        }
                    }
                }
            }
        }
    }
}
