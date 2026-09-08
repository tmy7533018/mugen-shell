import QtQuick
import QtQuick.Layouts
import "../ui" as UI

Rectangle {
    id: root
    
    required property var theme
    property var typo: null
    required property var icons
    required property int resultCount
    property string placeholder: "Search..."
    property int fieldHeight: 50
    property int borderWidth: 2

    readonly property int iconSize: Math.round(fieldHeight * 0.40)
    readonly property int hPadding: Math.round(fieldHeight * 0.32)
    readonly property int gap: Math.round(fieldHeight * 0.24)
    readonly property int textSize: Math.round(fieldHeight * 0.32)
    
    signal searchTextChanged(string text)
    signal requestActivateSelected()
    signal requestFocusResults(bool backwards)
    
    implicitHeight: root.fieldHeight
    color: "transparent"
    border.color: root.theme ? root.theme.surfaceBorder : Qt.rgba(0.70, 0.65, 0.90, 0.3)
    border.width: root.borderWidth
    radius: height / 2
    z: 20
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.hPadding
        anchors.rightMargin: root.hPadding
        spacing: root.gap
        
        UI.SvgIcon {
            width: root.iconSize
            height: root.iconSize
            source: root.icons ? root.icons.iconData.search.value : ""
            color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
            opacity: 0.7
            visible: root.icons && root.icons.iconData.search.type === "svg"
        }
        
        Text {
            text: root.icons && root.icons.iconData.search.type === "text" ? "🔍" : ""
            font.pixelSize: root.iconSize
            opacity: 0.7
            visible: !root.icons || root.icons.iconData.search.type === "text"
        }
        
        TextInput {
            id: searchField
            Layout.fillWidth: true
            
            color: root.theme ? root.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
            font.pixelSize: root.textSize
            font.family: root.typo ? root.typo.fontFamily : "M PLUS 2"
            
            selectByMouse: true
            selectionColor: root.theme ? root.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.4)
            focus: true
            
            Text {
                anchors.fill: parent
                text: root.placeholder
                color: root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
                font: searchField.font
                visible: searchField.text.length === 0 && !searchField.activeFocus
                opacity: 0.5
            }
            
            onTextChanged: {
                root.searchTextChanged(text)
            }
            
            Keys.onPressed: (event) => {
                // Backtab too: unhandled it falls through to Qt's focus traversal and bounces focus around.
                if (event.key === Qt.Key_Tab ||
                    event.key === Qt.Key_Backtab ||
                    event.key === Qt.Key_Down || 
                    event.key === Qt.Key_Up) {
                    root.requestFocusResults(event.key === Qt.Key_Backtab || event.key === Qt.Key_Up)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.resultCount > 0) {
                        root.requestActivateSelected()
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

