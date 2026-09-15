import QtQuick
import "../../lib" as Theme

RiggedIcon {
    id: rig

    RigPart {
        source: rig.rigDir + "/wallpaper/roll.svg"
        pivotX: 6; pivotY: 21
        dy: -1.2 * Theme.Rig.bump(rig.progress, 0.12, 0.08)
        sy: 1 - 0.15 * Theme.Rig.bump(rig.progress, 0.3, 0.08)
    }
    RigPart {
        source: rig.rigDir + "/wallpaper/sheet.svg"
        pivotX: 8; pivotY: 6
        sx: 1 + 0.15 * Theme.Rig.bump(rig.progress, 0.15, 0.1)
        rot: Theme.Rig.damped(rig.progress, 8, 2)
    }
}
