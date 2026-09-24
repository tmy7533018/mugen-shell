pragma ComponentBehavior: Bound

import QtQuick
import "../../ui" as UI
import "../../../lib" as Theme

Column {
    id: root

    required property var modeManager
    required property var theme
    required property var icons
    property var toolCalls: []
    // Held by the caller: every streamed chunk rebuilds this component and would reset a local flag.
    property var openKeys: ({})
    property string keyPrefix: ""
    readonly property int collapsedMaxChars: 200

    signal toggleRequested(string key)

    spacing: modeManager.scale(4)

    Repeater {
        model: root.toolCalls

        delegate: Rectangle {
            id: chip
            required property var modelData
            required property int index

            readonly property bool pending: chip.modelData.pending === true
            readonly property string callError: chip.modelData.error || ""
            readonly property string callResult: chip.modelData.result == null
                ? "" : String(chip.modelData.result)

            readonly property string label: {
                let args = chip.modelData.arguments || ({})
                let parts = []
                for (let k in args) parts.push(k + "=" + args[k])
                let head = (chip.modelData.name || "")
                    + (parts.length > 0 ? "(" + parts.join(", ") + ")" : "")
                if (chip.pending) return head + " …"
                if (chip.callError !== "") return head + "  ⚠ " + chip.callError
                if (chip.callResult !== "") return head + "  → " + chip.callResult
                return head + "  ✓"
            }

            readonly property string collapsedLabel: {
                const lineEnd = chip.label.search(/[\r\n\u2028\u2029]/)
                const first = lineEnd < 0 ? chip.label : chip.label.substring(0, lineEnd)
                let n = Math.min(first.length, root.collapsedMaxChars)
                if (n < first.length && /[\uD800-\uDBFF]/.test(first.charAt(n - 1))) n--
                const line = first.substring(0, n)
                return line.length < chip.label.length ? line + "…" : line
            }
            readonly property string openKey: root.keyPrefix + ":" + chip.index
            readonly property bool expanded: !!root.openKeys[chip.openKey]
            readonly property bool canExpand: chip.expanded || labelText.truncated
                || chip.collapsedLabel !== chip.label

            readonly property real hPad: root.modeManager.scale(9)
            readonly property real vPad: root.modeManager.scale(5)
            readonly property real iconGap: root.modeManager.scale(6)

            width: Math.min(gear.width + iconGap + labelText.implicitWidth + hPad * 2, root.width)
            height: Math.max(labelText.implicitHeight, gear.height) + vPad * 2
            radius: root.modeManager.scale(9)

            property real pulse: 1.0
            opacity: chip.pending ? chip.pulse : 1.0

            color: chip.callError !== ""
                ? Qt.rgba(0.85, 0.45, 0.45, 0.16)
                : (chip.pending
                    ? (root.theme ? root.theme.chipInactiveBg : Qt.rgba(0.55, 0.55, 0.68, 0.10))
                    : (root.theme ? root.theme.chipActiveBg : Qt.rgba(0.55, 0.65, 0.85, 0.18)))
            border.width: 1
            border.color: chip.callError !== ""
                ? Qt.rgba(0.85, 0.45, 0.45, 0.38)
                : (root.theme ? root.theme.chipInactiveBorder : Qt.rgba(0.55, 0.55, 0.68, 0.15))

            Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

            SequentialAnimation {
                running: chip.pending
                loops: Animation.Infinite
                NumberAnimation { target: chip; property: "pulse"; to: 0.5; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { target: chip; property: "pulse"; to: 0.95; duration: 700; easing.type: Easing.InOutSine }
            }

            UI.SvgIcon {
                id: gear
                anchors.left: parent.left
                anchors.leftMargin: chip.hPad
                anchors.top: parent.top
                anchors.topMargin: chip.vPad + root.modeManager.scale(2)
                width: root.modeManager.scale(11)
                height: width
                source: root.icons ? root.icons.settingsSvg : ""
                color: chip.callError !== ""
                    ? Qt.rgba(0.94, 0.66, 0.66, 0.95)
                    : (root.theme ? root.theme.textFaint : Qt.rgba(0.62, 0.62, 0.72, 0.8))
            }

            Text {
                id: labelText
                anchors.left: gear.right
                anchors.leftMargin: chip.iconGap
                anchors.right: parent.right
                anchors.rightMargin: chip.hPad
                anchors.top: parent.top
                anchors.topMargin: chip.vPad
                text: chip.expanded ? chip.label : chip.collapsedLabel
                textFormat: Text.PlainText
                elide: chip.expanded ? Text.ElideNone : Text.ElideRight
                wrapMode: chip.expanded ? Text.Wrap : Text.NoWrap
                color: root.theme ? root.theme.textSecondary : Qt.rgba(0.85, 0.85, 0.90, 0.85)
                font.pixelSize: root.modeManager.scale(11)
                font.family: "M PLUS 2"
                font.letterSpacing: 0.2
            }

            MouseArea {
                anchors.fill: parent
                enabled: chip.canExpand
                cursorShape: chip.canExpand ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.toggleRequested(chip.openKey)
            }
        }
    }
}
