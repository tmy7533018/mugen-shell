pragma Singleton
import QtQuick

QtObject {
    id: palettes

    readonly property var list: [
        {
            "id": "harmony", "name": "Harmony",
            "satMin": 0.22, "satMax": 0.55, "spin": 0, "strength": 0.85,
            "levels": [0.24, 0.10, 0.19, 0.06], "sourceIndex": [0, 1, 2, 0]
        },
        {
            "id": "duotone", "name": "Duotone",
            "satMin": 0.28, "satMax": 0.60, "spin": 0, "strength": 0.88,
            "levels": [0.24, 0.08, 0.22, 0.08], "sourceIndex": [0, 2, 2, 0]
        },
        {
            "id": "vivid", "name": "Vivid",
            "satMin": 0.50, "satMax": 0.85, "spin": 0, "strength": 0.92,
            "levels": [0.26, 0.11, 0.20, 0.07], "sourceIndex": [0, 1, 2, 0]
        },
        {
            "id": "muted", "name": "Muted",
            "satMin": 0.08, "satMax": 0.22, "spin": 0, "strength": 0.80,
            "levels": [0.22, 0.11, 0.18, 0.08], "sourceIndex": [0, 1, 2, 0]
        },
        {
            "id": "spectrum", "name": "Spectrum",
            "satMin": 0.30, "satMax": 0.60, "spin": 35, "strength": 0.88,
            "levels": [0.24, 0.10, 0.19, 0.07], "sourceIndex": [0, 1, 2, 0]
        },
        {
            "id": "flat", "name": "Flat",
            "satMin": 0.22, "satMax": 0.55, "spin": 0, "strength": 0.0,
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
