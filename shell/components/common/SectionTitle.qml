import QtQuick

// Small dim caps naming a band of content, the way the weather panel names its location.
Text {
    property var theme
    property var typo

    font.family: typo ? typo.fontFamily : "M PLUS 2"
    font.pixelSize: typo ? typo.sizeTiny : 10
    font.letterSpacing: 2.5
    font.capitalization: Font.AllUppercase
    color: theme ? theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.60)
}
