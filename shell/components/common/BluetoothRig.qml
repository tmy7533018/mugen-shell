import QtQuick
import "../../lib" as Theme

// The bluetooth icons are drawn on a 16 grid, so every pivot is the 16-grid point times 1.5.
RiggedIcon {
    id: rig

    property string variant: "plain"

    Loader {
        anchors.fill: parent
        sourceComponent: rig.variant === "searching" ? searching : (rig.variant === "connected" ? connected : plain)
    }

    // Inline components cannot see the file's ids, so the rune gets progress and the asset dir passed in.
    component Rune: Item {
        property string dir
        property real stemX
        property real t
        property string base
        anchors.fill: parent
        RigPart { source: base + "/" + dir + "/stem.svg" }
        RigPart {
            source: base + "/" + dir + "/top.svg"
            pivotX: stemX * 1.5; pivotY: 1.75 * 1.5
            rot: Theme.Rig.damped(t, 14, 2)
        }
        RigPart {
            source: base + "/" + dir + "/bottom.svg"
            pivotX: stemX * 1.5; pivotY: 14.25 * 1.5
            rot: -Theme.Rig.damped(Theme.Rig.delay(t, 0.06), 14, 2)
        }
    }

    Component {
        id: plain
        Rune { dir: "bluetooth"; stemX: 7.75; t: rig.progress; base: rig.rigDir }
    }

    Component {
        id: connected
        Item {
            Rune { dir: "bluetooth-connected"; stemX: 7.75; t: rig.progress; base: rig.rigDir }
            RigPart {
                source: rig.rigDir + "/bluetooth-connected/dashes.svg"
                pivotX: 7.75 * 1.5; pivotY: 8 * 1.5
                sx: 1 + 0.25 * Theme.Rig.damped(rig.progress, 1, 2)
            }
        }
    }

    Component {
        id: searching
        Item {
            Rune { dir: "bluetooth-searching"; stemX: 5.75; t: rig.progress; base: rig.rigDir }
            RigPart { source: rig.rigDir + "/bluetooth-searching/dot.svg" }
            RigPart {
                source: rig.rigDir + "/bluetooth-searching/arc.svg"
                pivotX: 11.25 * 1.5; pivotY: 8 * 1.5
                sx: 1 + 0.35 * Theme.Rig.pulse(rig.progress, 0, 1)
                sy: sx
                alpha: 1 - 0.6 * Theme.Rig.pulse(rig.progress, 0, 1)
            }
        }
    }
}
