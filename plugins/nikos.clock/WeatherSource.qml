// =============================================================================
// WeatherSource.qml — embedded weather fetcher for the clock anchor.
// =============================================================================
// The nikos.weather plugin was removed, and the anchor previously imported its
// service singleton — a static cross-plugin import that would have killed the
// whole clock on restart. This Item is the self-contained replacement: same
// wttr.in j1 source, 15-min cadence, stale-keep on failure. Exposes exactly
// what the anchor renders: glyph · temp · hasData.
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
            root.temp = w.temp
            root.condition = w.condition
            root.glyph = w.glyph
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
