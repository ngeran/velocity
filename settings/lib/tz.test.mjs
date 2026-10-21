// tz.test.mjs — pin every DST boundary the lib claims to handle.
// Run: tools/run-unit-tests (auto-discovered; plain node, no framework).
import assert from "node:assert/strict"
import {
    isKnownZone, lastSundayUtcMs, nthSundayUtcMs,
    euDSTActive, usDSTActive, zoneOffsetMinutes, zoneAbbr,
    formatInZone, formatInZoneHM,
    KNOWN_ZONES, isLocalZone, zoneCity, zoneShort, wallClock,
} from "./tz.mjs"

let n = 0
function ok(cond, msg) { n++; assert.ok(cond, msg) }
function eq(got, want, msg) { n++; assert.equal(got, want, msg + ` (got ${JSON.stringify(got)}, want ${JSON.stringify(want)})`) }

// ── published transition instants, 2026 ─────────────────────────────────────
// EU: Sun 29 Mar 2026 01:00 UTC → Sun 25 Oct 2026 01:00 UTC.
// US: Sun  8 Mar 2026 07:00 UTC → Sun  1 Nov 2026 06:00 UTC.
eq(new Date(lastSundayUtcMs(2026, 2)).toISOString(), "2026-03-29T01:00:00.000Z", "EU spring = last Sun Mar")
eq(new Date(lastSundayUtcMs(2026, 9)).toISOString(), "2026-10-25T01:00:00.000Z", "EU fall = last Sun Oct")
eq(new Date(nthSundayUtcMs(2026, 2, 2)).toISOString(), "2026-03-08T00:00:00.000Z", "US spring day = 2nd Sun Mar")
eq(new Date(nthSundayUtcMs(2026, 10, 1)).toISOString(), "2026-11-01T00:00:00.000Z", "US fall day = 1st Sun Nov")

// Athens: one second either side of each EU transition.
eq(zoneOffsetMinutes("Europe/Athens", Date.UTC(2026, 2, 29, 0, 59, 59)), 120, "Athens EET before spring")
eq(zoneOffsetMinutes("Europe/Athens", Date.UTC(2026, 2, 29, 1, 0, 0)), 180, "Athens EEST after spring")
eq(zoneOffsetMinutes("Europe/Athens", Date.UTC(2026, 9, 25, 0, 59, 59)), 180, "Athens EEST before fall")
eq(zoneOffsetMinutes("Europe/Athens", Date.UTC(2026, 9, 25, 1, 0, 0)), 120, "Athens EET after fall")
ok(euDSTActive(Date.UTC(2026, 5, 15, 12, 0, 0)), "Athens mid-July is DST")
ok(!euDSTActive(Date.UTC(2026, 11, 25, 12, 0, 0)), "Athens Christmas is standard")

// New York: one second either side of each US transition (local 2 AM both ways).
eq(zoneOffsetMinutes("America/New_York", Date.UTC(2026, 2, 8, 6, 59, 59)), -300, "NY EST before spring")
eq(zoneOffsetMinutes("America/New_York", Date.UTC(2026, 2, 8, 7, 0, 0)), -240, "NY EDT after spring")
eq(zoneOffsetMinutes("America/New_York", Date.UTC(2026, 10, 1, 5, 59, 59)), -240, "NY EDT before fall")
eq(zoneOffsetMinutes("America/New_York", Date.UTC(2026, 10, 1, 6, 0, 0)), -300, "NY EST after fall")
ok(usDSTActive(Date.UTC(2026, 5, 15, 12, 0, 0)), "NY mid-July is DST")
ok(!usDSTActive(Date.UTC(2026, 11, 25, 12, 0, 0)), "NY Christmas is standard")

