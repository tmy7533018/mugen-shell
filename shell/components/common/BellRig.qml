import QtQuick
import "../../lib" as Theme

RiggedIcon {
    id: rig

    RigPart {
        source: rig.rigDir + "/notification/shell.svg"
        pivotX: 12; pivotY: 2
        rot: Theme.Rig.damped(rig.progress, 12, 2)
    }
}
