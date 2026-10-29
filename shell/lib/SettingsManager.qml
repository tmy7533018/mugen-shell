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
        return {
            "enabled": blurEnabled, "size": blurSize, "passes": blurPasses, "noise": blurNoise,
            "contrast": blurContrast, "brightness": blurBrightness, "vibrancy": blurVibrancy,
            "xray": blurXray, "ignoreOpacity": blurIgnoreOpacity
        }
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

        let modeled = {
            "autoCloseTimer": {
                "interval": autoCloseTimerInterval
            },
            "barBackground": {
                "enabled": moduleBackdropEnabled,
                "palette": moduleBackdropPalette,
                "spread": moduleBackdropSpread
            },
            "battery": {
                "showPercent": batteryShowPercent
            },
            "glass": {
                "opacityDark": glassOpacityDark,
                "opacityLight": glassOpacityLight
            },
            "blur": blurParams(),
            "animations": {
                "speed": animationSpeed,
                "durationMultiplier": animationDurationMultiplier,
                "reduceMotion": reduceMotion
            },
            "notification": {
                "sound": notificationSound,
                "enabled": notificationsEnabled,
                "suppressOnFullscreen": notificationSuppressOnFullscreen,
                "popupTimeout": notificationPopupTimeout
            },
            "launcher": {
                "terminal": launcherTerminal,
                "typeToSearch": launcherTypeToSearch
            },
            "timer": {
                "sound": timerSound
            },
            "volume": {
                "step": volumeStep
            },
            "wallpaper": {
                "pauseWhen": wallpaperPauseWhen,
                "pauseApps": wallpaperPauseApps,
                "speed": wallpaperSpeed,
                "sound": wallpaperSound,
                "volume": wallpaperVolume,
                "fit": wallpaperFit,
                "brightness": wallpaperBrightness,
                "saturation": wallpaperSaturation,
                "transition": wallpaperTransition,
                "transitionSeconds": wallpaperTransitionSeconds,
                "slideshow": wallpaperSlideshow,
                "slideshowMinutes": wallpaperSlideshowMinutes,
                "slideshowOrder": wallpaperSlideshowOrder
            },
            "lockTimer": {
                "minutes": lockTimerMinutes
            },
            "idle": {
                "suspendMinutes": idleSuspendMinutes,
                "dpmsMinutes": idleDpmsMinutes
            },
            "lockScreen": {
                "showEvents": lockShowEvents,
                "showLocation": lockShowLocation
            },
            "date": {
                "format": dateFormat
            },
            "clock": {
                "show24Hour": clockShow24Hour,
                "showSeconds": clockShowSeconds
            },
            "weather": {
                "enabled": weatherEnabled,
                "location": weatherLocation,
                "unit": weatherUnit
            },
            "calendar": {
                "weekStart": calendarWeekStart
            },
            "bar": {
                "height": barHeight,
                "radius": barRadius,
                "marginH": barMarginH,
                "marginV": barMarginV,
                "autoHide": barAutoHide,
                "surface": {
                    "custom": barSurfaceCustom,
                    "hue": barSurfaceHue,
                    "saturation": barSurfaceSaturation,
                    "lightness": barSurfaceLightness,
                    "opacity": barSurfaceOpacity,
                    "border": barSurfaceBorder
                }
            },
            "workspaces": {
                "count": workspaceCount
            },
            "display": {
                "monitor": displayMonitor
            },
            "ai": {
                "barModel": barAiModel,
                "barThinking": barThinking
            },
            "yura": {
                "enabled": yuraEnabled,
                "panelSide": yuraPanelSide,
                "panelWidth": yuraPanelWidth,
                "panelHeight": yuraPanelHeight,
                "sidebarCollapsed": yuraSidebarCollapsed,
                "idleBreath": yuraIdleBreath,
                "autoCollapseMin": yuraAutoCollapseMin,
                "typingSpeed": yuraTypingSpeed
            }
        }

        let merged = _deepMerge(_rawSettings, modeled)
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

    function applySettingsFromJson(jsonString) {
        try {
            let settings = JSON.parse(jsonString)

            _rawSettings = settings

            _applyingExternal = true

            try {
                if (settings.autoCloseTimer) {
                    if (settings.autoCloseTimer.interval !== undefined) {
                        autoCloseTimerInterval = settings.autoCloseTimer.interval
                    }
                    // Legacy key: enabled=false meant interval 0.
                    if (settings.autoCloseTimer.enabled === false) {
                        autoCloseTimerInterval = 0
                        delete settings.autoCloseTimer.enabled
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.autoCloseTimer:", e)
            }

            try {
                if (settings.glass) {
                    if (settings.glass.opacityDark !== undefined) glassOpacityDark = _unitOr(settings.glass.opacityDark, glassOpacityDark)
                    if (settings.glass.opacityLight !== undefined) glassOpacityLight = _unitOr(settings.glass.opacityLight, glassOpacityLight)
                }
            } catch (e) {
                console.error("Failed to apply settings.glass:", e)
            }

            try {
                if (settings.blur) {
                    const c = settings.blur
                    if (c.enabled !== undefined) blurEnabled = !!c.enabled
                    if (isFinite(c.size)) blurSize = Math.round(c.size)
                    if (isFinite(c.passes)) blurPasses = Math.round(c.passes)
                    if (isFinite(c.noise)) blurNoise = c.noise
                    if (isFinite(c.contrast)) blurContrast = c.contrast
                    if (isFinite(c.brightness)) blurBrightness = c.brightness
                    if (isFinite(c.vibrancy)) blurVibrancy = c.vibrancy
                    if (c.xray !== undefined) blurXray = !!c.xray
                    if (c.ignoreOpacity !== undefined) blurIgnoreOpacity = !!c.ignoreOpacity
                }
            } catch (e) {
                console.error("Failed to apply settings.blur:", e)
            }

            try {
                if (settings.barBackground) {
                    if (settings.barBackground.enabled !== undefined) {
                        moduleBackdropEnabled = settings.barBackground.enabled
                    } else if (settings.barBackground.gradientEnabled !== undefined) {
                        // Pre-839a636 key: same on/off, renamed when the flat gradient was dropped.
                        moduleBackdropEnabled = settings.barBackground.gradientEnabled
                    }
                    if (settings.barBackground.palette !== undefined) {
                        moduleBackdropPalette = settings.barBackground.palette
                    }
                    if (settings.barBackground.spread !== undefined) {
                        moduleBackdropSpread = settings.barBackground.spread
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.barBackground:", e)
            }

            try {
                if (settings.battery) {
                    if (settings.battery.showPercent !== undefined) {
                        batteryShowPercent = settings.battery.showPercent
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.battery:", e)
            }

            try {
                if (settings.animations) {
                    if (settings.animations.speed !== undefined) {
                        animationSpeed = settings.animations.speed
                    }
                    if (settings.animations.durationMultiplier !== undefined) {
                        animationDurationMultiplier = settings.animations.durationMultiplier
                    }
                    if (settings.animations.reduceMotion !== undefined) {
                        reduceMotion = settings.animations.reduceMotion
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.animations:", e)
            }

            try {
                if (settings.notification) {
                    if (settings.notification.sound !== undefined) {
                        notificationSound = settings.notification.sound
                    }
                    if (settings.notification.enabled !== undefined) {
                        notificationsEnabled = settings.notification.enabled
                    }
                    if (settings.notification.suppressOnFullscreen !== undefined) {
                        notificationSuppressOnFullscreen = settings.notification.suppressOnFullscreen
                    }
                    if (settings.notification.popupTimeout !== undefined) {
                        notificationPopupTimeout = settings.notification.popupTimeout
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.notification:", e)
            }

            try {
                if (settings.launcher) {
                    if (settings.launcher.terminal !== undefined) {
                        launcherTerminal = settings.launcher.terminal
                    }
                    if (settings.launcher.typeToSearch !== undefined) {
                        launcherTypeToSearch = settings.launcher.typeToSearch
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.launcher:", e)
            }

            try {
                if (settings.timer) {
                    if (settings.timer.sound !== undefined) {
                        timerSound = settings.timer.sound
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.timer:", e)
            }

            try {
                if (settings.volume && settings.volume.step !== undefined) {
                    volumeStep = _volumeStepOf(settings.volume.step)
                }
            } catch (e) {
                console.error("Failed to apply settings.volume:", e)
            }

            try {
                const wp = settings.wallpaper
                if (_isPlainObject(wp)) {
                    const R = WallpaperRules
                    if (wp.pauseWhen !== undefined)
                        wallpaperPauseWhen = R.enumOf(wp.pauseWhen, R.pauseWhenValues, "fullscreen")
                    if (wp.pauseApps !== undefined) {
                        const apps = R.pauseAppsOf(wp.pauseApps)
                        if (JSON.stringify(apps) !== JSON.stringify(wallpaperPauseApps))
                            wallpaperPauseApps = apps
                    }
                    if (wp.speed !== undefined)
                        wallpaperSpeed = R.speedOf(wp.speed)
                    if (wp.sound !== undefined)
                        wallpaperSound = R.boolOf(wp.sound, false)
                    if (wp.volume !== undefined)
                        wallpaperVolume = R.volumeOf(wp.volume)
                    if (wp.fit !== undefined)
                        wallpaperFit = R.enumOf(wp.fit, R.fitValues, "fill")
                    if (wp.brightness !== undefined)
                        wallpaperBrightness = R.brightnessOf(wp.brightness)
                    if (wp.saturation !== undefined)
                        wallpaperSaturation = R.saturationOf(wp.saturation)
                    if (wp.transition !== undefined)
                        wallpaperTransition = R.enumOf(wp.transition, R.transitionValues, "wave")
                    if (wp.transitionSeconds !== undefined)
                        wallpaperTransitionSeconds = R.transitionSecondsOf(wp.transitionSeconds)
                    if (wp.slideshow !== undefined)
                        wallpaperSlideshow = R.boolOf(wp.slideshow, false)
                    if (wp.slideshowMinutes !== undefined)
                        wallpaperSlideshowMinutes = R.slideshowMinutesOf(wp.slideshowMinutes)
                    if (wp.slideshowOrder !== undefined)
                        wallpaperSlideshowOrder = R.enumOf(wp.slideshowOrder, R.slideshowOrderValues, "shuffle")
                }
            } catch (e) {
                console.error("Failed to apply settings.wallpaper:", e)
            }

            try {
                if (settings.lockTimer) {
                    if (settings.lockTimer.minutes !== undefined) {
                        lockTimerMinutes = settings.lockTimer.minutes
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.lockTimer:", e)
            }

            try {
                if (settings.idle) {
                    if (settings.idle.suspendMinutes !== undefined) {
                        idleSuspendMinutes = settings.idle.suspendMinutes
                    }
                    if (settings.idle.dpmsMinutes !== undefined) {
                        idleDpmsMinutes = settings.idle.dpmsMinutes
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.idle:", e)
            }

            try {
                if (settings.lockScreen) {
                    if (settings.lockScreen.showEvents !== undefined) {
                        lockShowEvents = settings.lockScreen.showEvents
                    }
                    if (settings.lockScreen.showLocation !== undefined) {
                        lockShowLocation = settings.lockScreen.showLocation
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.lockScreen:", e)
            }

            try {
                if (settings.date) {
                    if (settings.date.format !== undefined) {
                        dateFormat = settings.date.format
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.date:", e)
            }

            try {
                if (settings.clock) {
                    if (settings.clock.show24Hour !== undefined) {
                        clockShow24Hour = settings.clock.show24Hour
                    }
                    if (settings.clock.showSeconds !== undefined) {
                        clockShowSeconds = settings.clock.showSeconds
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.clock:", e)
            }

            try {
                if (settings.weather) {
                    if (settings.weather.enabled !== undefined) {
                        weatherEnabled = settings.weather.enabled
                    }
                    if (settings.weather.location !== undefined) {
                        weatherLocation = settings.weather.location
                    }
                    if (settings.weather.unit !== undefined) {
                        weatherUnit = settings.weather.unit
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.weather:", e)
            }

            try {
                if (settings.calendar) {
                    if (settings.calendar.weekStart !== undefined) {
                        calendarWeekStart = settings.calendar.weekStart
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.calendar:", e)
            }

            try {
                if (settings.bar) {
                    if (settings.bar.height !== undefined) {
                        barHeight = settings.bar.height
                    }
                    if (settings.bar.radius !== undefined) {
                        barRadius = settings.bar.radius
                    }
                    if (settings.bar.marginH !== undefined) {
                        barMarginH = settings.bar.marginH
                    }
                    if (settings.bar.marginV !== undefined) {
                        barMarginV = settings.bar.marginV
                    }
                    if (settings.bar.autoHide !== undefined) {
                        barAutoHide = !!settings.bar.autoHide
                    }
                    if (settings.bar.surface) {
                        const sf = settings.bar.surface
                        if (sf.custom !== undefined) barSurfaceCustom = sf.custom
                        if (sf.hue !== undefined) barSurfaceHue = _unitOr(sf.hue, barSurfaceHue)
                        if (sf.saturation !== undefined) barSurfaceSaturation = _unitOr(sf.saturation, barSurfaceSaturation)
                        if (sf.lightness !== undefined) barSurfaceLightness = _unitOr(sf.lightness, barSurfaceLightness)
                        if (sf.opacity !== undefined) barSurfaceOpacity = _unitOr(sf.opacity, barSurfaceOpacity)
                        if (sf.border !== undefined) barSurfaceBorder = sf.border
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.bar:", e)
            }

            try {
                if (settings.workspaces) {
                    if (settings.workspaces.count !== undefined) {
                        workspaceCount = settings.workspaces.count
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.workspaces:", e)
            }

            try {
                if (settings.display) {
                    if (settings.display.monitor !== undefined) {
                        displayMonitor = settings.display.monitor
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.display:", e)
            }

            try {
                if (settings.ai) {
                    if (settings.ai.barModel !== undefined) {
                        barAiModel = settings.ai.barModel
                    }
                    if (settings.ai.barThinking !== undefined) {
                        barThinking = settings.ai.barThinking
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.ai:", e)
            }

            try {
                if (settings.yura) {
                    if (settings.yura.enabled !== undefined) {
                        yuraEnabled = settings.yura.enabled
                    }
                    if (settings.yura.panelSide !== undefined) {
                        yuraPanelSide = settings.yura.panelSide
                    }
                    if (settings.yura.panelWidth !== undefined) {
                        yuraPanelWidth = settings.yura.panelWidth
                    }
                    if (settings.yura.panelHeight !== undefined) {
                        yuraPanelHeight = settings.yura.panelHeight
                    }
                    if (settings.yura.sidebarCollapsed !== undefined) {
                        yuraSidebarCollapsed = settings.yura.sidebarCollapsed
                    }
                    if (settings.yura.idleBreath !== undefined) {
                        yuraIdleBreath = settings.yura.idleBreath
                    }
                    if (settings.yura.autoCollapseMin !== undefined) {
                        yuraAutoCollapseMin = settings.yura.autoCollapseMin
                    }
                    if (settings.yura.typingSpeed !== undefined) {
                        yuraTypingSpeed = settings.yura.typingSpeed
                    }
                }
            } catch (e) {
                console.error("Failed to apply settings.yura:", e)
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
