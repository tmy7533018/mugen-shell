import QtQuick
import "../../ui" as UI
import "../../../lib" as Theme

Row {
    id: root

    required property var modeManager
    required property var theme
    required property var icons
    property bool canSpeak: false
    property bool speaking: false

    signal copyRequested()
    signal speakToggled()

    spacing: modeManager.scale(4)

    property bool justCopied: false

    Timer {
        id: copiedReset
        interval: 1200
        onTriggered: root.justCopied = false
    }

    // Every id it needs comes in as a property: an inline component can't see
    // the enclosing file's ids.
    component ActionButton: Rectangle {
        id: btn

        required property var mgr
        required property var pal
        property string iconSource: ""
        property string glyph: ""
        property real glyphSize: 15
        property bool lit: false

        signal triggered()

        width: btn.mgr.scale(27)
        height: btn.mgr.scale(23)
        radius: btn.mgr.scale(6)
        color: btnMouse.containsMouse
            ? (btn.pal ? Qt.rgba(btn.pal.glowPrimary.r, btn.pal.glowPrimary.g, btn.pal.glowPrimary.b, 0.22) : Qt.rgba(0.65, 0.55, 0.85, 0.22))
            : (btn.pal ? Qt.rgba(btn.pal.textPrimary.r, btn.pal.textPrimary.g, btn.pal.textPrimary.b, 0.08) : Qt.rgba(0.9, 0.9, 0.95, 0.08))

        Behavior on color { ColorAnimation { duration: Theme.Motion.micro } }

        UI.SvgIcon {
            anchors.centerIn: parent
            width: btn.mgr.scale(15)
            height: width
            visible: btn.glyph === ""
            source: btn.iconSource
            color: (btnMouse.containsMouse || btn.lit)
                ? (btn.pal ? btn.pal.textPrimary : Qt.rgba(0.95, 0.93, 0.98, 0.98))
                : (btn.pal ? btn.pal.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.7))
        }

        Text {
            anchors.centerIn: parent
            visible: btn.glyph !== ""
            text: btn.glyph
            color: btn.pal ? btn.pal.accent : Qt.rgba(0.55, 0.85, 0.65, 0.95)
            font.pixelSize: btn.glyphSize
            font.family: "M PLUS 2"
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered()
        }
    }

    ActionButton {
        mgr: root.modeManager
        pal: root.theme
        iconSource: root.icons ? root.icons.copySvg : ""
        glyph: root.justCopied ? "✓" : ""
        glyphSize: root.modeManager.scale(15)
        lit: root.justCopied
        onTriggered: {
            root.copyRequested()
            root.justCopied = true
            copiedReset.restart()
        }
    }

    ActionButton {
        visible: root.canSpeak
        mgr: root.modeManager
        pal: root.theme
        iconSource: root.icons ? root.icons.volumeUpSvg : ""
        glyph: root.speaking ? "■" : ""
        glyphSize: root.modeManager.scale(11)
        lit: root.speaking
        onTriggered: root.speakToggled()
    }
}
