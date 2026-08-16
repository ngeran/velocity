// =============================================================================
// WeatherService.qml — wttr.in current conditions for the bar widget
// =============================================================================
// Same sanctioned pattern as the settings WeatherCard: curl in a Process, no
// API key, IP-geolocated. The bar widget is ALWAYS visible, so — unlike the
// popup-gated probes — a slow always-on poll is the right trade (~4 curls per
// hour at 15 min). Stale-keep: properties only update on a valid sample, so a
// failed fetch leaves the last good conditions on screen.
// =============================================================================
pragma Singleton

import QtQuick
import Quickshell.Io
import "WeatherModel.js" as Model

Item {
    id: root
    visible: false

    property bool hasData: false
    property string location: ""     // "Malvern, Pennsylvania, US"
    property string temp: ""         // "25°C"
    property string condition: ""    // "Clear"
    property string glyph: "󰖐"      // Nerd Font condition glyph

    Process {
        id: fetchProc
        command: ["sh", "-c", "curl -s --max-time 8 'wttr.in/?format=%l|%t|%C&m'"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { fetchProc.buffer += data } }
        onRunningChanged: {
            if (!running) {
                var w = Model.parseWeatherLine(fetchProc.buffer)
                fetchProc.buffer = ""
                if (w) {
                    root.location = w.location
                    root.temp = w.temp
                    root.condition = w.condition
                    root.glyph = Model.glyphForCondition(w.condition)
                    root.hasData = true
                }
            }
        }
    }

    Timer {
        interval: 900000   // 15 min — weather changes slowly
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!fetchProc.running) fetchProc.running = true
    }
}
