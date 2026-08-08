//@ pragma UseQApplication

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "./lib" as Theme
import "./components/lock" as Lock
import "./components/managers" as Managers

ShellRoot {
    id: root

    // ext-session-lock holds the lock even if this process dies.
    readonly property var pamServices: {
        const override = Quickshell.env("MUGEN_LOCK_PAM_SERVICE")
        return override && override !== ""
            ? [override]
            : ["mugen-lock", "hyprlock", "swaylock"]
    }
    property int pamService: 0

    property bool lockEngaged: false
    property bool refusedToLock: false
    property bool armed: false
    property bool authenticating: false
    property bool unlocking: false

    property bool lockWanted: false

    onLockWantedChanged: engageLock()

    function engageLock() {
        if (lockEngaged || !lockWanted) return
        lockEngaged = true
    }

    property string password: ""

    signal keystroke
    signal authFailed

    readonly property string readyFile:
        Theme.Paths.runtimeDir === ""
            ? "" : Theme.Paths.runtimeDir + "/mugen-shell/lock.secure"

    property bool barPresent: false
    property bool barRectValid: false
    property string barScreen: ""
    property real barX: 0
    property real barY: 0
    property real barW: 0
    property real barH: 0
    property real barRadiusPx: 0
    property real barOpacity: 0.85

    property real barExitX: 0
    property real barExitY: 0
    property real barExitW: 0
    property real barExitH: 0
    property real barExitRadius: 0

    // A fullscreen window hides the bar, so a missing morph source is routine.
    function largestScreenName() {
        let best = ""
        let bestArea = -1
        for (const screen of Quickshell.screens) {
            const area = screen.width * screen.height
            if (area <= bestArea) continue
            bestArea = area
            best = screen.name
        }
        return best
    }

    readonly property string uiScreen:
        barRectValid ? barScreen : largestScreenName()

    function tuningKnob(name, fallback) {
        const override = parseFloat(Quickshell.env(name))
        return isFinite(override) && override >= 0 && override <= 1
            ? override : fallback
    }

    readonly property real surfaceOpacity: tuningKnob("MUGEN_LOCK_OPACITY", 0.92)

    // Pre-scale, in the same margin units the bar itself uses.
    readonly property int faceMarginBase: {
        const override = parseInt(Quickshell.env("MUGEN_LOCK_MARGIN"), 10)
        return isFinite(override) && override >= 0 && override <= 200
            ? override : settingsManager.barMarginV
    }
    readonly property real dimStrength: tuningKnob("MUGEN_LOCK_DIM", 0.30)

    property bool rectHandled: false
    property bool hideSent: false
    property bool restoreSent: false
    property int surfacesReady: 0

    // Latched: a late reply must not rewrite geometry under a running animation.
    property bool entryStarted: false
    property bool entryMorph: false
    property string entryScreen: ""

    // Held so the unlock reads on the orb before the geometry moves.
    readonly property int unlockGrace: morphDuration === 0 ? 0 : 260

    readonly property int morphDuration:
        settingsManager.reduceMotion || settingsManager.animationDurationMultiplier === 0
            ? 0
            : Math.round(Theme.Motion.sweep * settingsManager.animationDurationMultiplier)

    property string timeText: ""
    property date today: new Date()

    property var calendarEvents: []
    property string calendarDay: ""

    // The lock can outlast midnight, so the grid reloads off the clock tick.
    function reloadCalendar() {
        const key = Qt.formatDate(today, "yyyy-MM-dd")
        if (key === calendarDay) return
        calendarDay = key

        const year = today.getFullYear()
        const month = today.getMonth()
        calendarProcess.command = [
            "python3", Quickshell.shellDir + "/scripts/calendar-cli.py", "list-range",
            "--start", Qt.formatDate(new Date(year, month - 1, 1), "yyyy-MM-dd"),
            "--end", Qt.formatDate(new Date(year, month + 2, 0), "yyyy-MM-dd")
        ]
        calendarProcess.running = true
    }

    readonly property string weatherHighLow: {
        const day = weatherManager.daily && weatherManager.daily.length > 0
            ? weatherManager.daily[0] : null
        if (!day) return ""
        return "H" + Math.round(day.tempMax) + "°  L" + Math.round(day.tempMin) + "°"
    }

    // An index in the power tile model, not a systemd verb.
    readonly property var powerCommands: [
        ["systemctl", "poweroff"],
        ["systemctl", "suspend"],
        ["systemctl", "reboot"],
        ["loginctl", "terminate-session", Quickshell.env("XDG_SESSION_ID") || ""]
    ]

    function runPowerAction(action) {
        if (action < 0 || action >= powerCommands.length) return
        Quickshell.execDetached(powerCommands[action])
    }

    function refreshClock() {
        const now = new Date()
        let hours = now.getHours()
        let suffix = ""
        if (!settingsManager.clockShow24Hour) {
            suffix = hours >= 12 ? " PM" : " AM"
            hours = hours % 12
            if (hours === 0) hours = 12
        }
        const hh = settingsManager.clockShow24Hour
            ? String(hours).padStart(2, "0") : String(hours)
        const mm = String(now.getMinutes()).padStart(2, "0")
        const ss = String(now.getSeconds()).padStart(2, "0")
        timeText = (settingsManager.clockShowSeconds
            ? hh + ":" + mm + ":" + ss : hh + ":" + mm) + suffix
        today = now
        reloadCalendar()
    }

    function scheduleClockTick() {
        const period = settingsManager.clockShowSeconds ? 1000 : 60000
        clockTimer.interval = Math.max(50, period - (Date.now() % period))
        clockTimer.restart()
    }

    function typeCharacter(text) {
        if (unlocking || authenticating || !armed) return
        password += text
        keystroke()
    }

    function eraseCharacter() {
        if (unlocking || authenticating || password === "") return
        password = password.slice(0, -1)
    }

    function clearPassword() {
        if (unlocking || authenticating) return
        password = ""
    }

    function submit() {
        if (unlocking || authenticating || !armed || password === "") return
        authenticating = true
        pam.respond(password)
        password = ""
    }

    function startPam() {
        pam.config = pamServices[pamService]
        if (!pam.start()) nextPamService()
    }

    function nextPamService() {
        if (pamService + 1 < pamServices.length) {
            pamService += 1
            startPam()
            return
        }
        if (lockEngaged) {
            pamService = 0
            pamRetryTimer.restart()
            console.warn("lock: no usable PAM service, retrying")
            return
        }
        refusedToLock = true
        setLockBlur(false)
        restoreDesktopBlur()
        console.warn("lock: no usable PAM service among " + pamServices.join(", ")
            + " - refusing to lock")
        Quickshell.execDetached([
            "notify-send", "-u", "critical", "mugen-shell",
            "Lock screen has no usable PAM service; the session was not locked."
        ])
        // Qt.exit() is a no-op here; the arm deadline would then lock for good.
        Qt.quit()
    }

    function applyBarRect(text) {
        if (rectHandled) return
        rectHandled = true
        rectKillTimer.stop()

        const tokens = String(text).trim().split(/\s+/)
        if (tokens[0] !== "v2") {
            maybeSendHide()
            return
        }
        barPresent = true

        if (tokens.length !== 17) {
            maybeSendHide()
            return
        }

        const nums = [2, 3, 4, 5, 6, 7, 12, 13, 14, 15, 16].map(i => parseFloat(tokens[i]))
        if (nums.some(n => !isFinite(n)) || nums[2] <= 0 || nums[3] <= 0
            || nums[8] <= 0 || nums[9] <= 0) {
            maybeSendHide()
            return
        }

        if (!entryStarted) {
            barScreen = tokens[1]
            barX = nums[0]
            barY = nums[1]
            barW = nums[2]
            barH = nums[3]
            barRadiusPx = nums[4]
            barOpacity = nums[5]
            barExitX = nums[6]
            barExitY = nums[7]
            barExitW = nums[8]
            barExitH = nums[9]
            barExitRadius = nums[10]
            colors.themeMode = tokens[9] === "light" ? "light" : "dark"
            barRectValid = true
        }
        maybeSendHide()
    }

    function maybeSendHide() {
        if (hideSent || !barPresent || surfacesReady < 1) return
        hideSent = true
        barHideProcess.command = ["qs", "-c", "mugen-shell", "ipc", "call",
                                  "bar", "hide", String(Quickshell.processId)]
        barHideProcess.running = true
        hideDeadline.restart()
    }

    function sendBarRestore() {
        if (!hideSent || restoreSent) return
        restoreSent = true
        Quickshell.execDetached(["qs", "-c", "mugen-shell", "ipc", "call",
                                 "bar", "restore"])
    }

    // Raised before the surface exists: the step lands where windows vanish.
    function setLockBlur(on) {
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.config({ misc = { session_lock_blur = "
                + (on ? "true" : "false") + " } })"])
    }

    // mugen-lock.sh softened the global radius and handed back the values.
    function restoreDesktopBlur() {
        const parts = String(Quickshell.env("MUGEN_LOCK_BLUR_RESTORE"))
            .trim().split(/\s+/)
        if (parts.length !== 2 || !/^\d+$/.test(parts[0]) || !/^\d+$/.test(parts[1]))
            return
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.config({ decoration = { blur = { size = " + parts[0]
                + ", passes = " + parts[1] + " } } })"])
    }

    function beginEntry() {
        if (entryStarted) return
        // Both descriptors before the flag the surfaces watch.
        entryMorph = barRectValid
        entryScreen = barRectValid ? barScreen : ""
        entryStarted = true
    }

    function releaseBlur() {
        setLockBlur(false)
        restoreDesktopBlur()
    }

    function beginUnlock() {
        unlocking = true
        // Dropped with the fold, or the step shows with nothing to carry it.
        if (unlockGrace > 0) blurReleaseTimer.start()
        else releaseBlur()
        barRestoreTimer.start()
        unlockTimer.start()
    }

    Theme.SettingsManager { id: settingsManager }
    Theme.Typography { id: typography }
    Theme.Colors { id: colors }

    // Colors resolves the mode via a subprocess; the face would open dark.
    FileView {
        id: themeModeSeed
        path: colors.themeModeFile
        blockLoading: true
        printErrors: false
    }

    function seedThemeMode() {
        const mode = String(themeModeSeed.text()).trim()
        if (mode === "light" || mode === "dark") colors.themeMode = mode
    }

    Timer {
        id: blurReleaseTimer
        interval: root.unlockGrace
        onTriggered: root.releaseBlur()
    }

    Timer {
        id: unlockTimer
        interval: root.unlockGrace + root.morphDuration + 40
        onTriggered: {
            root.lockEngaged = false
            quitTimer.start()
        }
    }

    Process {
        id: barRectProcess
        command: ["qs", "-c", "mugen-shell", "ipc", "call", "bar", "rect"]

        stdout: StdioCollector {
            onStreamFinished: root.applyBarRect(this.text)
        }
    }

    Timer {
        id: rectKillTimer
        interval: 1500
        running: true
        onTriggered: {
            if (barRectProcess.running) barRectProcess.signal(15)
            root.applyBarRect("")
        }
    }

    Process {
        id: calendarProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text || "{}")
                    root.calendarEvents = Array.isArray(parsed.events) ? parsed.events : []
                } catch (e) {
                    root.calendarEvents = []
                }
            }
        }
    }

    Process {
        id: barHideProcess
        stdout: StdioCollector { onStreamFinished: root.beginEntry() }
    }

    Timer {
        id: hideDeadline
        interval: 250
        onTriggered: root.beginEntry()
    }

    Timer {
        id: entryGrace
        interval: 350
        running: root.surfacesReady > 0 && !root.entryStarted
        onTriggered: root.beginEntry()
    }

    readonly property int barFadeInMs:
        settingsManager.animationDurationMultiplier === 0
            ? 0
            : Math.round(Theme.Motion.standard * settingsManager.animationDurationMultiplier)

    Timer {
        id: barRestoreTimer
        // Not earlier: a bar under a still-larger face reads as two.
        interval: root.unlockGrace
            + Math.max(0, root.morphDuration - root.barFadeInMs)
        onTriggered: root.sendBarRestore()
    }

    Managers.WeatherManager {
        id: weatherManager
        enabled: settingsManager.weatherEnabled
        locationOverride: settingsManager.weatherLocation
        unit: settingsManager.weatherUnit
    }

    Managers.MusicPlayerManager { id: musicPlayerManager }
    Managers.CavaManager {
        id: cava

        // It spawns nothing until asked; the visualiser sits at its floor.
        Component.onCompleted: isActive = true
    }
    Theme.IconProvider { id: icons }

    PamContext {
        id: pam

        onResponseRequiredChanged: {
            if (!responseRequired) return
            root.armed = true
            root.lockWanted = true
        }

        onCompleted: result => {
            root.authenticating = false
            root.password = ""

            if (result === PamResult.Success) {
                root.beginUnlock()
                return
            }

            root.armed = false
            root.authFailed()
            root.startPam()
        }

        onError: error => {
            root.authenticating = false
            if (error === PamError.StartFailed) {
                root.nextPamService()
                return
            }
            console.warn("lock: PAM error - " + PamError.toString(error))
            root.startPam()
        }
    }

    Timer {
        id: pamRetryTimer
        interval: 2000
        onTriggered: root.startPam()
    }

    Timer {
        id: armDeadline
        interval: 3000
        running: true
        onTriggered: {
            if (root.lockEngaged || root.unlocking || root.refusedToLock) return
            console.warn("lock: PAM did not prompt within "
                + interval + "ms - locking anyway")
            root.lockWanted = true
        }
    }

    Timer {
        id: clockTimer
        onTriggered: {
            root.refreshClock()
            root.scheduleClockTick()
        }
    }

    Timer {
        id: quitTimer
        interval: 300
        onTriggered: Qt.quit()
    }

    Process { id: readyStamp }

    WlSessionLock {
        id: sessionLock
        locked: root.lockEngaged

        onSecureStateChanged: {
            if (root.readyFile === "") return
            readyStamp.command = secure
                ? ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && : > \"$1\"",
                   "sh", root.readyFile]
                : ["rm", "-f", root.readyFile]
            readyStamp.running = true
        }

        WlSessionLockSurface {
            id: lockWindow
            color: "transparent"

            Lock.LockSurface {
                id: lockSurface
                anchors.fill: parent

                typo: typography
                themeRef: colors

                screenName: lockWindow.screen ? lockWindow.screen.name : ""
                uiVisible: screenName !== "" && screenName === root.uiScreen
                entryStarted: root.entryStarted
                entryMorph: root.entryMorph
                entryScreen: root.entryScreen
                morphDuration: root.morphDuration

                sourceX: root.barX
                sourceY: root.barY
                sourceWidth: root.barW
                sourceHeight: root.barH
                sourceRadius: root.barRadiusPx
                sourceOpacity: root.barOpacity

                exitX: root.barExitX
                exitY: root.barExitY
                exitWidth: root.barExitW
                exitHeight: root.barExitH
                exitRadius: root.barExitRadius

                marginBase: root.faceMarginBase
                radiusBase: settingsManager.barRadius
                faceOpacity: root.surfaceOpacity
                dimStrength: root.dimStrength

                timeText: root.timeText
                today: root.today
                calendarWeekStart: settingsManager.calendarWeekStart
                calendarEvents: root.calendarEvents

                passwordLength: root.password.length
                authenticating: root.authenticating
                unlocking: root.unlocking
                unlockGrace: root.unlockGrace
                reduceMotion: settingsManager.reduceMotion

                iconsBase: Quickshell.shellDir + "/assets/icons"
                texturesBase: Quickshell.shellDir + "/assets/textures"
                cavaManager: cava

                weatherPalette: weatherManager.ready
                    ? icons.weatherPalette(icons.weatherType(
                        weatherManager.weatherCode, weatherManager.isDay))
                    : null
                weatherIconSource: weatherManager.ready
                    ? icons.weatherIcon(weatherManager.weatherCode, weatherManager.isDay)
                    : ""
                weatherText: weatherManager.ready
                    ? Math.round(weatherManager.temperature) + "°" : ""
                weatherHighLow: root.weatherHighLow
                weatherCondition: weatherManager.ready
                    ? icons.weatherText(weatherManager.weatherCode)
                        + " · " + weatherManager.locationName
                    : ""
                weatherParticleType: weatherManager.ready
                    ? icons.weatherType(weatherManager.weatherCode, weatherManager.isDay)
                    : "clouds"
                weatherWind: weatherManager.wind

                mediaIsPlaying: musicPlayerManager.isPlaying
                mediaTitle: musicPlayerManager.title
                mediaArtist: musicPlayerManager.artist
                mediaArtUrl: musicPlayerManager.artUrl
                mediaPosition: musicPlayerManager.position
                mediaDuration: musicPlayerManager.duration
                mediaAccent: musicPlayerManager.accentColor

                onPreviousRequested: musicPlayerManager.previous()
                onPlayPauseRequested: musicPlayerManager.playPause()
                onNextRequested: musicPlayerManager.next()
                onPowerActionRequested: action => root.runPowerAction(action)

                Component.onCompleted: {
                    if (root.entryStarted) lockSurface.skipEntry()
                    root.surfacesReady += 1
                    root.maybeSendHide()
                }
                Component.onDestruction: root.surfacesReady -= 1

                Connections {
                    target: root
                    function onKeystroke() { lockSurface.bumpOrb() }
                    function onAuthFailed() { lockSurface.shakeOrb() }
                }
            }

            Item {
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    event.accepted = true
                    switch (event.key) {
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.submit()
                        return
                    case Qt.Key_Backspace:
                        if (event.modifiers & Qt.ControlModifier) root.clearPassword()
                        else root.eraseCharacter()
                        return
                    case Qt.Key_Escape:
                        root.clearPassword()
                        return
                    }
                    if (event.modifiers & Qt.ControlModifier) {
                        if (event.key === Qt.Key_U || event.key === Qt.Key_W)
                            root.clearPassword()
                        return
                    }
                    if (event.text.length > 0 && event.text.charCodeAt(0) >= 0x20
                        && event.text.charCodeAt(0) !== 0x7f)
                        root.typeCharacter(event.text)
                }

                Component.onCompleted: forceActiveFocus()
            }
        }
    }

    Component.onCompleted: {
        seedThemeMode()
        setLockBlur(true)
        refreshClock()
        scheduleClockTick()
        barRectProcess.running = true
        startPam()
    }
}
