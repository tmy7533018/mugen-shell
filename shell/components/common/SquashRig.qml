import QtQuick
import "../../lib" as Theme

RiggedIcon {
    id: rig

    property string source: ""

    RigPart {
        source: rig.source
        sx: 1 + Theme.Rig.damped(rig.progress, 0.1, 2)
        sy: 1 - Theme.Rig.damped(rig.progress, 0.1, 2)
    }
}
