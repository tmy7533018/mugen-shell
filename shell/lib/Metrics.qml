pragma Singleton
import QtQuick

// The bar sizes every margin against this width, and anything that has to land
// on the bar's grid from another process has to use the same reference.
QtObject {
    readonly property real baseWidth: 1920

    function scaleTo(value, screenWidth) {
        return Math.round(value * screenWidth / baseWidth)
    }
}
