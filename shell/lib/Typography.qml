import QtQuick

QtObject {
    id: typography

    property string fontFamily: "M PLUS 2"
    property string codeFamily: "M PLUS 1 Code"

    property real scale: 1.0

    property int weightThin:        Font.Thin
    property int weightExtraLight:  Font.ExtraLight
    property int weightLight:       Font.Light
    property int weightRegular:     Font.Normal
    property int weightMedium:      Font.Medium
    property int weightSemiBold:    Font.DemiBold
    property int weightBold:        Font.Bold
    property int weightExtraBold:   Font.ExtraBold
    property int weightBlack:       Font.Black

    property int sizeTiny:   Math.round(10 * scale)
    property int sizeSmall:  Math.round(11 * scale)
    property int sizeNormal: Math.round(13 * scale)
    property int sizeLarge:  Math.round(15 * scale)
    property int sizeHuge:   Math.round(18 * scale)

    // Hinting reduces blurriness for small text; large text looks better without
    property int hintSmall:  Font.PreferDefaultHinting
    property int hintLarge:  Font.PreferNoHinting

    property int defaultSize:   sizeNormal
    property int defaultWeight: weightLight

    property QtObject clockStyle: QtObject {
        property string family: typography.fontFamily
        property int     size:   typography.sizeLarge
        property int     weight: typography.weightMedium
        property real    letterSpacing: 0.4
        property int     hinting: typography.hintLarge
        property bool    kerning: true
    }

    property QtObject imeStyle: QtObject {
        property string family: typography.fontFamily
        property int     size:   typography.sizeNormal
        property int     weight: typography.weightLight
        property real    letterSpacing: 0.2
        property int     hinting: typography.hintSmall
        property bool    kerning: true
    }

    property QtObject systemInfoStyle: QtObject {
        property string family: typography.fontFamily
        property int     size:   typography.sizeSmall
        property int     weight: typography.weightLight
        property real    letterSpacing: 0.3
        property int     hinting: typography.hintSmall
        property bool    kerning: true
    }

    property QtObject workspaceStyle: QtObject {
        property string family: typography.fontFamily
        property int     size:   typography.sizeNormal
        property int     weight: typography.weightMedium
        property real    letterSpacing: 0.2
        property int     hinting: typography.hintSmall
        property bool    kerning: true
    }

    property QtObject monoStyle: QtObject {
        property string family: typography.codeFamily
        property int     size:   typography.sizeSmall
        property int     weight: typography.weightRegular
        property real    letterSpacing: 0.0
        property int     hinting: typography.hintSmall
        property bool    kerning: true
    }

    function applyStyle(target, style) {
        if (!target || !style) return;
        target.font.family = style.family;
        target.font.pixelSize = style.size;
        target.font.weight = style.weight;
        if ("kerning" in style)           target.font.kerning = style.kerning;
        if ("letterSpacing" in style)     target.font.letterSpacing = style.letterSpacing;
        if ("hinting" in style)           target.font.hintingPreference = style.hinting;
        // Text.NativeRendering not needed; Qt 6 defaults are fine
        // if ("renderType" in target) target.renderType = Text.NativeRendering;
    }
}
