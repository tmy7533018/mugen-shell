import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: settingsManager

    readonly property string configDir: {
        let xdg = Quickshell.env("XDG_CONFIG_HOME")
        if (!xdg || xdg === "") xdg = Quickshell.env("HOME") + "/.config"
        return xdg + "/mugen-shell"
    }

    // Read-only template shipped with the project; never written to.
    property string defaultSettingsFile: Quickshell.shellDir + "/settings.default.json"
    property string userSettingsFile: configDir + "/settings.json"

    // 0 = disabled, otherwise the idle timeout (ms) before a mode auto-closes.
    property int autoCloseTimerInterval: 5000
    property bool moduleBackdropEnabled: true
    property string moduleBackdropPalette: "harmony"
    property real moduleBackdropSpread: 0.06
    property bool batteryShowPercent: false
    property string animationSpeed: "normal"  // "slow" | "normal" | "fast" | "instant"
    property real animationDurationMultiplier: 1.0
    property string notificationSound: "None"  // filename in Paths.soundsDir, or "None"
    property bool notificationsEnabled: true  // DnD = !notificationsEnabled
    property int notificationPopupTimeout: 5000  // ms, 0 = never auto-close
    property bool notificationSuppressOnFullscreen: false
    property string launcherTerminal: "kitty"  // command used to launch Terminal=true apps
    property bool launcherTypeToSearch: true
    property string timerSound: "None"  // filename in Paths.timerSoundsDir, or "None"
    property int volumeStep: 2
    property string wallpaperPauseWhen: "fullscreen"
    property var wallpaperPauseApps: []
    property real wallpaperSpeed: 1
    property bool wallpaperSound: false
    property int wallpaperVolume: 50
    property string wallpaperFit: "fill"
    property int wallpaperBrightness: 0
    property int wallpaperSaturation: 0
    property string wallpaperTransition: "wave"
    property real wallpaperTransitionSeconds: 1.3
    property bool wallpaperSlideshow: false
    property int wallpaperSlideshowMinutes: 15
    property string wallpaperSlideshowOrder: "shuffle"
    property int lockTimerMinutes: 10  // hypridle screen-lock idle timeout
    property int idleSuspendMinutes: 30  // hypridle suspend timeout, 0 = disabled
    property int idleDpmsMinutes: 0  // hypridle screen-off timeout, 0 = disabled
    property bool lockShowEvents: true
    property bool lockShowLocation: true
    property string dateFormat: "ddd M/d"  // Qt date tokens
    property bool clockShow24Hour: true
    property bool clockShowSeconds: false
    property bool weatherEnabled: true
    property string weatherLocation: ""
    property string weatherUnit: "celsius"
    property int calendarWeekStart: 0  // 0 = Sunday, 1 = Monday
    property bool reduceMotion: false  // silences looping ambient animation, separate from animationSpeed
    property int barHeight: 60
    property int barRadius: 50
    property int barMarginH: 10
    property int barMarginV: 6
    property bool barAutoHide: false

    // Defaults are the exact HSL of MugenSurface's dark base, so enabling custom changes nothing.
    property bool barSurfaceCustom: false
    property real barSurfaceHue: 0.611111
    property real barSurfaceSaturation: 0.130435
    property real barSurfaceLightness: 0.090196
    property real barSurfaceOpacity: 0.82
    property bool barSurfaceBorder: true
    property real glassOpacityDark: 0.82
    property real glassOpacityLight: 0.65

    property bool blurEnabled: true
    property int blurSize: 5
    property int blurPasses: 3
    property real blurNoise: 0.02
    property real blurContrast: 1.0
    property real blurBrightness: 1.2
    property real blurVibrancy: 0.0
    property bool blurXray: false
    property bool blurIgnoreOpacity: true

    function blurParams() {
        return _modeledOf(_domain("blur").rows)
    }

    function resetBlur() {
        blurEnabled = true
        blurSize = 5
        blurPasses = 3
        blurNoise = 0.02
        blurContrast = 1.0
        blurBrightness = 1.2
        blurVibrancy = 0.0
        blurXray = false
        blurIgnoreOpacity = true
    }

    property int workspaceCount: 5
    property string displayMonitor: ""  // Quickshell screen name; "" = first screen

    // Reassigning a live PanelWindow.screen crashes Quickshell, so windows bind this latched copy.
    property string initialDisplayMonitor: ""
    property bool _displayMonitorLatched: false
    property string barAiModel: ""  // "" = follow the backend default
    property bool barThinking: false
    property bool yuraEnabled: true
    property string yuraPanelSide: "left"  // "left" | "right"
    property int yuraPanelWidth: 700
    property int yuraPanelHeight: 640
    property bool yuraSidebarCollapsed: false
    property bool yuraIdleBreath: true
    property int yuraAutoCollapseMin: 0  // 0 = never
    property string yuraTypingSpeed: "instant"  // "instant" | "fast" | "normal" | "slow"

    // Suppress save while applying values that just came in from disk.
    property bool _applyingExternal: false

    // saveSettings merges over this, so keys this build doesn't model survive our save.
    property var _rawSettings: ({})

    // A replace-semantics save against an empty _rawSettings would wipe the file, so gate it on the load.
    property bool _settingsLoaded: false

    signal settingsChanged()

    Component.onCompleted: {
        Motion.settings = settingsManager
        loadSettings()
    }

    function loadSettings() {
        readSettingsProcess.command = ["bash", "-c",
            'if [ -e "$1" ]; then exec cat "$1"; fi; exit 42', "bash", userSettingsFile]
        readSettingsProcess.running = true
    }

    function _isPlainObject(v) {
        return v !== null && typeof v === "object" && !Array.isArray(v)
    }

    function _deepMerge(base, override) {
        let out = _isPlainObject(base) ? JSON.parse(JSON.stringify(base)) : {}
        for (let k in override) {
            if (!override.hasOwnProperty(k)) continue
            if (_isPlainObject(override[k]) && _isPlainObject(out[k])) {
                out[k] = _deepMerge(out[k], override[k])
            } else if (_isPlainObject(override[k])) {
                out[k] = JSON.parse(JSON.stringify(override[k]))
            } else {
                out[k] = override[k]
            }
        }
        return out
    }

    function saveSettings() {
        if (_applyingExternal) return
        if (!_settingsLoaded) return

        let merged = _deepMerge(_rawSettings, _modeled())
        _rawSettings = merged
        let jsonString = JSON.stringify(merged, null, 2)

        saveSettingsProcess.command =
            JsonStore.atomicWriteArgv(configDir, userSettingsFile, jsonString)
        saveSettingsProcess.running = true
    }

    function resetToDefault() {
        // Same atomic tmp + rename as saveSettings — cp truncates in place.
        resetProcess.command = [
            "bash", "-c",
            "umask 077 && mkdir -p \"$1\" && tmp=\"$3.$$.tmp\" && cp \"$2\" \"$tmp\" && mv \"$tmp\" \"$3\"",
            "bash", configDir, defaultSettingsFile, userSettingsFile
        ]
        resetProcess.running = true
    }

    // An unassignable value throws and abandons the rest of its section, so hand-edited colours fall back instead.
    function _unitOr(v, fallback) {
        const n = Number(v)
        return isFinite(n) ? Math.max(0, Math.min(1, n)) : fallback
    }

    // volume-key.sh applies the same clamp and fallback, so the keys and the panel agree on a hand-edited value.
    function _volumeStepOf(v) {
        return (typeof v === "number" && isFinite(v)) ? Math.max(1, Math.min(10, Math.round(v))) : 2
    }

    // A domain missing from the file is appended in this order; the rest follow in apply order.
    readonly property var _saveOrderHead: ["autoCloseTimer", "barBackground", "battery", "glass", "blur"]

    // Domains in apply order, rows in assignment order: listeners see the changes in exactly this sequence.
    readonly property var _schema: [
        { key: "autoCloseTimer", after: o => settingsManager._applyLegacyAutoClose(o), rows: [
            { prop: "autoCloseTimerInterval", key: "interval" }] },
        { key: "glass", rows: [
            { prop: "glassOpacityDark", key: "opacityDark", read: (v, cur) => settingsManager._unitOr(v, cur) },
            { prop: "glassOpacityLight", key: "opacityLight", read: (v, cur) => settingsManager._unitOr(v, cur) }] },
        { key: "blur", rows: [
            { prop: "blurEnabled", key: "enabled", read: v => !!v },
            { prop: "blurSize", key: "size", finite: true, read: v => Math.round(v) },
            { prop: "blurPasses", key: "passes", finite: true, read: v => Math.round(v) },
            { prop: "blurNoise", key: "noise", finite: true },
            { prop: "blurContrast", key: "contrast", finite: true },
            { prop: "blurBrightness", key: "brightness", finite: true },
            { prop: "blurVibrancy", key: "vibrancy", finite: true },
            { prop: "blurXray", key: "xray", read: v => !!v },
            { prop: "blurIgnoreOpacity", key: "ignoreOpacity", read: v => !!v }] },
        { key: "barBackground", rows: [
            // Pre-839a636 key: same on/off, renamed when the flat gradient was dropped.
            { prop: "moduleBackdropEnabled", key: "enabled", legacyKey: "gradientEnabled" },
            { prop: "moduleBackdropPalette", key: "palette" },
            { prop: "moduleBackdropSpread", key: "spread" }] },
        { key: "battery", rows: [
            { prop: "batteryShowPercent", key: "showPercent" }] },
        { key: "animations", rows: [
            { prop: "animationSpeed", key: "speed" },
            { prop: "animationDurationMultiplier", key: "durationMultiplier" },
            { prop: "reduceMotion", key: "reduceMotion" }] },
        { key: "notification", rows: [
            { prop: "notificationSound", key: "sound" },
            { prop: "notificationsEnabled", key: "enabled" },
            { prop: "notificationSuppressOnFullscreen", key: "suppressOnFullscreen" },
            { prop: "notificationPopupTimeout", key: "popupTimeout" }] },
        { key: "launcher", rows: [
            { prop: "launcherTerminal", key: "terminal" },
            { prop: "launcherTypeToSearch", key: "typeToSearch" }] },
        { key: "timer", rows: [
            { prop: "timerSound", key: "sound" }] },
        { key: "volume", rows: [
            { prop: "volumeStep", key: "step", read: v => settingsManager._volumeStepOf(v) }] },
        { key: "wallpaper", plainObject: true, rows: [
            { prop: "wallpaperPauseWhen", key: "pauseWhen", read: v => WallpaperRules.enumOf(v, WallpaperRules.pauseWhenValues, "fullscreen") },
            { prop: "wallpaperPauseApps", key: "pauseApps", read: v => WallpaperRules.pauseAppsOf(v) },
            { prop: "wallpaperSpeed", key: "speed", read: v => WallpaperRules.speedOf(v) },
            { prop: "wallpaperSound", key: "sound", read: v => WallpaperRules.boolOf(v, false) },
            { prop: "wallpaperVolume", key: "volume", read: v => WallpaperRules.volumeOf(v) },
            { prop: "wallpaperFit", key: "fit", read: v => WallpaperRules.enumOf(v, WallpaperRules.fitValues, "fill") },
            { prop: "wallpaperBrightness", key: "brightness", read: v => WallpaperRules.brightnessOf(v) },
            { prop: "wallpaperSaturation", key: "saturation", read: v => WallpaperRules.saturationOf(v) },
            { prop: "wallpaperTransition", key: "transition", read: v => WallpaperRules.enumOf(v, WallpaperRules.transitionValues, "wave") },
            { prop: "wallpaperTransitionSeconds", key: "transitionSeconds", read: v => WallpaperRules.transitionSecondsOf(v) },
            { prop: "wallpaperSlideshow", key: "slideshow", read: v => WallpaperRules.boolOf(v, false) },
            { prop: "wallpaperSlideshowMinutes", key: "slideshowMinutes", read: v => WallpaperRules.slideshowMinutesOf(v) },
            { prop: "wallpaperSlideshowOrder", key: "slideshowOrder", read: v => WallpaperRules.enumOf(v, WallpaperRules.slideshowOrderValues, "shuffle") }] },
        { key: "lockTimer", rows: [
            { prop: "lockTimerMinutes", key: "minutes" }] },
        { key: "idle", rows: [
            { prop: "idleSuspendMinutes", key: "suspendMinutes" },
            { prop: "idleDpmsMinutes", key: "dpmsMinutes" }] },
        { key: "lockScreen", rows: [
            { prop: "lockShowEvents", key: "showEvents" },
            { prop: "lockShowLocation", key: "showLocation" }] },
        { key: "date", rows: [
            { prop: "dateFormat", key: "format" }] },
        { key: "clock", rows: [
            { prop: "clockShow24Hour", key: "show24Hour" },
            { prop: "clockShowSeconds", key: "showSeconds" }] },
        { key: "weather", rows: [
            { prop: "weatherEnabled", key: "enabled" },
            { prop: "weatherLocation", key: "location" },
            { prop: "weatherUnit", key: "unit" }] },
        { key: "calendar", rows: [
            { prop: "calendarWeekStart", key: "weekStart" }] },
        { key: "bar", rows: [
            { prop: "barHeight", key: "height" },
            { prop: "barRadius", key: "radius" },
            { prop: "barMarginH", key: "marginH" },
            { prop: "barMarginV", key: "marginV" },
            { prop: "barAutoHide", key: "autoHide", read: v => !!v },
            { key: "surface", rows: [
                { prop: "barSurfaceCustom", key: "custom" },
                { prop: "barSurfaceHue", key: "hue", read: (v, cur) => settingsManager._unitOr(v, cur) },
                { prop: "barSurfaceSaturation", key: "saturation", read: (v, cur) => settingsManager._unitOr(v, cur) },
                { prop: "barSurfaceLightness", key: "lightness", read: (v, cur) => settingsManager._unitOr(v, cur) },
                { prop: "barSurfaceOpacity", key: "opacity", read: (v, cur) => settingsManager._unitOr(v, cur) },
                { prop: "barSurfaceBorder", key: "border" }] }] },
        { key: "workspaces", rows: [
            { prop: "workspaceCount", key: "count" }] },
        { key: "display", rows: [
            { prop: "displayMonitor", key: "monitor" }] },
        { key: "ai", rows: [
            { prop: "barAiModel", key: "barModel" },
            { prop: "barThinking", key: "barThinking" }] },
        { key: "yura", rows: [
            { prop: "yuraEnabled", key: "enabled" },
            { prop: "yuraPanelSide", key: "panelSide" },
            { prop: "yuraPanelWidth", key: "panelWidth" },
            { prop: "yuraPanelHeight", key: "panelHeight" },
            { prop: "yuraSidebarCollapsed", key: "sidebarCollapsed" },
            { prop: "yuraIdleBreath", key: "idleBreath" },
            { prop: "yuraAutoCollapseMin", key: "autoCollapseMin" },
            { prop: "yuraTypingSpeed", key: "typingSpeed" }] }
    ]

    function _domain(key) {
        return _schema.find(d => d.key === key)
    }

    function _modeledOf(rows) {
        let out = {}
        for (const r of rows)
            out[r.key] = r.rows ? _modeledOf(r.rows) : settingsManager[r.prop]
        return out
    }

    function _modeled() {
        let out = {}
        for (const key of _saveOrderHead)
            out[key] = _modeledOf(_domain(key).rows)
        for (const d of _schema) {
            if (_saveOrderHead.indexOf(d.key) < 0)
                out[d.key] = _modeledOf(d.rows)
        }
        return out
    }

    // Legacy key: enabled=false meant interval 0.
    function _applyLegacyAutoClose(o) {
        if (o.enabled === false) {
            autoCloseTimerInterval = 0
            delete o.enabled
        }
    }

    function _applyRows(obj, rows) {
        for (const r of rows) {
            if (r.rows) {
                if (obj[r.key]) _applyRows(obj[r.key], r.rows)
                continue
            }
            let v = obj[r.key]
            if (v === undefined && r.legacyKey) v = obj[r.legacyKey]
            if (r.finite ? !isFinite(v) : v === undefined) continue
            const current = settingsManager[r.prop]
            const next = r.read ? r.read(v, current) : v
            // A var property emits on every new array, even an equal one, and every save reloads every process.
            if (typeof current === "object" && current !== null && JSON.stringify(next) === JSON.stringify(current)) continue
            settingsManager[r.prop] = next
        }
    }

    function applySettingsFromJson(jsonString) {
        try {
            let settings = JSON.parse(jsonString)

            _rawSettings = settings

            _applyingExternal = true

            for (const d of _schema) {
                try {
                    const obj = settings[d.key]
                    if (d.plainObject ? _isPlainObject(obj) : obj) {
                        _applyRows(obj, d.rows)
                        if (d.after) d.after(obj)
                    }
                } catch (e) {
                    console.error("Failed to apply settings." + d.key + ":", e)
                }
            }

            updateAnimationMultiplier()

            _settingsLoaded = true

            if (!_displayMonitorLatched) {
                initialDisplayMonitor = displayMonitor
                _displayMonitorLatched = true
            }

            _applyingExternal = false

            settingsChanged()
        } catch (e) {
            _applyingExternal = false
            // Unparseable on disk: nothing to preserve, so let saves through and overwrite it.
            _settingsLoaded = true
            console.error("Failed to parse settings JSON:", e)
            // Listeners seed from the first emit, and the defaults are what is in effect now.
            settingsChanged()
        }
    }

    function updateAnimationMultiplier() {
        switch (animationSpeed) {
            case "slow":
                animationDurationMultiplier = 1.5
                break
            case "normal":
                animationDurationMultiplier = 1.0
                break
            case "fast":
                animationDurationMultiplier = 0.6
                break
            case "instant":
                animationDurationMultiplier = 0.0
                break
            default:
                animationDurationMultiplier = 1.0
        }
    }

    // Re-read on external writes so every shell process stays in sync.
    property FileView settingsWatcher: FileView {
        path: settingsManager.userSettingsFile
        watchChanges: true
        preload: false
        printErrors: false

        onFileChanged: {
            settingsManager.loadSettings()
        }
    }

    property Process readSettingsProcess: Process {
        command: []
        running: false
        property string output: ""

        stdout: SplitParser {
            onRead: data => {
                readSettingsProcess.output += data
            }
        }

        onExited: (exitCode) => {
            if (exitCode === 0 && readSettingsProcess.output.trim().length > 0) {
                settingsManager._loadRetries = 0
                applySettingsFromJson(readSettingsProcess.output)
            } else if (exitCode === 42) {
                // Only the probe's own code means absent; any other failure may be transient.
                readDefaultSettingsProcess.seed = true
                readDefaultSettingsProcess.running = true
            } else if (settingsManager._loadRetries < 3) {
                // An empty read raced a writer and a non-42 failure may be transient; either way, retry.
                settingsManager._loadRetries++
                retryLoadTimer.restart()
            } else {
                settingsManager._loadRetries = 0
                readDefaultSettingsProcess.seed = false
                readDefaultSettingsProcess.running = true
            }
            readSettingsProcess.output = ""
        }
    }

    property int _loadRetries: 0

    property Timer retryLoadTimer: Timer {
        interval: 250
        onTriggered: settingsManager.loadSettings()
    }

    property Process readDefaultSettingsProcess: Process {
        command: ["cat", settingsManager.defaultSettingsFile]
        running: false
        property string output: ""
        // Only a genuinely missing file may have defaults written back to it.
        property bool seed: true

        stdout: SplitParser {
            onRead: data => {
                readDefaultSettingsProcess.output += data
            }
        }

        onExited: (exitCode) => {
            if (exitCode === 0 && readDefaultSettingsProcess.output.trim().length > 0) {
                applySettingsFromJson(readDefaultSettingsProcess.output)
                if (readDefaultSettingsProcess.seed) saveSettings()
            }
            readDefaultSettingsProcess.output = ""
        }
    }

    property Process saveSettingsProcess: Process {
        id: saveProc
        command: []
        running: false
        property string errors: ""
        onRunningChanged: if (running) errors = ""

        stdout: SplitParser {
            onRead: data => {}
        }

        stderr: SplitParser {
            onRead: data => saveProc.errors += data + "\n"
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                settingsChanged()
            } else {
                console.warn("SettingsManager: saving", settingsManager.userSettingsFile, "failed (exit " + exitCode + "):", errors.trim())
            }
        }
    }

    property Process resetProcess: Process {
        command: []
        running: false

        stdout: SplitParser {
            onRead: data => {}
        }

        stderr: SplitParser {
            onRead: data => {}
        }

        onExited: (exitCode) => {
            if (exitCode === 0) {
                loadSettings()
            }
        }
    }
}
