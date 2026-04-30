import QtQuick
import QtQuick.Layouts
import "../../common" as Common

Item {
    id: musicButtonWrapper

    required property var theme
    required property var typo
    required property var icons
    required property var modeManager
    required property var musicPlayerManager
    required property var cavaManager

    function scaled(v) { return modeManager ? modeManager.scale(v) : v }

    function blendColors(baseColor, accentColor, factor) {
        const safeFactor = Math.max(0, Math.min(1, factor || 0))
        const base = baseColor || (theme ? theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90))
        const accent = accentColor || Qt.rgba(0.65, 0.55, 0.85, 0.9)
        return Qt.rgba(
            base.r + (accent.r - base.r) * safeFactor,
            base.g + (accent.g - base.g) * safeFactor,
            base.b + (accent.b - base.b) * safeFactor,
            base.a + (accent.a - base.a) * safeFactor
        )
    }

    implicitWidth: isPlaying ? scaled(33) : scaled(24)
    implicitHeight: scaled(24)
    Layout.alignment: Qt.AlignVCenter
    Layout.leftMargin: scaled(4)

    property bool isPlaying: musicPlayerManager ? musicPlayerManager.isPlaying : false
    property color baseColor: theme ? theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.90)
    property color accentColor: musicPlayerManager && musicPlayerManager.accentColor
        ? musicPlayerManager.accentColor
        : (theme ? theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
    property real colorPhase: 0

    property color currentIconColor: blendColors(baseColor, accentColor, isPlaying ? colorPhase : 0)

    readonly property real visualizerWidth: scaled(6 * 3 + 5 * 3)

    onIsPlayingChanged: {
        if (!isPlaying) {
            colorPhase = 0
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 420;
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: iconPanel
        anchors.fill: parent
        opacity: (!musicButtonWrapper.isPlaying || visualizerHoverHandler.hovered) ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
        }

        Common.IconButton {
            id: musicButton
            anchors.centerIn: parent
            modeManager: musicButtonWrapper.modeManager
            iconSource: musicButtonWrapper.icons ? (musicButtonWrapper.icons.iconData.music.type === "svg" ? musicButtonWrapper.icons.iconData.music.value : "") : ""
            iconText: musicButtonWrapper.icons ? (musicButtonWrapper.icons.iconData.music.type === "text" ? musicButtonWrapper.icons.iconData.music.value : "") : ""
            iconColor: musicButtonWrapper.currentIconColor
            fontSize: musicButtonWrapper.typo ? musicButtonWrapper.typo.clockStyle.size : 14
            fontFamily: musicButtonWrapper.typo ? musicButtonWrapper.typo.clockStyle.family : "M PLUS 2"
            fontWeight: musicButtonWrapper.typo ? musicButtonWrapper.typo.clockStyle.weight : Font.Normal
            letterSpacing: musicButtonWrapper.typo ? musicButtonWrapper.typo.clockStyle.letterSpacing : 0

            Behavior on iconColor {
                ColorAnimation { duration: 600; easing.type: Easing.InOutCubic }
            }

            onClicked: {
                if (musicButtonWrapper.modeManager) {
                    musicButtonWrapper.modeManager.switchMode("music")
                }
            }
        }
    }

    Common.BarVisualizer {
        id: barVisualizer
        anchors.centerIn: parent
        cavaManager: musicButtonWrapper.cavaManager
        barWidth: musicButtonWrapper.scaled(3)
        barSpacing: musicButtonWrapper.scaled(3)
        minBarHeight: musicButtonWrapper.scaled(6)
        maxBarHeight: musicButtonWrapper.scaled(28)
        barColor: musicButtonWrapper.accentColor
        baseColor: musicButtonWrapper.theme ? musicButtonWrapper.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.85)
        opacity: musicButtonWrapper.isPlaying
            ? (visualizerHoverHandler.hovered ? 0.0 : 0.6)
            : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
        }

        Behavior on barColor {
            ColorAnimation { duration: 600; easing.type: Easing.InOutCubic }
        }
    }

    SequentialAnimation on colorPhase {
        loops: Animation.Infinite
        running: musicButtonWrapper.isPlaying
        NumberAnimation {
            from: 0
            to: 1
            duration: 1600
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            from: 1
            to: 0
            duration: 1600
            easing.type: Easing.InOutSine
        }
    }

    HoverHandler {
        id: visualizerHoverHandler
        enabled: musicButtonWrapper.isPlaying
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        id: visualizerClickArea
        anchors.fill: parent
        hoverEnabled: false
        cursorShape: Qt.PointingHandCursor
        visible: musicButtonWrapper.isPlaying
        enabled: musicButtonWrapper.isPlaying
        onClicked: {
            if (musicButtonWrapper.modeManager) {
                musicButtonWrapper.modeManager.switchMode("music")
            }
        }
        z: 1
    }
}
