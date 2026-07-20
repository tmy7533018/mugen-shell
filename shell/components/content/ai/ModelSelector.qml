import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../lib" as Theme

Item {
    id: selector

    required property var theme
    required property var modeManager
    required property string currentModel
    required property var availableModels
    property bool isOpen: false
    property bool editable: true

    signal toggled()
    signal modelChosen(string name)

    Layout.preferredWidth: modelLabel.width + (modeManager ? modeManager.scale(20) : 20)
    Layout.preferredHeight: modeManager ? modeManager.scale(26) : 26
    z: 100

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: selector.editable && modelSelectorMouse.containsMouse
            ? (selector.theme ? selector.theme.chipActiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.25))
            : (selector.theme ? selector.theme.chipInactiveBg : Qt.rgba(0.45, 0.45, 0.60, 0.12))
        border.color: selector.theme ? selector.theme.chipInactiveBorder : Qt.rgba(0.55, 0.55, 0.68, 0.15)
        border.width: 1
        opacity: selector.editable ? 1.0 : 0.6

        Behavior on color {
            ColorAnimation { duration: Theme.Motion.fast; easing.type: Easing.OutCubic }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast } }

        Text {
            id: modelLabel
            anchors.centerIn: parent
            text: selector.editable
                ? selector.currentModel + (selector.isOpen ? "  ▴" : "  ▾")
                : selector.currentModel
            color: selector.theme ? selector.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            font.pixelSize: selector.modeManager ? selector.modeManager.scale(11) : 11
            font.family: "M PLUS 2"
            font.italic: !selector.editable
            opacity: selector.editable
                ? (modelSelectorMouse.containsMouse ? 1.0 : 0.7)
                : 0.85

            Behavior on opacity {
                NumberAnimation { duration: Theme.Motion.fast }
            }
        }

        MouseArea {
            id: modelSelectorMouse
            anchors.fill: parent
            hoverEnabled: selector.editable
            cursorShape: selector.editable ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: selector.editable
            onClicked: selector.toggled()
        }
    }

    // Popup, not an anchored Column: hit testing refuses to route clicks
    // below the chip's box, so the list needs the overlay layer.
    Popup {
        id: dropdown
        x: selector.width - width
        y: selector.height + (selector.modeManager ? selector.modeManager.scale(4) : 4)
        visible: selector.isOpen
        padding: selector.modeManager ? selector.modeManager.scale(6) : 6
        closePolicy: Popup.NoAutoClose

        background: Rectangle {
            radius: selector.modeManager ? selector.modeManager.scale(10) : 10
            color: selector.theme
                ? Qt.rgba(selector.theme.surfaceGlass.r, selector.theme.surfaceGlass.g, selector.theme.surfaceGlass.b, 0.9)
                : Qt.rgba(0.08, 0.05, 0.15, 0.9)
            border.color: selector.theme ? selector.theme.surfaceBorder : Qt.rgba(0.55, 0.55, 0.68, 0.2)
            border.width: 1
        }

        contentItem: Column {
            id: modelDropdownCol
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
                        ColorAnimation { duration: Theme.Motion.micro }
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
