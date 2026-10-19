// tz.mjs — zone / DST math without tzdata. Pure; node-tested (tz.test.mjs).
// =============================================================================
// This host's tz database is untrusted (`TZ=Europe/Athens date` renders UTC),
// so every zone time is computed manually from UTC + a per-zone offset chosen
// by a DST rule. Two rules cover the configured cities:
//
//   EU  — last Sunday of March 01:00 UTC → last Sunday of October 01:00 UTC
//         (Athens EET/EEST, London GMT/BST)
//   US  — 2nd Sunday of March 07:00 UTC  → 1st Sunday of November 06:00 UTC
//         (2:00 AM local standard / 2:00 AM local daylight, resolved to UTC)
//         (New York EST/EDT, Chicago CST/CDT, Los Angeles PST/PDT)
//
// The rules transition on DIFFERENT Sundays (US springs ~2 weeks before the
// EU and falls ~1 week after it), so US and EU zones legitimately disagree
// for those windows — the tests pin both sides of every boundary.
//
// Consumers: settings/components/Header.qml (second clock; zone from the
// nikos.timezones plugin settings file). Lives under settings/ (NOT a
// top-level shared/) because the qrc VFS root of a `-c <name>` instance is
// that config's own directory — imports escaping it fail with "Script
// qrc:/qs-blackhole unavailable". plugins/nikos.timezones keeps its own copy
// until the C-phase consolidation (plugins must stay portable).
// =============================================================================

const HOUR_MS = 3600000

// offset = minutes EAST of UTC, [standard, daylight]. Zones the header (and
// later the C-phase consumers) resolve by name; unknown zones fall through to
// the system offset.
const ZONES = {
    "Europe/Athens":       { rule: "eu", offsets: [120, 180],   abbr: ["EET", "EEST"] },
    "Europe/London":       { rule: "eu", offsets: [0, 60],      abbr: ["GMT", "BST"] },
    "America/New_York":    { rule: "us", offsets: [-300, -240], abbr: ["EST", "EDT"] },
    "America/Chicago":     { rule: "us", offsets: [-360, -300], abbr: ["CST", "CDT"] },
    "America/Los_Angeles": { rule: "us", offsets: [-480, -420], abbr: ["PST", "PDT"] },
    "Asia/Tokyo":          { rule: "fixed", offsets: [540],     abbr: ["JST"] },
    "UTC":                 { rule: "fixed", offsets: [0],       abbr: ["UTC"] },
}

// True if the lib can compute this zone (unknown names would silently fall
// back to the system offset — callers use this to keep their own fallback).
export function isKnownZone(zone) {
    return Object.prototype.hasOwnProperty.call(ZONES, String(zone || ""))
}

// UTC ms of the last Sunday of `monthIdx` (0-based) at 01:00 UTC.
export function lastSundayUtcMs(year, monthIdx) {
    const d = new Date(Date.UTC(year, monthIdx + 1, 0))   // last day of month
    d.setUTCDate(d.getUTCDate() - d.getUTCDay())          // back to Sunday
    d.setUTCHours(1, 0, 0, 0)
    return d.getTime()
}

// UTC ms of the `n`th Sunday of `monthIdx` (0-based) at 00:00 UTC.
export function nthSundayUtcMs(year, monthIdx, n) {
    const first = new Date(Date.UTC(year, monthIdx, 1))
    const firstSunday = 1 + ((7 - first.getUTCDay()) % 7)
    return Date.UTC(year, monthIdx, firstSunday + (n - 1) * 7)
}

// EU summer time: from last Sun March 01:00 UTC, to last Sun October 01:00 UTC.
export function euDSTActive(t) {
    const ms = t instanceof Date ? t.getTime() : t
    const d = new Date(ms)
    return ms >= lastSundayUtcMs(d.getUTCFullYear(), 2)
        && ms <  lastSundayUtcMs(d.getUTCFullYear(), 9)
}

// US daylight time: 2nd Sun March 07:00 UTC (2 AM EST) → 1st Sun November
// 06:00 UTC (2 AM EDT). Different Sundays than the EU rule — see header.
export function usDSTActive(t) {
    const ms = t instanceof Date ? t.getTime() : t
    const d = new Date(ms)
    const y = d.getUTCFullYear()
    return ms >= nthSundayUtcMs(y, 2, 2) + 7 * HOUR_MS
        && ms <  nthSundayUtcMs(y, 10, 1) + 6 * HOUR_MS
}

// Minutes EAST of UTC for `zone` at instant `t`. Unknown zone → system offset.
export function zoneOffsetMinutes(zone, t) {
    const z = ZONES[String(zone || "")]
    if (!z) return -(t instanceof Date ? t : new Date(t)).getTimezoneOffset()
    if (z.rule === "fixed") return z.offsets[0]
    const dst = z.rule === "eu" ? euDSTActive(t) : usDSTActive(t)
    return dst ? z.offsets[1] : z.offsets[0]
}

// Zone abbreviation at instant `t` ("" for unknown zones — caller decides).
export function zoneAbbr(zone, t) {
    const z = ZONES[String(zone || "")]
    if (!z) return ""
    if (z.rule === "fixed") return z.abbr[0]
    const dst = z.rule === "eu" ? euDSTActive(t) : usDSTActive(t)
    return dst ? z.abbr[1] : z.abbr[0]
}

function pad2(n) { return (n < 10 ? "0" : "") + n }

// "hh:mm:ss" wall clock in `zone` ("" = system zone). Never Intl.
export function formatInZone(t, zone) {
    const off = zoneOffsetMinutes(zone, t)
    const d = new Date((t instanceof Date ? t : new Date(t)).getTime() + off * 60000)
    return pad2(d.getUTCHours()) + ":" + pad2(d.getUTCMinutes()) + ":" + pad2(d.getUTCSeconds())
}

// "hh:mm" variant (TimezoneService-shaped labels).
export function formatInZoneHM(t, zone) {
    return formatInZone(t, zone).slice(0, 5)
}
