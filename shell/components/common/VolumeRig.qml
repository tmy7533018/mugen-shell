import QtQuick
import Quickshell
import "../../lib" as Theme

RiggedIcon {
    id: rig

    property string variant: "up"

    Loader {
        anchors.fill: parent
        sourceComponent: rig.variant === "headphones" ? headphones : (rig.variant === "down" ? down : up)
    }

    Component {
        id: up
        Item {
            RigPart {
                source: rig.rigDir + "/volume-up/body.svg"
                pivotX: 8.5; pivotY: 12
                sx: 1 - 0.1 * Theme.Rig.bump(rig.progress, 0.12, 0.08)
            }
            RigPart {
                source: rig.rigDir + "/volume-up/wave1.svg"
                sx: 1 + 0.2 * Theme.Rig.pulse(rig.progress, 0, 2)
                sy: sx
                alpha: 1 - 0.7 * Theme.Rig.pulse(rig.progress, 0, 2)
                dx: 1.2 * Theme.Rig.pulse(rig.progress, 0, 2)
            }
            RigPart {
                source: rig.rigDir + "/volume-up/wave2.svg"
                sx: 1 + 0.2 * Theme.Rig.pulse(rig.progress, 1, 2)
                sy: sx
                alpha: 1 - 0.7 * Theme.Rig.pulse(rig.progress, 1, 2)
                dx: 1.2 * Theme.Rig.pulse(rig.progress, 1, 2)
            }
        }
    }

    Component {
        id: down
        Item {
            RigPart {
                source: rig.rigDir + "/volume-down/body.svg"
                pivotX: 10; pivotY: 12
                sx: 1 - 0.1 * Theme.Rig.bump(rig.progress, 0.12, 0.08)
            }
            RigPart {
                source: rig.rigDir + "/volume-down/wave1.svg"
                sx: 1 + 0.2 * Theme.Rig.pulse(rig.progress, 0, 1)
                sy: sx
                alpha: 1 - 0.7 * Theme.Rig.pulse(rig.progress, 0, 1)
                dx: 1.2 * Theme.Rig.pulse(rig.progress, 0, 1)
            }
        }
    }

    Component {
        id: headphones
        Item {
            RigPart {
                source: Quickshell.shellDir + "/assets/icons/headphones.svg"
                pivotX: 12; pivotY: 2
                rot: Theme.Rig.damped(rig.progress, 8, 2)
            }
        }
    }
}
