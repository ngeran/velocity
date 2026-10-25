// =============================================================================
// WeatherService — plugin-internal qmldir singleton (nikos.clock)
// =============================================================================
// Keyless Open-Meteo weather for the calendar panel's today card. Lives INSIDE
// the plugin (like nikos.timezones' TimezoneService) because bar services are
// invisible to plugins — they only see ctx.
//
//   • Pure parsing lives in lib/weather.mjs (node-tested); this file is only
//     the fetch wrapper.
//   • Location: explicit lat/lon settings > cached coords (state file) > a
//     one-shot ipwho.is probe whose result is cached. An explicit location
//     always wins (upstream Ryoku's rule).
//   • Idle-zero: NO recurring timer — refresh happens on panelOpened(), gated
//     to one fetch per 15 min; processes are one-shot curls with a 10s
//     watchdog kill (plain Process like nikos.keyboard's probes — check-
//     bounded only scans bar/services + settings/services).
//   • Last-known weather survives restarts: the raw forecast is cached in
//     $XDG_STATE_HOME/velocity/plugins/nikos.clock-weather.json and booted
//     back in as `stale`, so the first open offline still shows something.
//
// Configured by Service.qml (entryPoints.service) — views never configure.
// Consumed by CalendarPanel.qml via `import "." as Clock`.
// =============================================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/weather.mjs" as Wx

