import QtQuick
import QtQuick.Layouts
import "../../common" as Common

Rectangle {
    id: section

    required property var theme
    required property var modeManager
    required property var settingsManager

    signal openUrl(string url)

    readonly property string repoUrl: "https://github.com/tmy7533018/mugen-shell"

    width: parent ? parent.width : 420
    // Driven by the content: a fixed height silently squeezes the logo and clips the last row.
    height: body.implicitHeight + 56
    color: theme ? theme.surfaceInsetSubtle : Qt.rgba(0, 0, 0, 0.25)
    radius: 20
    border.width: 1
    border.color: theme ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2) : Qt.rgba(0.65, 0.55, 0.85, 0.2)

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 28
        spacing: 12

        Common.LogoMark {
            id: mark
            Layout.alignment: Qt.AlignHCenter
            width: 168
            animated: !(section.settingsManager && section.settingsManager.reduceMotion)

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: mark.play()
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            text: "Mugen Shell"
            color: section.theme ? section.theme.textPrimary : Qt.rgba(0.91, 0.91, 0.94, 0.95)
            font.pixelSize: 22
            font.family: "M PLUS 2"
            font.weight: Font.Light
            font.letterSpacing: 1.5
        }

        Text {
            Layout.fillWidth: true
            Layout.maximumWidth: 560
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            text: "A Quickshell + Hyprland desktop, and Yura, the assistant living in it."
            color: section.theme ? section.theme.textSecondary : Qt.rgba(0.72, 0.72, 0.82, 0.90)
            font.pixelSize: 13
            font.family: "M PLUS 2"
            font.letterSpacing: 0.5
            lineHeight: 1.5
            wrapMode: Text.WordWrap
        }

        Text {
            id: meta
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.StyledText
            text: '<a href="' + section.repoUrl + '">github.com/tmy7533018/mugen-shell</a>'
            color: section.theme ? section.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.75)
            linkColor: meta.hoveredLink !== ""
                ? (section.theme ? section.theme.textPrimary : Qt.rgba(0.92, 0.92, 0.96, 0.95))
                : (section.theme ? section.theme.accent : Qt.rgba(0.65, 0.55, 0.85, 0.9))
            font.pixelSize: 12
            font.family: "M PLUS 2"

            onLinkActivated: link => section.openUrl(link)

            // NoButton so the link keeps the clicks; this only carries the cursor shape.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                cursorShape: meta.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }
    }
}
