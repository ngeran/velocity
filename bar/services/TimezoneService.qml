// =============================================================================
// TimezoneService.qml — world-clock data for the bar
// =============================================================================
// Single source of truth for the TimezoneWidget (hover label) and the
// TrayCard timezone body. Offsets/labels come from the system's tzdata via
// Intl (no network, DST-correct). `now` ticks every 30 s and on refresh();
// consumers bind labels to it reactively.
//
// Edit `zones` to configure: { label, shortLabel, zone } — zone "" with
// home: true tracks the system timezone.
// =============================================================================

pragma Singleton

import QtQuick

QtObject {
    id: root

    // ── Configuration ────────────────────────────────────────────────────────
    property var zones: [
        { label: "Local", shortLabel: "LOCAL", zone: "", home: true },
        { label: "New York", shortLabel: "NY", zone: "America/New_York" },
        { label: "Los Angeles", shortLabel: "CA", zone: "America/Los_Angeles" },
        { label: "UTC", shortLabel: "UTC", zone: "UTC" }
    ]

    // ── Live clock ───────────────────────────────────────────────────────────
    property date now: new Date()

    property Timer tick: Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    function refresh() { root.now = new Date() }

    // ── Derived labels (reactive on `now`) ───────────────────────────────────
    // "NY 07:12 · CA 04:12" — home zone excluded (the bar clock already shows it)
    readonly property string compactLabel: {
        var parts = []
        for (var i = 0; i < zones.length; i++) {
            var z = zones[i]
            if (z.home || !z.zone) continue
            var t = timeIn(z.zone)
            if (t) parts.push(z.shortLabel + " " + t)
        }
        return parts.join(" · ")
    }

    // System timezone IANA name ("Europe/Athens") for the popup's date line.
    readonly property string localZoneName: {
        try { return Intl.DateTimeFormat().resolvedOptions().timeZone }
        catch (e) { return "" }
    }

    // ── Formatters ───────────────────────────────────────────────────────────
    // "07:12" in the given zone.
    function timeIn(zone) {
        if (!zone) return Qt.formatDateTime(root.now, "HH:mm")
        try {
            var f = new Intl.DateTimeFormat('en-US', { timeZone: zone, hour: '2-digit', minute: '2-digit', hour12: false })
            var p = f.formatToParts(root.now)
            return p.find(function(x) { return x.type === 'hour' }).value + ":"
                 + p.find(function(x) { return x.type === 'minute' }).value
        } catch (e) { return "—" }
    }

    // "Tue 1 Sep" in the given zone.
    function dateIn(zone) {
        var d = zone ? zonedDate(zone) : root.now
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return days[d.getDay()] + " " + d.getDate() + " " + months[d.getMonth()]
    }

    // Offset vs local: "+6h", "−9h", "+5:30", "" for local itself.
    function offsetLabel(zone) {
        if (!zone) return ""
        var diff = zonedDate(zone) - root.now          // ms east of local
        if (Math.abs(diff) < 60000) return ""          // same offset as local
        var sign = diff < 0 ? "−" : "+"
        var abs = Math.round(Math.abs(diff) / 60000)
        var h = Math.floor(abs / 60), m = abs % 60
        return sign + (m === 0 ? h + "h" : h + ":" + (m < 10 ? "0" + m : m))
    }

    // Local-wall-clock Date of `now` in `zone` (the classic toLocaleString
    // round-trip; used only for date/offset arithmetic, never formatting).
    function zonedDate(zone) {
        try {
            var s = root.now.toLocaleString('en-US', { timeZone: zone })
            return new Date(s)
        } catch (e) { return root.now }
    }
}
