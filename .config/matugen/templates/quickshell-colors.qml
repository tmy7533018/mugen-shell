import QtQuick

QtObject {
    id: palette

    // Gradient colors from matugen
    property string primaryHex: "{{colors.primary.default.hex}}"
    property string secondaryHex: "{{colors.secondary.default.hex}}"
    property string tertiaryHex: "{{colors.tertiary.default.hex}}"
    
    property color glowPrimary: Qt.rgba(
        parseInt(primaryHex.substring(1, 3), 16) / 255,
        parseInt(primaryHex.substring(3, 5), 16) / 255,
        parseInt(primaryHex.substring(5, 7), 16) / 255,
        0.85
    )
    
    property color glowSecondary: Qt.rgba(
        parseInt(secondaryHex.substring(1, 3), 16) / 255,
        parseInt(secondaryHex.substring(3, 5), 16) / 255,
        parseInt(secondaryHex.substring(5, 7), 16) / 255,
        0.85
    )
    
    property color glowTertiary: Qt.rgba(
        parseInt(tertiaryHex.substring(1, 3), 16) / 255,
        parseInt(tertiaryHex.substring(3, 5), 16) / 255,
        parseInt(tertiaryHex.substring(5, 7), 16) / 255,
        0.85
    )
    
    property color surfaceBorder: Qt.rgba(0.70, 0.65, 0.90, 0.3)
    property color surfaceGlass: Qt.rgba(0.08, 0.05, 0.15, 0.32)

    property color textPrimary: Qt.rgba(0.92, 0.92, 0.96, 0.90)
    property color textSecondary: Qt.rgba(0.72, 0.72, 0.82, 0.90)
    property color textFaint: Qt.rgba(0.62, 0.62, 0.72, 0.90)

    // Workspace chip colors
    property color chipActiveBg: Qt.rgba(
        parseInt(primaryHex.substring(1, 3), 16) / 255,
        parseInt(primaryHex.substring(3, 5), 16) / 255,
        parseInt(primaryHex.substring(5, 7), 16) / 255,
        0.25
    )
    
    property color chipActiveBorder: Qt.rgba(
        parseInt(primaryHex.substring(1, 3), 16) / 255,
        parseInt(primaryHex.substring(3, 5), 16) / 255,
        parseInt(primaryHex.substring(5, 7), 16) / 255,
        0.40
    )
    
    property color chipInactiveBg: Qt.rgba(0.45, 0.45, 0.60, 0.10)
    property color chipInactiveBorder: Qt.rgba(0.55, 0.55, 0.68, 0.15)

    property color accent: Qt.rgba(
        parseInt(primaryHex.substring(1, 3), 16) / 255,
        parseInt(primaryHex.substring(3, 5), 16) / 255,
        parseInt(primaryHex.substring(5, 7), 16) / 255,
        0.85
    )
}
