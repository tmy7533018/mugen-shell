import QtQuick
import QtQuick.Layouts
import "../ui" as UI

Rectangle {
    id: root
    
    required property var theme
    required property var typo
    required property var icons
    required property var filteredApps
    required property var modeManager
    
    signal searchTextChanged(string text)
    signal requestLaunchApp(var app)
    signal requestFocusGrid()
    
    Layout.preferredWidth: {
        if (root.parent && root.parent.parent) {
            let cols = Math.floor(root.parent.parent.width / 100)
            return cols > 0 ? cols * 100 : 100
        }
        return 100
    }
    Layout.preferredHeight: 50
    Layout.alignment: Qt.AlignHCenter
    color: "transparent"
    border.color: root.theme ? root.theme.surfaceBorder : Qt.rgba(0.70, 0.65, 0.90, 0.3)
    border.width: 2
    radius: height / 2
    z: 20
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12
        
        UI.SvgIcon {
            width: 20
            height: 20
            source: root.icons ? root.icons.iconData.search.value : ""
            color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
            opacity: 0.7
            visible: root.icons && root.icons.iconData.search.type === "svg"
        }
        
        Text {
            text: root.icons && root.icons.iconData.search.type === "text" ? "🔍" : ""
            font.pixelSize: 20
            opacity: 0.7
            visible: !root.icons || root.icons.iconData.search.type === "text"
        }
        
        TextInput {
            id: searchField
            Layout.fillWidth: true
            
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            font.pixelSize: root.typo ? root.typo.sizeLarge : 16
            font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
            
            selectByMouse: true
            selectionColor: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.4)
            focus: true
            
            Text {
                anchors.fill: parent
                text: "Search apps..."
                color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                font: searchField.font
                visible: searchField.text.length === 0 && !searchField.activeFocus
                opacity: 0.5
            }
            
            onTextChanged: {
                root.searchTextChanged(text)
            }
            
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Tab ||
                    event.key === Qt.Key_Down || 
                    event.key === Qt.Key_Up) {
                    root.requestFocusGrid()
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.filteredApps.length > 0) {
                        let app = root.filteredApps[0]
                        if (app && app.exec) {
                            root.requestLaunchApp(app)
                        }
                        event.accepted = true
                    } else {
                        event.accepted = false
                    }
                } else {
                    event.accepted = false
                }
            }
            
            MouseArea {
                anchors.fill: parent
                onPressed: {
                    searchField.forceActiveFocus()
                    mouse.accepted = false
                }
            }
        }
    }
    
    property alias text: searchField.text
    property alias searchFieldItem: searchField
}

