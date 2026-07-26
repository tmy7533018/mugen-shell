import QtQuick
import Quickshell.Io

QtObject {
    id: weatherManager

    property bool enabled: true
    property string locationOverride: ""
    property string unit: "celsius"

    property real latitude: 0
    property real longitude: 0
    property string locationName: ""
    property bool locationResolved: false

    property bool ready: false
    property real temperature: 0
    property real feelsLike: 0
    property int humidity: 0
    property real wind: 0
    property int weatherCode: -1
    property bool isDay: true
    property string errorText: ""

    property var hourly: []
    property var daily: []

    onEnabledChanged: {
        if (enabled) resolveLocation()
        else cancelRetry()
    }

    // A changed override forces a fresh location resolve; clearing it falls
    // back to IP geolocation.
    onLocationOverrideChanged: {
        locationResolved = false
        cancelRetry()
        if (enabled) resolveLocation()
    }

    onUnitChanged: {
        if (locationResolved) fetchForecast()
    }

    function refresh() {
        if (!enabled) return
        if (locationResolved) fetchForecast()
        else resolveLocation()
    }

    // A change landing while the matching curl is still in flight is queued
    // and replayed from onStreamFinished, so it can't be silently dropped
    // until the next 15-minute poll.
    property bool pendingResolve: false
    property bool pendingRefetch: false

    // The shell starts well before the network does — wifi association can
    // land 15 seconds after the first fetch has already failed — and the bar
    // hides the indicator until a forecast arrives. Without this the wait
    // would be the full poll interval.
    property int retryDelay: 0
    readonly property int retryDelayBase: 5000
    readonly property int retryDelayMax: 2 * 60 * 1000

    function scheduleRetry() {
        if (!enabled) return
        retryDelay = retryDelay === 0
            ? retryDelayBase
            : Math.min(retryDelay * 2, retryDelayMax)
        retryTimer.interval = retryDelay
        retryTimer.restart()
    }

    function cancelRetry() {
        retryDelay = 0
        retryTimer.stop()
    }

    property Timer retryTimer: Timer {
        repeat: false
        onTriggered: weatherManager.refresh()
    }

    function resolveLocation() {
        if (!enabled) return
        if (geocodeProcess.running || ipGeoProcess.running) {
            pendingResolve = true
            return
        }
        let place = locationOverride.trim()
        if (place.length > 0) {
            geocodeProcess.place = place
            geocodeProcess.running = true
        } else {
            ipGeoProcess.running = true
        }
    }

    function fetchForecast() {
        if (!locationResolved) return
        if (forecastProcess.running) {
            pendingRefetch = true
            return
        }
        forecastProcess.command = ["bash", "-c",
            "curl -s --max-time 8 \"https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + latitude.toFixed(4)
            + "&longitude=" + longitude.toFixed(4)
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"
            + "&hourly=temperature_2m,weather_code,precipitation_probability"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            + "&timezone=auto&forecast_days=7"
            + "&temperature_unit=" + (unit === "fahrenheit" ? "fahrenheit" : "celsius") + "\""]
        forecastProcess.running = true
    }

    property Process ipGeoProcess: Process {
        running: false
        command: ["bash", "-c", "curl -s --max-time 8 https://ipwho.is/"]

        // Compact JSON has no newlines, so StdioCollector (whole stream) is
        // required — a SplitParser would drop the unterminated final segment.
        stdout: StdioCollector {
            onStreamFinished: {
                let ok = false
                try {
                    let j = JSON.parse(this.text)
                    if (typeof j.latitude === "number" && typeof j.longitude === "number") {
                        weatherManager.latitude = j.latitude
                        weatherManager.longitude = j.longitude
                        weatherManager.locationName = j.city || j.region || "Here"
                        weatherManager.locationResolved = true
                        weatherManager.errorText = ""
                        ok = true
                    }
                } catch (e) {}
                if (ok) {
                    weatherManager.cancelRetry()
                } else {
                    // Every way this fails is transient: no network yet, or
                    // ipwho.is answering with success:false under rate limit.
                    weatherManager.errorText = "location unavailable"
                    weatherManager.scheduleRetry()
                }
                if (weatherManager.pendingResolve) {
                    weatherManager.pendingResolve = false
                    weatherManager.resolveLocation()
                } else if (ok) {
                    weatherManager.fetchForecast()
                }
            }
        }
    }

    property Process geocodeProcess: Process {
        running: false
        property string place: ""
        // Place is passed as an argv element ($1), never interpolated into the
        // script, so a name with shell metacharacters can't inject.
        command: ["bash", "-c",
            "curl -s -G --max-time 8 https://geocoding-api.open-meteo.com/v1/search"
            + " --data-urlencode \"name=$1\" -d count=1 -d language=en -d format=json",
            "_", geocodeProcess.place]

        stdout: StdioCollector {
            onStreamFinished: {
                let ok = false
                let answered = false
                try {
                    let j = JSON.parse(this.text)
                    answered = true
                    if (j.results && j.results.length > 0) {
                        let r = j.results[0]
                        weatherManager.latitude = r.latitude
                        weatherManager.longitude = r.longitude
                        weatherManager.locationName = r.name || weatherManager.locationOverride
                        weatherManager.locationResolved = true
                        weatherManager.errorText = ""
                        ok = true
                    }
                } catch (e) {}
                if (ok) {
                    weatherManager.cancelRetry()
                } else {
                    weatherManager.errorText = "place not found"
                    // A well-formed reply with no match is a real answer: the
                    // place is misspelled, and retrying would only hammer the
                    // geocoder. Unparseable output means the request never
                    // landed, which is worth another go.
                    if (answered) weatherManager.cancelRetry()
                    else weatherManager.scheduleRetry()
                }
                if (weatherManager.pendingResolve) {
                    weatherManager.pendingResolve = false
                    weatherManager.resolveLocation()
                } else if (ok) {
                    weatherManager.fetchForecast()
                }
            }
        }
    }

    property Process forecastProcess: Process {
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let j = JSON.parse(this.text)
                    let cur = j.current
                    if (cur) {
                        weatherManager.temperature = cur.temperature_2m
                        weatherManager.feelsLike = cur.apparent_temperature
                        weatherManager.humidity = Math.round(cur.relative_humidity_2m)
                        weatherManager.wind = cur.wind_speed_10m
                        weatherManager.weatherCode = cur.weather_code
                        weatherManager.isDay = cur.is_day === 1
                    }
                    let h = j.hourly
                    if (h && h.time) {
                        let rows = []
                        for (let i = 0; i < h.time.length; i++) {
                            rows.push({
                                "time": h.time[i],
                                "temp": h.temperature_2m[i],
                                "code": h.weather_code[i],
                                "precip": h.precipitation_probability ? h.precipitation_probability[i] : 0
                            })
                        }
                        weatherManager.hourly = rows
                    }
                    let d = j.daily
                    if (d && d.time) {
                        let rows = []
                        for (let i = 0; i < d.time.length; i++) {
                            rows.push({
                                "date": d.time[i],
                                "tempMax": d.temperature_2m_max[i],
                                "tempMin": d.temperature_2m_min[i],
                                "code": d.weather_code[i],
                                "precipProb": d.precipitation_probability_max ? d.precipitation_probability_max[i] : 0
                            })
                        }
                        weatherManager.daily = rows
                    }
                    weatherManager.ready = true
                    weatherManager.errorText = ""
                    weatherManager.cancelRetry()
                } catch (e) {
                    if (!weatherManager.ready) weatherManager.errorText = "weather unavailable"
                    weatherManager.scheduleRetry()
                }
                if (weatherManager.pendingRefetch) {
                    weatherManager.pendingRefetch = false
                    weatherManager.fetchForecast()
                }
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: weatherManager.enabled
        onTriggered: weatherManager.refresh()
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            if (enabled) resolveLocation()
        })
    }
}
