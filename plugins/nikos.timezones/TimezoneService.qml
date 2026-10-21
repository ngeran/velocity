// =============================================================================
// TimezoneService.qml — world-clock data for the timezones pill + grid
// =============================================================================
// Zone math: lib/tz.mjs (synced from shared/tz.mjs — no Intl/tzdata, this
// host's tz database is untrusted). Zones come from the plugin settings
// (manifest `zone` + `zones`), pushed in by BarWidget via configure().
// `now` ticks every 30 s and on refresh(); consumers bind to it.
// =============================================================================

pragma Singleton

import QtQuick
import "lib/tz.mjs" as Tz

QtObject {
    id: root

    property string pillZone: "Europe/Athens"
    property var zoneIds: ["Europe/Athens", "Europe/London", "Asia/Tokyo", "Local", "UTC"]

    function configure(values) {
        if (!values) return
        if (typeof values.zone === "string") root.pillZone = values.zone
        if (Array.isArray(values.zones)) root.zoneIds = values.zones
    }

    // Row model for Panel.qml: { label, shortLabel, zone, home }. zone "" = system.
    readonly property var zones: root.zoneIds.map(function(id) {
        var local = Tz.isLocalZone(id)
        return { label: Tz.zoneCity(id), shortLabel: Tz.zoneShort(id),
                 zone: local ? "" : id, home: local }
    })

    // ── Live clock ───────────────────────────────────────────────────────────
    property date now: new Date()

    property Timer tick: Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    function refresh() { root.now = new Date() }

    function zoneOffsetMinutes(zone, d) { return Tz.zoneOffsetMinutes(zone, d) }

    function pad2(n) { return (n < 10 ? "0" : "") + n }

    // Hover pill: "ATHENS 01:07".
    readonly property string compactLabel: Tz.zoneCity(root.pillZone).toUpperCase() + " "
        + Tz.formatInZoneHM(root.now, Tz.isLocalZone(root.pillZone) ? "" : root.pillZone)

    // System timezone IANA name for the popup's date line.
    readonly property string localZoneName: {
        try { return Intl.DateTimeFormat().resolvedOptions().timeZone }
        catch (e) { return "" }
    }

    // "07:12" wall-clock in the given zone. "" = system zone.
    function timeIn(zone) { return Tz.formatInZoneHM(root.now, zone) }

    // Offset vs local: "+6h", "−9h", "+5:30", "" for the system zone itself.
    function offsetLabel(zone) {
        if (!zone) return ""
        var diff = zoneOffsetMinutes(zone, root.now) + root.now.getTimezoneOffset()
        if (diff === 0) return ""
        var sign = diff < 0 ? "−" : "+"
        var abs = Math.abs(diff)
        var h = Math.floor(abs / 60), m = abs % 60
        return sign + (m === 0 ? h + "h" : h + ":" + (m < 10 ? "0" + m : m))
    }

    // ── Working-hours grid (worldtimebuddy port, omarchy-timezones rules) ────
    // Columns align on the HOME day; column i = home-midnight + i hours (one
    // absolute moment), and each cell renders that moment's hour IN ITS ZONE.
    function homeOffsetMinutes(d) { return -d.getTimezoneOffset() }

    // UTC ms of the home zone's most recent local midnight (column 0).
    function dayStartUtc(d) {
        var dayMs = 24 * 3600000
        var off = homeOffsetMinutes(d)
        var localMs = d.getTime() + off * 60000
        return localMs - (((localMs % dayMs) + dayMs) % dayMs) - off * 60000
    }

    // Fractional "now" column position in [0, 24) for the vertical indicator.
    function nowColumn(d) { return (d.getTime() - dayStartUtc(d)) / 3600000 }

    // One grid cell: the zone-local hour at home-day column `col`, plus the
    // omarchy tint bands — work 8–18, day 6–23, night otherwise.
    function cellAt(col, dayStartUtcMs, offsetMin) {
        var z = new Date(dayStartUtcMs + col * 3600000 + offsetMin * 60000)
        var hour = z.getUTCHours()
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return {
            hour: hour,
            isMidnight: hour === 0,
            dayLabel: days[z.getUTCDay()] + " " + z.getUTCDate(),
            tint: (hour >= 8 && hour < 18) ? "work" : (hour >= 6 && hour < 23) ? "day" : "night"
        }
    }

    // "18:00" wall-clock for an absolute UTC instant in a fixed-offset zone.
    function timeAtOffset(utcMs, offsetMin) {
        var d = new Date(utcMs + offsetMin * 60000)
        return pad2(d.getUTCHours()) + ":" + pad2(d.getUTCMinutes())
    }

    // "Thu 6 Sep" for the zone's current day.
    function dateAtOffset(offsetMin) {
        var d = new Date(root.now.getTime() + offsetMin * 60000)
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return days[d.getUTCDay()] + " " + d.getUTCDate() + " " + months[d.getUTCMonth()]
    }

    function abbrFor(zone) { return Tz.zoneAbbr(zone, root.now) }
}
