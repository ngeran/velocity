// =============================================================================
// WeatherService.qml — wttr.in conditions for the bar widget + TrayCard popup
// =============================================================================
// Same sanctioned pattern as the settings WeatherCard: curl in a Process, no
// API key, IP-geolocated. Fetches the j1 JSON (current + 3-day forecast) —
// one curl per 15 min is the right trade for an always-visible widget.
// Stale-keep: properties only update on a valid sample, so a failed fetch
// leaves the last good conditions on screen.
//
// popupOpen mirrors NetworkService/BluetoothService: the popup body sets it
// while it is the active tray, forcing a fresh fetch on open.
// =============================================================================
pragma Singleton

import QtQuick
import Quickshell.Io
import "WeatherModel.js" as Model

Item {
    id: root
    visible: false

    // Set by TrayCard while the weather popup is the active tray.
    property bool popupOpen: false
    onPopupOpenChanged: if (popupOpen) refresh()

    property bool hasData: false
    property string location: ""     // "Athens, Greece"
    property string temp: ""         // "25°C"
    property string condition: ""    // "Sunny"
    property string glyph: "󰖐"      // Nerd Font condition glyph
    property string feels: ""        // "27°C"
    property string humidity: ""     // "40%"
    property string wind: ""         // "11 km/h NW"
    property var days: []            // [{label,min,max,desc,glyph}] × ≤3

    Process {
        id: fetchProc
        command: ["sh", "-c", "curl -s --max-time 10 'wttr.in/?format=j1'"]
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { fetchProc.buffer += data } }
        onRunningChanged: {
            if (running) return
            var w = Model.parseJ1(fetchProc.buffer)
            fetchProc.buffer = ""
            if (!w) return                          // stale-keep
            root.location = w.location
            root.temp = w.temp
            root.condition = w.condition
            root.glyph = Model.glyphForCondition(w.condition)
            root.feels = w.feels
            root.humidity = w.humidity
            root.wind = w.wind
            root.days = w.days
            root.hasData = true
        }
    }

    function refresh() {
        if (!fetchProc.running) fetchProc.running = true
    }

    Timer {
        interval: 900000   // 15 min — weather changes slowly
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
