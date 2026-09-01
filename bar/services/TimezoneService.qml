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
    // Hover pill: Athens time ONLY ("ATHENS 01:07"), computed manually from
    // UTC — this system's tz database is broken (every zone renders +0000:
    // `TZ=Europe/Athens date` returns plain UTC), so Intl/tzdata conversions
    // cannot be trusted. Athens follows the EU DST rule: EEST (UTC+3) from the
    // last Sunday of March to the last Sunday of October, EET (UTC+2) after.
    readonly property string compactLabel: "ATHENS " + athensTime()

    // ── Athens (manual, tzdata-free) ─────────────────────────────────────────
    function lastSundayUtc(year, month) {          // month 0-based
        var d = new Date(Date.UTC(year, month + 1, 0))   // last day of month
        d.setUTCDate(d.getUTCDate() - d.getUTCDay())     // back to Sunday
        d.setUTCHours(1, 0, 0, 0)                        // 01:00 UTC
        return d.getTime()
    }
    function athensOffsetMinutes(d) {
        var start = lastSundayUtc(d.getUTCFullYear(), 2)   // March
        var end   = lastSundayUtc(d.getUTCFullYear(), 9)   // October
        return (d.getTime() >= start && d.getTime() < end) ? 180 : 120
    }
    function pad2(n) { return (n < 10 ? "0" : "") + n }
    function athensTime() {
        var d = new Date(root.now.getTime() + athensOffsetMinutes(root.now) * 60000)
        return pad2(d.getUTCHours()) + ":" + pad2(d.getUTCMinutes())
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
