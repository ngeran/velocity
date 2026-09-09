// =============================================================================
// TimezoneService.qml — world-clock data for the bar
// =============================================================================
// Single source of truth for the TimezoneWidget (hover label) and the
// TrayCard timezone body. `now` ticks every 30 s and on refresh(); consumers
// bind labels to it reactively.
//
// NO Intl / NO tzdata: this system's tz database is broken (every zone
// renders +0000 — `TZ=Europe/Athens date` returns plain UTC), so all zone
// times are computed MANUALLY from UTC + per-zone offsets. DST zones use the
// EU rule (last Sunday of March 01:00 UTC → last Sunday of October 01:00 UTC),
// which covers Athens/London; Tokyo is DST-free.
//
// Edit `zones` to configure: { label, shortLabel, zone, offsets: [winter, summer] }
// — zone "" with home: true tracks the system timezone; fixed zones carry one
// offset for both entries.
// =============================================================================

pragma Singleton

import QtQuick

QtObject {
    id: root

    // ── Configuration ────────────────────────────────────────────────────────
    property var zones: [
        { label: "Athens", shortLabel: "ATH", zone: "Europe/Athens", offsets: [120, 180] },
        { label: "London", shortLabel: "LON", zone: "Europe/London", offsets: [0, 60] },
        { label: "Tokyo",  shortLabel: "TYO", zone: "Asia/Tokyo",   offsets: [540, 540] },
        { label: "Local",  shortLabel: "LOCAL", zone: "", home: true },
        { label: "UTC",    shortLabel: "UTC", zone: "UTC", offsets: [0, 0] }
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

    // ── EU DST rule (Athens, London) ─────────────────────────────────────────
    function lastSundayUtc(year, month) {          // month 0-based
        var d = new Date(Date.UTC(year, month + 1, 0))   // last day of month
        d.setUTCDate(d.getUTCDate() - d.getUTCDay())     // back to Sunday
        d.setUTCHours(1, 0, 0, 0)                        // 01:00 UTC
        return d.getTime()
    }
    function euDSTActive(d) {
        return d.getTime() >= lastSundayUtc(d.getUTCFullYear(), 2)    // from last Sun Mar
            && d.getTime() <  lastSundayUtc(d.getUTCFullYear(), 9)    // to last Sun Oct
    }

    // Minutes EAST of UTC for `zone` at time `d`
    function zoneOffsetMinutes(zone, d) {
        if (zone === "UTC") return 0
        for (var i = 0; i < root.zones.length; i++) {
            var z = root.zones[i]
            if (z.zone === zone && z.offsets)
                return euDSTActive(d) ? z.offsets[1] : z.offsets[0]
        }
        return -d.getTimezoneOffset()        // unknown zone → system offset
    }

    function pad2(n) { return (n < 10 ? "0" : "") + n }

    // ── Derived labels (reactive on `now`) ───────────────────────────────────
    // Hover pill: Athens time ONLY ("ATHENS 01:07").
    readonly property string compactLabel: "ATHENS " + timeIn("Europe/Athens")

    // System timezone IANA name for the popup's date line.
    readonly property string localZoneName: {
        try { return Intl.DateTimeFormat().resolvedOptions().timeZone }
        catch (e) { return "" }
    }

    // ── Formatters (manual — never Intl) ─────────────────────────────────────
    // "07:12" wall-clock in the given zone. "" = system zone.
    function timeIn(zone) {
        var off = zone ? zoneOffsetMinutes(zone, root.now)
                       : -root.now.getTimezoneOffset()
        var d = new Date(root.now.getTime() + off * 60000)
        return pad2(d.getUTCHours()) + ":" + pad2(d.getUTCMinutes())
    }

    // "Tue 1 Sep" wall-clock in the given zone.
    function dateIn(zone) {
        var off = zone ? zoneOffsetMinutes(zone, root.now)
                       : -root.now.getTimezoneOffset()
        var d = new Date(root.now.getTime() + off * 60000)
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return days[d.getUTCDay()] + " " + d.getUTCDate() + " " + months[d.getUTCMonth()]
    }

    // Offset vs local: "+6h", "−9h", "+5:30", "" for the system zone itself.
    function offsetLabel(zone) {
        if (!zone) return ""
        var diff = zoneOffsetMinutes(zone, root.now) + root.now.getTimezoneOffset()
        if (diff === 0) return ""              // same offset as local
        var sign = diff < 0 ? "−" : "+"
        var abs = Math.abs(diff)
        var h = Math.floor(abs / 60), m = abs % 60
        return sign + (m === 0 ? h + "h" : h + ":" + (m < 10 ? "0" + m : m))
    }
}
