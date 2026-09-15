import QtQuick
import "../../lib" as Theme

RiggedIcon {
    id: rig

    readonly property real spread: 1.5 * Theme.Rig.bump(rig.progress, 0.15, 0.1) + 0.6 * Theme.Rig.bump(rig.progress, 0.45, 0.1)

    RigPart {
        source: rig.rigDir + "/screenshot/cornerBL.svg"
        dx: -rig.spread
        dy: rig.spread
    }
    RigPart {
        source: rig.rigDir + "/screenshot/cornerTR.svg"
        dx: rig.spread
        dy: -rig.spread
    }
}
