import QtQuick
import "../../lib" as Theme

RiggedIcon {
    id: rig

    RigPart { source: rig.rigDir + "/music/headL.svg" }
    RigPart {
        source: rig.rigDir + "/music/stem.svg"
        pivotX: 6.5; pivotY: 17.5
        rot: Theme.Rig.damped(rig.progress, 12, 2)
    }
    RigPart {
        source: rig.rigDir + "/music/headR.svg"
        pivotX: 6.5; pivotY: 17.5
        rot: Theme.Rig.damped(Theme.Rig.delay(rig.progress, 0.06), 12, 2)
    }
}
