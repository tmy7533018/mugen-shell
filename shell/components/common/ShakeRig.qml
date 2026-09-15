import QtQuick
import "../../lib" as Theme

RiggedIcon {
    id: rig

    property string source: ""

    RigPart {
        source: rig.source
        dx: Theme.Rig.damped(rig.progress, 1.2, 3)
    }
}
