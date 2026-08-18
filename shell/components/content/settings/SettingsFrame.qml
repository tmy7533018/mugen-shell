import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../ui" as UI
import "../../../lib" as Theme

// Sidebar, search and section list, shared by every settings screen. The screen
// itself owns the sections and hands them over through `resolveSection`.
Item {
    id: frame

    property var theme
    required property var categories
    property string title: "Settings"
    property string iconSource: Quickshell.shellDir + "/assets/icons/settings.svg"

    // function(type) -> Component, since the sections live in the owning screen.
    property var resolveSection: null

    // A category carrying `action` opens something else instead of listing sections.
    signal categoryAction(string action)

    property string initialCategory: ""
    property string selectedCategory: initialCategory !== ""
        ? initialCategory
        : (categories.length > 0 ? categories[0].id : "")
    property string query: ""

    // "moduleBackground" -> "Module Background", so search needs no second copy of the titles.
    function labelFor(type) {
        const spaced = type.replace(/([A-Z])/g, " $1")
        return spaced.charAt(0).toUpperCase() + spaced.slice(1)
    }

    function matches(type, category, needle) {
        return type.toLowerCase().indexOf(needle) >= 0
            || frame.labelFor(type).toLowerCase().indexOf(needle) >= 0
            || String(category.label).toLowerCase().indexOf(needle) >= 0
    }

    readonly property var selectedEntry: {
        for (let i = 0; i < frame.categories.length; i++)
            if (frame.categories[i].id === frame.selectedCategory) return frame.categories[i]
        return null
    }

    function selectCategoryAt(offset) {
        const ids = frame.categories.map(c => c.id)
        const at = ids.indexOf(frame.selectedCategory)
        const next = Math.max(0, Math.min(ids.length - 1, (at < 0 ? 0 : at) + offset))
        frame.selectedCategory = ids[next]
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        color: frame.theme ? frame.theme.surfaceInsetCard : Qt.rgba(0.05, 0.05, 0.08, 0.92)
        radius: 0
        border.width: 0

        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                Qt.quit()
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                frame.selectCategoryAt(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                frame.selectCategoryAt(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (frame.selectedEntry && frame.selectedEntry.action)
                    frame.categoryAction(frame.selectedEntry.action)
                event.accepted = true
            } else if (event.key === Qt.Key_Slash
                       || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))) {
                searchInput.forceActiveFocus()
                event.accepted = true
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: 12

                UI.SvgIcon {
                    Layout.alignment: Qt.AlignVCenter
                    width: 22
                    height: 22
                    source: frame.iconSource
                    color: frame.theme ? frame.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9)
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: frame.title
                    color: frame.theme ? frame.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.9)
                    font.pixelSize: 20
                    font.weight: Font.Light
                    font.family: "M PLUS 2"
                    font.letterSpacing: 1.5
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 240
                    Layout.preferredHeight: 32
                    color: "transparent"
                    radius: height / 2
                    border.width: 1
                    border.color: searchInput.activeFocus
                        ? (frame.theme ? frame.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.6))
                        : (frame.theme ? frame.theme.surfaceBorder : Qt.rgba(0.70, 0.65, 0.90, 0.3))

                    Behavior on border.color { ColorAnimation { duration: Theme.Motion.micro } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        UI.SvgIcon {
                            Layout.alignment: Qt.AlignVCenter
                            width: 14
                            height: 14
                            source: Quickshell.shellDir + "/assets/icons/search.svg"
                            color: frame.theme ? frame.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                            opacity: 0.7
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            color: frame.theme ? frame.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
                            font.pixelSize: 12
                            font.family: "M PLUS 2"
                            selectByMouse: true
                            selectionColor: frame.theme ? frame.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                            onTextChanged: frame.query = text

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Escape) {
                                    if (searchInput.text.length > 0) searchInput.text = ""
                                    surface.forceActiveFocus()
                                    event.accepted = true
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search settings"
                                color: frame.theme ? frame.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                                font: searchInput.font
                                visible: searchInput.text.length === 0
                                opacity: 0.5
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onClicked: searchInput.forceActiveFocus()
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Column {
                    id: sidebar
                    width: 150
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    spacing: 4
                    opacity: frame.query.length > 0 ? 0.4 : 1.0

                    Behavior on opacity { NumberAnimation { duration: Theme.Motion.micro } }

                    Repeater {
                        model: frame.categories
                        delegate: Rectangle {
                            id: categoryRow
                            required property var modelData
                            width: sidebar.width
                            height: 36
                            radius: 10
                            property bool selected: frame.selectedCategory === categoryRow.modelData.id
                            property bool danger: categoryRow.modelData.danger === true
                            color: categoryRow.selected
                                ? (categoryRow.danger
                                    ? Qt.rgba(0.95, 0.55, 0.65, 0.20)
                                    : (frame.theme ? Qt.rgba(frame.theme.accent.r, frame.theme.accent.g, frame.theme.accent.b, 0.20) : Qt.rgba(0.65, 0.55, 0.85, 0.20)))
                                : (categoryArea.containsMouse
                                    ? Qt.rgba(1, 1, 1, 0.04)
                                    : "transparent")

                            Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 14
                                text: categoryRow.modelData.label
                                color: categoryRow.danger
                                    ? Qt.rgba(0.95, 0.55, 0.65, categoryRow.selected ? 1.0 : 0.78)
                                    : (categoryRow.selected
                                        ? (frame.theme ? frame.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95))
                                        : (frame.theme ? frame.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.85)))
                                font.pixelSize: 12
                                font.weight: categoryRow.selected ? Font.Medium : Font.Normal
                                font.family: "M PLUS 2"
                                font.letterSpacing: 0.5
                            }

                            MouseArea {
                                id: categoryArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (categoryRow.modelData.action) {
                                        frame.categoryAction(categoryRow.modelData.action)
                                        return
                                    }
                                    searchInput.text = ""
                                    frame.selectedCategory = categoryRow.modelData.id
                                    surface.forceActiveFocus()
                                }
                            }
                        }
                    }
                }

                ListView {
                    id: settingsList
                    anchors.left: sidebar.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 16
                    spacing: 16
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 4

                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: frame.theme ? Qt.rgba(frame.theme.glowPrimary.r, frame.theme.glowPrimary.g, frame.theme.glowPrimary.b, 0.4) : Qt.rgba(0.65, 0.55, 0.85, 0.4)
                        }
                    }

                    model: ListModel { id: settingsModel }

                    delegate: Loader {
                        required property var model
                        width: settingsList.width
                        sourceComponent: frame.resolveSection
                            ? frame.resolveSection(model.type)
                            : null
                    }

                    function rebuild() {
                        settingsModel.clear()
                        const needle = frame.query.trim().toLowerCase()
                        for (let i = 0; i < frame.categories.length; i++) {
                            const category = frame.categories[i]
                            if (!category.types)
                                continue
                            if (needle.length === 0 && category.id !== frame.selectedCategory)
                                continue
                            for (let j = 0; j < category.types.length; j++) {
                                const type = category.types[j]
                                if (needle.length === 0 || frame.matches(type, category, needle))
                                    settingsModel.append({ "type": type })
                            }
                        }
                    }

                    Component.onCompleted: rebuild()
                }

                Text {
                    anchors.left: sidebar.right
                    anchors.leftMargin: 16
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    visible: settingsList.count === 0
                    text: frame.query.length > 0
                        ? "Nothing matches \"" + frame.query + "\""
                        : (frame.selectedEntry && frame.selectedEntry.action
                            ? "Press Enter to open" : "")
                    color: frame.theme ? frame.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                    font.pixelSize: 12
                    font.family: "M PLUS 2"
                }

                Connections {
                    target: frame
                    function onSelectedCategoryChanged() { settingsList.rebuild() }
                    function onQueryChanged() { settingsList.rebuild() }
                }
            }
        }
    }
}
