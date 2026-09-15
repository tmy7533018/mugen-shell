import QtQuick
import "../../lib" as Theme

// Points left at rest; the caller rotates it 180° to point right, which keeps dx pointing along the chevrons.
RiggedIcon {
    id: rig

    RigPart {
        source: rig.rigDir + "/chevron-double-left/near.svg"
        dx: Theme.Rig.damped(rig.progress, -1.5, 2)
    }
    RigPart {
        source: rig.rigDir + "/chevron-double-left/far.svg"
        dx: Theme.Rig.damped(Theme.Rig.delay(rig.progress, 0.06), -1.5, 2)
    }
}
