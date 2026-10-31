pragma Singleton
import QtQuick

QtObject {
    // First match wins, so the identifying categories come before the ones half the
    // desktop carries: Steam is Network;FileTransfer;Game and belongs under Games.
    readonly property var genres: [
        { "label": "Games", "keys": ["Game", "ActionGame", "StrategyGame", "Emulator"] },
        { "label": "Dev", "keys": ["Development", "IDE", "Building", "Debugger", "TextEditor"] },
        { "label": "Graphics", "keys": ["Graphics", "2DGraphics", "3DGraphics", "RasterGraphics", "VectorGraphics", "Photography"] },
        { "label": "Media", "keys": ["AudioVideo", "Audio", "Video", "Player", "Recorder", "TV", "Music"] },
        { "label": "Internet", "keys": ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging", "P2P", "FileTransfer"] },
        { "label": "System", "keys": ["System", "Settings", "Monitor", "Security", "HardwareSettings", "DesktopSettings"] },
        { "label": "Utilities", "keys": ["Utility", "FileManager", "FileTools", "TerminalEmulator", "Archiving", "Calculator"] }
    ]

    function genreOf(app) {
        let cats = (app && app.categories ? app.categories : "").split(";")
        for (let g = 0; g < genres.length; g++) {
            for (let c = 0; c < cats.length; c++) {
                if (cats[c] !== "" && genres[g].keys.indexOf(cats[c]) >= 0) {
                    return genres[g].label
                }
            }
        }
        return ""
    }

    function stripDiacritics(s) {
        return s.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    }

    function appAcronym(name) {
        let words = name.split(/[\s\-_./]+/).filter(w => w.length > 0)
        if (words.length < 2) return ""
        return words.map(w => w[0]).join("")
    }

    function fuzzyScore(target, query) {
        if (query.length < 3) return 0
        if (target.length < query.length) return 0

        let qi = 0
        let firstMatch = -1
        let lastMatch = -1
        let consecutive = 0
        let maxConsecutive = 0
        let boundaryBonus = 0

        for (let ti = 0; ti < target.length && qi < query.length; ti++) {
            if (target[ti] === query[qi]) {
                if (firstMatch === -1) firstMatch = ti
                lastMatch = ti
                consecutive++
                if (consecutive > maxConsecutive) maxConsecutive = consecutive
                if (ti === 0 || /[\s\-_./]/.test(target[ti - 1])) {
                    boundaryBonus += 5
                }
                qi++
            } else {
                consecutive = 0
            }
        }

        if (qi < query.length) return 0

        let span = lastMatch - firstMatch + 1
        if (span > query.length * 3) return 0

        return query.length * 10 + maxConsecutive * 5 + boundaryBonus - (span - query.length) * 2
    }

    function scoreApp(app, search, favorite) {
        if (!app || !app.name) return 0

        let q = stripDiacritics(search)
        let nameLower = stripDiacritics(app.name.toLowerCase())

        let base = 0
        if (nameLower === q) {
            base = 1000
        } else if (nameLower.startsWith(q)) {
            base = 500
        } else {
            let nameIdx = nameLower.indexOf(q)
            if (nameIdx >= 0) {
                base = 300 - Math.min(nameIdx, 100)
            } else if (appAcronym(nameLower) === q) {
                base = 250
            } else if (stripDiacritics((app.exec || "").toLowerCase()).includes(q)) {
                base = 150
            } else if (stripDiacritics((app.wmClass || "").toLowerCase()).includes(q)) {
                base = 120
            } else if (app.wmClassAliases && app.wmClassAliases.some(a => stripDiacritics(a.toLowerCase()).includes(q))) {
                base = 100
            } else if (stripDiacritics((app.keywords || "").toLowerCase()).includes(q)) {
                base = 80
            } else if (stripDiacritics((app.categories || "").toLowerCase()).includes(q)) {
                base = 50
            } else {
                let fz = fuzzyScore(nameLower, q)
                if (fz > 0) base = Math.min(40, fz)
            }
        }

        if (base > 0 && favorite) base += 200
        return base
    }
}