// ── the rules transition on DIFFERENT Sundays ───────────────────────────────
// 2021: US sprang forward Mar 14, EU Mar 28 → for two weeks NY is on DST
// while Athens is not. Fall 2026: EU ends Oct 25, US Nov 1 → one week where
// Athens is standard while NY is still on DST.
eq(zoneOffsetMinutes("America/New_York", Date.UTC(2021, 2, 15, 12, 0, 0)), -240, "NY already EDT 2021-03-15")
eq(zoneOffsetMinutes("Europe/Athens", Date.UTC(2021, 2, 15, 12, 0, 0)), 120, "Athens still EET 2021-03-15")
eq(zoneOffsetMinutes("Europe/Athens", Date.UTC(2026, 9, 27, 12, 0, 0)), 120, "Athens EET 2026-10-27")
eq(zoneOffsetMinutes("America/New_York", Date.UTC(2026, 9, 27, 12, 0, 0)), -240, "NY still EDT 2026-10-27")

// ── fixed zones + real-instant spot checks ──────────────────────────────────
eq(zoneOffsetMinutes("Asia/Tokyo", Date.UTC(2026, 0, 1)), 540, "Tokyo fixed +540")
eq(zoneOffsetMinutes("UTC", Date.UTC(2026, 5, 15)), 0, "UTC fixed 0")
// 2026-10-19 22:28:30 UTC = 01:28:30 Athens (EEST) = 18:28:30 New York (EDT)
// — the exact wall times the settings header showed on launch day.
eq(formatInZone(Date.UTC(2026, 9, 19, 22, 28, 30), "Europe/Athens"), "01:28:30", "Athens wall time")
eq(formatInZone(Date.UTC(2026, 9, 19, 22, 28, 30), "America/New_York"), "18:28:30", "NY wall time")
eq(formatInZoneHM(Date.UTC(2026, 9, 19, 22, 28, 30), "Europe/Athens"), "01:28", "HM variant")
eq(formatInZone(Date.UTC(2026, 5, 15, 9, 0, 0), "Europe/Athens"), "12:00:00", "noon EEST = 09:00 UTC")

// ── abbreviations + unknown-zone fallback ───────────────────────────────────
eq(zoneAbbr("Europe/Athens", Date.UTC(2026, 5, 15)), "EEST", "Athens summer abbr")
eq(zoneAbbr("Europe/Athens", Date.UTC(2026, 11, 25)), "EET", "Athens winter abbr")
eq(zoneAbbr("Europe/London", Date.UTC(2026, 5, 15)), "BST", "London summer abbr")
eq(zoneAbbr("Europe/London", Date.UTC(2026, 11, 25)), "GMT", "London winter abbr")
eq(zoneAbbr("Asia/Tokyo", Date.UTC(2026, 5, 15)), "JST", "Tokyo abbr")
eq(zoneAbbr("Mars/Olympus", Date.UTC(2026, 5, 15)), "", "unknown zone → empty abbr")
ok(isKnownZone("Europe/Athens") && !isKnownZone("Mars/Olympus") && !isKnownZone(""), "isKnownZone gates")
const d = new Date(Date.UTC(2026, 5, 15))
eq(zoneOffsetMinutes("Mars/Olympus", d), -d.getTimezoneOffset(), "unknown zone → system offset")

// ── labels + wall clock ─────────────────────────────────────────────────────
ok(KNOWN_ZONES.indexOf("Asia/Tokyo") !== -1 && KNOWN_ZONES.indexOf("Local") === -1, "KNOWN_ZONES lists computable zones")
ok(isLocalZone("Local") && isLocalZone("") && !isLocalZone("UTC"), "isLocalZone")
eq(zoneCity("America/New_York"), "New York", "zoneCity strips region + underscores")
eq(zoneCity("Local"), "Local", "zoneCity local")
eq(zoneShort("Asia/Tokyo"), "TYO", "zoneShort uses the table")
eq(zoneShort("Local"), "LOCAL", "zoneShort local")
const t = new Date(Date.UTC(2026, 6, 1, 12, 30))
const w = wallClock(t, "Europe/Athens")
eq(w.getHours() + ":" + w.getMinutes(), "15:30", "wallClock: Athens EEST local getters")
eq(wallClock(t, "Local").getTime(), t.getTime(), "wallClock: local is identity")

console.log(`tz.test.mjs: OK (${n} assertions)`)
