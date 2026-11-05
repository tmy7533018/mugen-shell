pragma Singleton
import QtQuick

QtObject {
    readonly property var catalog: [
        { id: "launcher", label: "Launcher", side: "left", icon: "app-launcher", hint: "" },
        { id: "clock", label: "Clock", side: "left", icon: "clock", hint: "" },
        { id: "timer", label: "Timer", side: "left", icon: "clock", hint: "Only while running" },
        { id: "weather", label: "Weather", side: "left", icon: "weather-clear", hint: "When weather is on" },
        { id: "wallpaper", label: "Wallpaper", side: "left", icon: "wallpaper", hint: "" },
        { id: "screenshot", label: "Screenshot", side: "left", icon: "screenshot", hint: "" },
        { id: "volume", label: "Volume", side: "left", icon: "volume-up", hint: "" },
        { id: "music", label: "Music", side: "left", icon: "music", hint: "" },
        { id: "yura", label: "Yura", side: "left", icon: "ai", hint: "" },
        { id: "tray", label: "Tray", side: "right", icon: "chevron-double-left", hint: "" },
        { id: "notifications", label: "Notifications", side: "right", icon: "notification", hint: "" },
        { id: "ime", label: "Input", side: "right", icon: "japanese-aquare", hint: "" },
        { id: "idle", label: "Keep awake", side: "right", icon: "eye-open", hint: "" },
        { id: "brightness", label: "Brightness", side: "right", icon: "moon", hint: "Only with a backlight" },
        { id: "battery", label: "Battery", side: "right", icon: "battery", hint: "Only with a battery" },
        { id: "airplane", label: "Airplane", side: "right", icon: "airplane", hint: "Only with a battery" },
        { id: "wifi", label: "Wi-Fi", side: "right", icon: "wifi", hint: "" },
        { id: "bluetooth", label: "Bluetooth", side: "right", icon: "bluetooth", hint: "" },
        { id: "power", label: "Power", side: "right", icon: "power-shutdown", hint: "" }
    ]

    readonly property string separatorId: "separator"

    readonly property var _defaultOrder: [
        ["left", "launcher"], ["left", "separator"], ["left", "clock"], ["left", "timer"], ["left", "separator"],
        ["left", "weather"], ["left", "separator"], ["left", "wallpaper"], ["left", "screenshot"], ["left", "separator"],
        ["left", "volume"], ["left", "music"], ["left", "separator"], ["left", "yura"],
        ["right", "tray"], ["right", "separator"], ["right", "notifications"], ["right", "separator"],
        ["right", "ime"], ["right", "idle"], ["right", "brightness"], ["right", "battery"], ["right", "separator"],
        ["right", "airplane"], ["right", "wifi"], ["right", "bluetooth"], ["right", "separator"], ["right", "power"]
    ]

    function defaultItems() {
        return _defaultOrder.map(e => ({ id: e[1], side: e[0], visible: true }))
    }

    function _catalogEntry(id) {
        return catalog.find(c => c.id === id)
    }

    function _isKnown(id) {
        return id === separatorId || _catalogEntry(id) !== undefined
    }

    function itemsOf(v) {
        if (!Array.isArray(v))
            return defaultItems()
        const out = []
        const seen = Object.create(null)
        for (const e of v) {
            if (e === null || typeof e !== "object" || typeof e.id !== "string" || e.id === "")
                continue
            const known = _catalogEntry(e.id)
            const side = (e.side === "left" || e.side === "right") ? e.side : (known ? known.side : "")
            if (side === "")
                continue
            if (e.id === separatorId) {
                out.push({ id: e.id, side: side, visible: true })
                continue
            }
            if (seen[e.id])
                continue
            seen[e.id] = true
            out.push({ id: e.id, side: side, visible: typeof e.visible === "boolean" ? e.visible : true })
        }
        for (const c of catalog) {
            if (!seen[c.id])
                out.push({ id: c.id, side: c.side, visible: true })
        }
        return out
    }

    function sectionIds(items, side) {
        return items.filter(i => i.side === side && i.visible && _isKnown(i.id)).map(i => i.id)
    }

    function shownSeparators(ids, unavailable) {
        const usable = id => id !== separatorId && !unavailable[id]
        const iconAfter = new Array(ids.length).fill(false)
        let later = false
        for (let i = ids.length - 1; i >= 0; i--) {
            iconAfter[i] = later
            if (usable(ids[i]))
                later = true
        }
        const out = []
        let iconSinceLine = false
        for (let i = 0; i < ids.length; i++) {
            if (ids[i] === separatorId) {
                const draw = iconSinceLine && iconAfter[i]
                out.push(draw)
                if (draw)
                    iconSinceLine = false
            } else {
                out.push(false)
                if (usable(ids[i]))
                    iconSinceLine = true
            }
        }
        return out
    }

    function _entries(items, keep) {
        const out = []
        items.forEach((it, itemIndex) => {
            if (_isKnown(it.id) && keep(it))
                out.push({ id: it.id, itemIndex: itemIndex })
        })
        return out
    }

    function displayEntries(items, side) {
        return _entries(items, it => it.side === side && it.visible)
    }

    function hiddenEntries(items) {
        return _entries(items, it => !it.visible)
    }

    function _insertAt(rest, item, side, position) {
        const entries = displayEntries(rest, side)
        const out = rest.map(i => ({ id: i.id, side: i.side, visible: i.visible }))
        let at
        if (position < entries.length)
            at = entries[Math.max(0, position)].itemIndex
        else if (entries.length > 0)
            at = entries[entries.length - 1].itemIndex + 1
        else
            at = out.length
        out.splice(at, 0, item)
        return out
    }

    function placed(items, itemIndex, side, position) {
        const moved = items[itemIndex]
        const rest = items.filter((_, i) => i !== itemIndex)
        return _insertAt(rest, { id: moved.id, side: side, visible: true }, side, position)
    }

    function hidden(items, itemIndex) {
        const target = items[itemIndex]
        const rest = items.filter((_, i) => i !== itemIndex)
        const out = rest.map(i => ({ id: i.id, side: i.side, visible: i.visible }))
        if (target.id === separatorId)
            return out
        let last = -1
        out.forEach((it, i) => { if (it.side === target.side) last = i })
        out.splice(last + 1, 0, { id: target.id, side: target.side, visible: false })
        return out
    }

    function withSeparator(items, side, position) {
        return _insertAt(items, { id: separatorId, side: side, visible: true }, side, position)
    }
}
