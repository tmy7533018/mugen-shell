import QtQuick
import Quickshell
import "../../lib" as Theme

RiggedIcon {
    id: rig

    property string variant: "open"

    Loader {
        anchors.fill: parent
        sourceComponent: rig.variant === "closed" ? closed : open
    }

    Component {
        id: open
        Item {
            RigPart { source: rig.rigDir + "/eye-open/lid.svg" }
            RigPart { source: rig.rigDir + "/eye-open/iris.svg" }
        }
    }

    Component {
        id: closed
        Item {
            RigPart { source: Quickshell.shellDir + "/assets/icons/eye-closed.svg" }
        }
    }
}
