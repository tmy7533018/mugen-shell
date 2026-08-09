pragma Singleton
import QtQuick

QtObject {
    id: palettes

    readonly property var list: [
        {
            "id": "harmony", "name": "Harmony",
            "satMin": 0.22, "satMax": 0.55, "hueOffsets": [0, -20, 20, 0], "strength": 0.85,
            "levels": [0.24, 0.10, 0.19, 0.06], "sourceIndex": [0, 1, 2, 0]
        },
        {
            "id": "duotone", "name": "Duotone",
            "satMin": 0.30, "satMax": 0.65, "hueOffsets": [0, 0, 160, 160], "strength": 0.92,
            "levels": [0.40, 0.06, 0.24, 0.04], "sourceIndex": [0, 0, 0, 0]
        },
        {
            "id": "vivid", "name": "Vivid",
            "satMin": 0.55, "satMax": 0.95, "hueOffsets": [0, -25, 25, 0], "strength": 0.95,
            "levels": [0.42, 0.20, 0.35, 0.14], "sourceIndex": [0, 1, 2, 0]
        },
        {
            "id": "muted", "name": "Muted",
            "satMin": 0.00, "satMax": 0.05, "hueOffsets": [0, 0, 0, 0], "strength": 0.85,
            "levels": [0.31, 0.17, 0.27, 0.13], "sourceIndex": [0, 1, 2, 0]
        },
        {
            "id": "spectrum", "name": "Spectrum",
            "satMin": 0.35, "satMax": 0.65, "hueOffsets": [0, 60, 120, 180], "strength": 0.90,
            "levels": [0.28, 0.14, 0.24, 0.10], "sourceIndex": [0, 1, 2, 0]
        },
        {
            "id": "flat", "name": "Flat",
            "satMin": 0.22, "satMax": 0.55, "hueOffsets": [0, 0, 0, 0], "strength": 0.0,
            "levels": [0.24, 0.10, 0.19, 0.06], "sourceIndex": [0, 1, 2, 0]
        }
    ]

    readonly property string fallbackId: "harmony"

    function byId(id) {
        for (let i = 0; i < palettes.list.length; i++) {
            if (palettes.list[i].id === id) return palettes.list[i]
        }
        return palettes.list[0]
    }
}