Item {
    id: root

    // ── settings (pushed by Service.qml from ctx.settings) ──────────────────
    property bool showWeather: true
    property string placeSetting: ""    // display label; blank = detected city
    property double latSetting: 0       // 0/0 = auto (cache → ip-locate)
    property double lonSetting: 0

    // ── resolved location ────────────────────────────────────────────────────
    property double lat: 0
    property double lon: 0
    property string detectedPlace: ""
    property double _cacheLat: 0        // ingested from the state file at boot
    property double _cacheLon: 0
    property string _cachePlace: ""

    // ── weather state: idle | loading | stale | ok | error ──────────────────
    // stale = showing last-known data while a refresh is in flight or after
    // one failed (the panel keeps rendering; a small tag marks it).
    property string state: "idle"
    property var wx: null               // Wx.parseForecast output (available-checked)
    property var _raw: null             // un-parsed forecast, for the state cache
    property date lastFetch: new Date(0)
    readonly property int _maxAgeMs: 15 * 60 * 1000

    readonly property bool busy: _busy

    // °C/°F from the session locale (US/LR/MM keep Fahrenheit).
    readonly property string unit: Wx.unitFor(Quickshell.env("LC_ALL") || Quickshell.env("LANG") || "")

    // ── derived, panel-facing ────────────────────────────────────────────────
    readonly property string placeLabel: placeSetting !== "" ? placeSetting : detectedPlace
    readonly property string glyph: (wx && wx.available) ? Wx.nerdFor(wx.code, wx.isDay) : ""
    readonly property string hiLo: (wx && wx.available && wx.daily.length > 0)
                                   ? wx.daily[0].hi + "° / " + wx.daily[0].lo + "°" : ""

    // ── state cache ($XDG_STATE_HOME/velocity/plugins/nikos.clock-weather.json)
    readonly property string _cachePath:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") || "~") + "/.local/state")
        + "/velocity/plugins/nikos.clock-weather.json"

    FileView { id: cacheFile; path: root._cachePath }

    Component.onCompleted: root._ingestCache()

    function _ingestCache() {
        var txt = ""
        try { txt = cacheFile.text() } catch (e) { return }
        var c = Wx.parseJson(txt)
        if (!c) return
        if (typeof c.lat === "number" && typeof c.lon === "number" && (c.lat !== 0 || c.lon !== 0)) {
            root._cacheLat = c.lat
            root._cacheLon = c.lon
            root._cachePlace = typeof c.place === "string" ? c.place : ""
        }
        // Boot the last forecast back in as `stale` — the first panel open
        // refreshes past it, but an offline open still has something to show.
        var wxp = Wx.parseForecast(c.raw, root.unit)
        if (wxp.available) {
            root._raw = c.raw
            root.wx = wxp
            root.lastFetch = new Date(typeof c.fetchedAt === "number" ? c.fetchedAt : 0)
            root.state = "stale"
        }
    }

    // Atomic tmp+mv write (SettingsStore idiom). One-shot, no watcher.
    Process {
        id: cacheWriter   // unbounded-ok: one-shot local tmp+mv file write
    }

    function _writeCache() {
        if (!root.wx || !root.wx.available) return
        cacheWriter.command = ["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1.tmp" && mv "$1.tmp" "$1"',
            "write", root._cachePath,
            JSON.stringify({ place: root.detectedPlace, lat: root.lat, lon: root.lon,
                             fetchedAt: root.lastFetch.getTime(), raw: root._raw })]
        cacheWriter.running = true
    }

    // ── public API ───────────────────────────────────────────────────────────
    function configure(values) {
        var v = values || {}
        root.showWeather = (v.showWeather === undefined) ? true : !!v.showWeather
        root.placeSetting = (typeof v.place === "string") ? v.place : ""
        var nlat = (typeof v.lat === "number") ? v.lat : 0
        var nlon = (typeof v.lon === "number") ? v.lon : 0
        if (nlat !== root.latSetting || nlon !== root.lonSetting) {
            root.latSetting = nlat
            root.lonSetting = nlon
            root.lat = 0
            root.lon = 0
            root.lastFetch = new Date(0)   // re-resolve on the next panel open
        }
    }

    // Called by the BarWidget when a calendar panel opens (per-output panels
    // all funnel here; the 15-min gate dedupes multi-monitor opens).
    function panelOpened() {
        if (!root.showWeather || root._busy) return
        var age = new Date() - root.lastFetch
        if (root.wx && root.wx.available && age >= 0 && age < root._maxAgeMs) return
        root.refresh()
    }

    function refresh() {
        if (!root.showWeather || root._busy) return
        root._busy = true
        root.state = (root.wx && root.wx.available) ? "stale" : "loading"
        root._resolveAndFetch()
    }

    function _resolveAndFetch() {
        // 1. explicit settings always win (Ryoku's rule)
        if (root.latSetting !== 0 || root.lonSetting !== 0) {
            root.lat = root.latSetting
            root.lon = root.lonSetting
            root._fetchForecast()
            return
        }
        // 2. cached coords (from a previous ip-locate) — no network probe
        if (root._cacheLat !== 0 || root._cacheLon !== 0) {
            root.lat = root._cacheLat
            root.lon = root._cacheLon
            if (root.detectedPlace === "") root.detectedPlace = root._cachePlace
            root._fetchForecast()
            return
        }
        // 3. one-shot ip-locate, result cached for future boots
        root._ipBuf = ""
        ipProc.command = ["curl", "-s", "--max-time", "8", "https://ipwho.is/"]
        ipProc.running = true
    }

    function _fetchForecast() {
        root._wxBuf = ""
        wxProc.command = ["curl", "-s", "--max-time", "8",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat
            + "&longitude=" + root.lon
            + ((root.unit === "fahrenheit") ? "&temperature_unit=fahrenheit" : "")
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,weather_code,is_day"
            + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&forecast_days=4&timezone=auto"]
        wxProc.running = true
    }

    // Local naive stamp prefix ("yyyy-MM-ddTHH") for Wx.sliceAhead — the
    // today-card curve starts at the CURRENT hour.
    function nowStamp() {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd'T'HH:mm").slice(0, 13)
    }

    function _fail(reason) {
        root._busy = false
        root.state = (root.wx && root.wx.available) ? "stale" : "error"
        console.log("[nikos.clock] weather fetch failed: " + reason)
    }

    property bool _busy: false
    property string _ipBuf: ""
    property string _wxBuf: ""

    // ── ipwho.is probe ───────────────────────────────────────────────────────
    Process {
        id: ipProc   // unbounded-ok: one-shot curl, killed by a 10s watchdog

        stdout: SplitParser {
            onRead: data => { root._ipBuf += data + "\n" }
        }

        onRunningChanged: {
            if (ipProc.running) { _ipWatch.restart(); return }
            _ipWatch.stop()
            if (!root._busy) return   // watchdog kill — already failed
            var loc = Wx.parseIpwho(Wx.parseJson(root._ipBuf))
            root._ipBuf = ""
            if (loc) {
                root.lat = loc.lat
                root.lon = loc.lon
                root.detectedPlace = loc.city
                root._writeCacheCoords()
                root._fetchForecast()
            } else {
                root._fail("ip-locate failed")
            }
        }
    }

    Timer {
        id: _ipWatch
        interval: 10000
        onTriggered: {
            if (!ipProc.running) return
            root._busy = false        // onRunningChanged skips the dead fetch
            ipProc.running = false
            root._fail("ip-locate timeout")
        }
    }

    // Cache write used BEFORE weather exists (coords only, so the next boot
    // skips the ip probe); _writeCache carries the forecast.
    function _writeCacheCoords() {
        cacheWriter.command = ["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1.tmp" && mv "$1.tmp" "$1"',
            "write", root._cachePath,
            JSON.stringify({ place: root.detectedPlace, lat: root.lat, lon: root.lon,
                             fetchedAt: 0, raw: null })]
        cacheWriter.running = true
    }

    // ── Open-Meteo forecast ──────────────────────────────────────────────────
    Process {
        id: wxProc   // unbounded-ok: one-shot curl, killed by a 10s watchdog

        stdout: SplitParser {
            onRead: data => { root._wxBuf += data + "\n" }
        }

        onRunningChanged: {
            if (wxProc.running) { _wxWatch.restart(); return }
            _wxWatch.stop()
            if (!root._busy) return   // watchdog kill — already failed
            var json = Wx.parseJson(root._wxBuf)
            root._wxBuf = ""
            var wxp = Wx.parseForecast(json, root.unit)
            if (wxp.available) {
                root._raw = json
                root.wx = wxp
                root.lastFetch = new Date()
                root.state = "ok"
                root._writeCache()
            } else {
                root._fail("open-meteo returned no current block")
            }
            root._busy = false
        }
    }

    Timer {
        id: _wxWatch
        interval: 10000
        onTriggered: {
            if (!wxProc.running) return
            root._busy = false
            wxProc.running = false
            root._fail("forecast timeout")
        }
    }
}
