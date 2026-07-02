import QtQuick
import QtQuick.Layouts
import "../../../lib" as Theme

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var presets
    required property string currentPreset
    required property bool isLoadingPresets

    signal applyPreset(string name)

    width: parent ? parent.width : 420
    height: section.isExpanded ? 64 + Math.min(section.presets.length, 6) * 36 + 12 : 64
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)
    clip: true

    property bool isExpanded: false

    property int kbHighlightIndex: -1

    function syncKbToCurrent() {
        if (!section.presets) return
        for (let i = 0; i < section.presets.length; i++) {
            if (section.presets[i] === section.currentPreset) {
                section.kbHighlightIndex = i
                return
            }
        }
        section.kbHighlightIndex = 0
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (!section.isExpanded) {
                section.isExpanded = true
                section.syncKbToCurrent()
            } else {
                if (section.kbHighlightIndex >= 0 && section.presets && section.kbHighlightIndex < section.presets.length) {
                    section.applyPreset(section.presets[section.kbHighlightIndex])
                }
                section.isExpanded = false
            }
            section.bump()
            return true
        }
        if (section.isExpanded && event.key === Qt.Key_Escape) {
            section.isExpanded = false
            section.bump()
            return true
        }
        if (section.isExpanded && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
            if (!section.presets || section.presets.length === 0) return true
            let dir = event.key === Qt.Key_Down ? 1 : -1
            let next = section.kbHighlightIndex + dir
            if (next < 0) next = section.presets.length - 1
            if (next >= section.presets.length) next = 0
            section.kbHighlightIndex = next
            section.bump()
            return true
        }
        return false
    }

    function bump() {
        if (modeManager && modeManager.isMode("settings")) modeManager.bump()
    }

    Behavior on height {
        NumberAnimation { duration: Theme.Motion.standard; easing.type: Easing.OutCubic }
    }

    MouseArea {
        id: blurHeader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 64
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        TapHandler {
            onTapped: {
                section.isExpanded = !section.isExpanded
                section.bump()
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Blur Preset"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Normal
                font.letterSpacing: 0.5
            }

            Text {
                text: section.isLoadingPresets ? "Loading…"
                    : (section.currentPreset || "Select preset")
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: Font.Medium
            }

            Text {
                text: section.isExpanded ? "▴" : "▾"
                color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
            }
        }
    }

    ListView {
        id: presetList
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: blurHeader.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 12
        clip: true
        model: section.presets
        visible: section.isExpanded
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            width: presetList.width
            height: 36
            radius: 8
            property bool isCurrent: modelData === section.currentPreset

            property bool isKbHighlighted: section.kbHighlightIndex === index

            color: (presetMouseArea.containsMouse || isKbHighlighted)
                ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.25) : Qt.rgba(0.65, 0.55, 0.85, 0.25))
                : (isCurrent
                    ? (section.theme ? Qt.rgba(section.theme.accent.r, section.theme.accent.g, section.theme.accent.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4))
                    : "transparent")

            Behavior on color {
                ColorAnimation { duration: Theme.Motion.micro }
            }

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                text: modelData
                color: section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                font.pixelSize: 12
                font.family: "M PLUS 2"
                font.weight: isCurrent ? Font.Medium : Font.Normal
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 12
                text: "✓"
                visible: isCurrent
                color: section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                font.pixelSize: 12
                font.family: "M PLUS 2"
            }

            MouseArea {
                id: presetMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                onClicked: {
                    section.applyPreset(modelData)
                    section.isExpanded = false
                    section.bump()
                }
            }
        }
    }
}
