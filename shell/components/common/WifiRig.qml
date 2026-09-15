import QtQuick
import "../../lib" as Theme

RiggedIcon {
    id: rig

    RigPart { source: rig.rigDir + "/wifi/dot.svg" }
    Repeater {
        model: 3
        RigPart {
            required property int index
            source: rig.rigDir + "/wifi/arc" + (index + 1) + ".svg"
            pivotX: 12; pivotY: 19
            sx: 1 + 0.15 * Theme.Rig.pulse(rig.progress, index, 3)
            sy: sx
            alpha: 1 - 0.3 * Theme.Rig.pulse(rig.progress, index, 3)
        }
    }
}
