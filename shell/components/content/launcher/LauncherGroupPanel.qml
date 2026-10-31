import QtQuick
import "../../../lib" as Theme

Rectangle {
    id: panel

    property var theme
    property var typo
    property bool open: false
    property var group: null
    property var members: []
    property var openMembers: []
    property int gridColumns: 1
    property Component tileComponent: null
    property alias grid: groupGridView
    property alias nameInput: groupNameInput

    signal launch(var app)
    signal nameCommitted(string name)
    signal activity()

    opacity: panel.open ? 1.0 : 0.0
    scale: panel.open ? 1.0 : 0.94
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: Theme.Motion.fast; easing.type: Theme.Motion.easeOut } }
    Behavior on scale { NumberAnimation { duration: Theme.Motion.fast; easing.type: Theme.Motion.easeOut } }

    readonly property int columns: Math.max(2, Math.min(panel.gridColumns - 2, panel.members.length))
    readonly property int rows: Math.max(1, Math.ceil(panel.members.length / panel.columns))

    width: columns * 100 + 48
    height: 26 + 40 + 14 + rows * 110 + 20
    radius: 24
    color: panel.theme ? panel.theme.popupFace : Qt.rgba(13 / 255, 8 / 255, 26 / 255, 0.92)
    border.width: 1
    border.color: panel.theme ? panel.theme.surfaceBorder : Qt.rgba(0.70, 0.65, 0.90, 0.3)

    // Swallow clicks so they do not fall through to the dismiss area.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (mouse) => { mouse.accepted = true }
        onWheel: (wheel) => { wheel.accepted = true }
    }

    Item {
        id: groupNameRow
        anchors.top: parent.top
        anchors.topMargin: 26
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(groupNameInput.contentWidth, 40) + 20
        height: 40

        TextInput {
            id: groupNameInput
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -3
            text: panel.group ? panel.group.name : ""
            font.family: panel.typo ? panel.typo.fontFamily : "M PLUS 2"
            font.pixelSize: 20
            color: panel.theme ? panel.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            selectionColor: panel.theme ? Qt.rgba(panel.theme.accent.r, panel.theme.accent.g, panel.theme.accent.b, 0.35) : Qt.rgba(0.65, 0.55, 0.85, 0.35)
            selectedTextColor: color
            horizontalAlignment: TextInput.AlignHCenter
            activeFocusOnPress: true
            selectByMouse: true
            onTextEdited: panel.activity()
            onPreeditTextChanged: panel.activity()

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Escape) {
                    groupGridView.forceActiveFocus()
                    event.accepted = true
                }
            }
            // Whatever is in the field when it loses focus is the name; there is no cancel.
            onActiveFocusChanged: {
                if (!groupNameInput.activeFocus) panel.nameCommitted(groupNameInput.text)
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: 2
            radius: 1
            color: panel.theme ? panel.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 1.0)
            opacity: groupNameInput.activeFocus ? 0.75 : (groupNameHover.hovered ? 0.3 : 0.0)

            Behavior on opacity { NumberAnimation { duration: Theme.Motion.micro } }
        }

        HoverHandler { id: groupNameHover }
    }

    GridView {
        id: groupGridView
        anchors.top: groupNameRow.bottom
        anchors.topMargin: 14
        anchors.horizontalCenter: parent.horizontalCenter
        width: panel.columns * 100
        height: panel.rows * 110
        interactive: false
        cellWidth: 100
        cellHeight: 110
        model: panel.members
        delegate: panel.tileComponent
        currentIndex: -1
        highlight: null
        highlightFollowsCurrentItem: false
        property bool userInteracted: false

        // GridView selects 0 whenever its model changes; nothing is chosen until hover or a key.
        onCountChanged: {
            if (!userInteracted && currentIndex !== -1) currentIndex = -1
        }

        Keys.onPressed: (event) => {
            panel.activity()
            let cols = panel.columns
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (groupGridView.currentIndex >= 0 && panel.openMembers[groupGridView.currentIndex]) panel.launch(panel.openMembers[groupGridView.currentIndex])
                event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Backtab) {
                currentIndex = count === 0 ? -1 : (currentIndex < 0 ? count - 1 : (currentIndex - 1 + count) % count)
                event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab) {
                currentIndex = count === 0 ? -1 : (currentIndex + 1) % count
                event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                if (currentIndex < 0) currentIndex = 0
                else if (currentIndex + cols < count) currentIndex += cols
                event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                if (currentIndex >= cols) currentIndex -= cols
                else groupNameInput.forceActiveFocus()
                event.accepted = true
            }
        }
    }
}
