import QtQuick
import "../../lib" as Theme

RiggedIcon {
    id: rig

    Repeater {
        model: [
            { part: "sq0", ux: -1, uy: -1 },
            { part: "sq1", ux: 1, uy: -1 },
            { part: "sq2", ux: 1, uy: 1 },
            { part: "sq3", ux: -1, uy: 1 }
        ]
        RigPart {
            required property var modelData
            required property int index
            readonly property real t: Theme.Rig.delay(rig.progress, index * Theme.Rig.fraction(30))
            source: rig.rigDir + "/app-launcher/" + modelData.part + ".svg"
            dx: modelData.ux * Theme.Rig.damped(t, 1.2, 2)
            dy: modelData.uy * Theme.Rig.damped(t, 1.2, 2)
        }
    }
}
