// =============================================================================
// WeatherSource.qml — embedded weather fetcher for the clock plugin.
// =============================================================================
// The nikos.weather plugin was removed, and the anchor previously imported its
// service singleton — a static cross-plugin import that would have killed the
// whole clock on restart. This Item is the self-contained replacement: same
// wttr.in j1 source, 15-min cadence, stale-keep on failure. Feeds both the
// anchor (glyph · temp) and the ATMOSPHERE popup (full field set below).
// =============================================================================
import QtQuick
import Quickshell.Io
import "Weather.js" as W

Item {
    id: root

    property bool hasData: false
    property string glyph: "󰖐"      // Nerd Font condition glyph
    property string temp: ""         // "25°C"
    property string condition: ""    // "Sunny"
    property bool fetching: false

    // Popup-only fields (ATMOSPHERE panel)
    property string location: ""     // "Malvern"
    property string region: ""       // "Pennsylvania"
    property string feels: ""        // "27°C"
    property string humidity: ""     // "54%"
    property string wind: ""         // "16 km/h S"
    property string windDesc: ""     // "Moderate Breeze"
    property string pressure: ""     // "1017 hPa"
    property string dewPoint: ""     // "16°C"
    property string uv: ""           // "4 (MOD)"
    property var days: []            // [{label,min,max,desc,glyph,rain}] × ≤3

    function refresh() {
        fetching = true
        if (!fetchProc.running) fetchProc.running = true
    }

    Process {
        id: fetchProc
        command: ["sh", "-c", "curl -s --max-time 10 'wttr.in/?format=j1'"]
        property string buffer: ""
        // SplitParser emits PER LINE — rejoin WITH newlines (codebase trap).
        stdout: SplitParser { onRead: function(d) { fetchProc.buffer += d + "\n" } }
        onRunningChanged: {
            if (running) return
            var w = W.parseJ1(fetchProc.buffer)
            fetchProc.buffer = ""
            root.fetching = false
            if (!w) return                          // stale-keep
            root.location = w.location
            root.region = w.region
            root.temp = w.temp
            root.condition = w.condition
            // The model doesn't return glyph — the old service derived it
            // from the condition text (same here).
            root.glyph = W.glyphForCondition(w.condition)
            root.feels = w.feels
            root.humidity = w.humidity
            root.wind = w.wind
            root.windDesc = w.windDesc
            root.pressure = w.pressure
            root.dewPoint = w.dewPoint
            root.uv = w.uv
            root.days = w.days
            root.hasData = true
        }
    }

    Timer {
        interval: 900000   // 15 min — weather changes slowly
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
