// LogModel.test.mjs — the journalctl-JSON quirks the parser exists to absorb.
//
// Tests the settings copy; tools/check-shared holds it byte-identical to
// shared/LogModel.js (canonical) and bar/services/LogModel.js, so this suite
// covers all three. Every case below was observed in this machine's own
// journal or is a documented boundary of the parser.
import { strict as assert } from "node:assert"
import { createRequire } from "node:module"
const { stripAnsi, decodeMessage, severityOf, unitOf, parseEntry, rowMatches }
    = createRequire(import.meta.url)("./LogModel.js")

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

// ── stripAnsi ────────────────────────────────────────────────────────────────
ok("CSI colour codes are removed", () => {
    assert.equal(stripAnsi("\x1b[31mfail\x1b[0m"), "fail")
})
ok("OSC title sequences drop with BEL and ST terminators", () => {
    assert.equal(stripAnsi("\x1b]0;title\x07ok"), "ok")
    assert.equal(stripAnsi("\x1b]0;title\x1b\\ok"), "ok")
})
ok("lone ESC eats the following char (catch-all branch); clean text passes", () => {
    // \x1b. is terminal semantics: an ESC with no valid CSI/OSC swallows the
    // next byte rather than leave a stray escape glyph in the row.
    assert.equal(stripAnsi("a\x1bb"), "a")
    assert.equal(stripAnsi("plain"), "plain")
    assert.equal(stripAnsi(null), "")
})

// ── decodeMessage ────────────────────────────────────────────────────────────
ok("string messages pass through, null/undefined become empty", () => {
    assert.equal(decodeMessage("hello"), "hello")
    assert.equal(decodeMessage(undefined), "")
    assert.equal(decodeMessage(null), "")
})
ok("byte-int arrays become text (systemd's non-UTF8 payload encoding)", () => {
    // "OK" plus ESC[32m — the array form real rows use for ANSI payloads
    assert.equal(decodeMessage([79, 75, 27, 91, 51, 50, 109]), "OK\x1b[32m")
})
ok("multi-KB arrays survive the 4096-char chunking", () => {
    const big = new Array(9000).fill(65)   // "A" * 9000 crosses one chunk boundary
    const out = decodeMessage(big)
    assert.equal(out.length, 9000)
    assert.equal(out[0], "A")
    assert.equal(out[8999], "A")
})

// ── severityOf / unitOf ──────────────────────────────────────────────────────
ok("priorities map to the three display buckets", () => {
    assert.equal(severityOf(0), "error")
    assert.equal(severityOf(3), "error")
    assert.equal(severityOf(4), "warn")
    assert.equal(severityOf(5), "info")
    assert.equal(severityOf(7), "info")
})
ok("unit resolution: user-unit wins, .service stripped, fallback chain", () => {
    assert.equal(unitOf({ _SYSTEMD_UNIT: "foo.service" }), "foo")
    assert.equal(unitOf({ _SYSTEMD_USER_UNIT: "bar.service", _SYSTEMD_UNIT: "other.service" }), "bar")
    assert.equal(unitOf({ SYSLOG_IDENTIFIER: "kernel-ish" }), "kernel-ish")
    assert.equal(unitOf({ _COMM: "sshd" }), "sshd")
    assert.equal(unitOf({ _TRANSPORT: "kernel" }), "kernel")
    assert.equal(unitOf({}), "")
})

// ── parseEntry ───────────────────────────────────────────────────────────────
const US = "1764000000123456"   // µs-since-epoch STRING, as journalctl emits
const row = (over) => parseEntry(Object.assign({
    MESSAGE: "boot ok", PRIORITY: "3",
    __REALTIME_TIMESTAMP: US, _SYSTEMD_UNIT: "quickshell-bar.service", _PID: 4242
}, over))

ok("a full row parses: µs string → ms ts, local timeLabel, pid string", () => {
    const r = row({})
    const d = new Date(Math.floor(Number(US) / 1000))
    const p2 = (v) => (v < 10 ? "0" + v : "" + v)
    assert.equal(r.ts, d.getTime())
    assert.equal(r.timeLabel, p2(d.getHours()) + ":" + p2(d.getMinutes()) + ":" + p2(d.getSeconds()))
    assert.equal(r.priority, 3)
    assert.equal(r.severity, "error")
    assert.equal(r.unit, "quickshell-bar")
    assert.equal(r.pid, "4242")
    assert.equal(r.message, "boot ok")
})
ok("PRIORITY quirks: absent/garbage → 6, clamped to 0..7", () => {
    assert.equal(row({ PRIORITY: undefined }).priority, 6)
    assert.equal(row({ PRIORITY: "abc" }).priority, 6)
    assert.equal(row({ PRIORITY: "-2" }).priority, 0)
    assert.equal(row({ PRIORITY: "9" }).priority, 7)
})
ok("_SOURCE_REALTIME_TIMESTAMP backs up a missing __REALTIME_TIMESTAMP", () => {
    const r = row({ __REALTIME_TIMESTAMP: undefined, _SOURCE_REALTIME_TIMESTAMP: US })
    assert.equal(r.ts, Math.floor(Number(US) / 1000))
})
ok("no timestamp at all → ts 0 and the --:--:-- label", () => {
    const r = row({ __REALTIME_TIMESTAMP: undefined, _SOURCE_REALTIME_TIMESTAMP: undefined })
    assert.equal(r.ts, 0)
    assert.equal(r.timeLabel, "--:--:--")
})
ok("byte-array MESSAGE decodes and ANSI strips before trim", () => {
    const r = row({ MESSAGE: [27, 91, 51, 49, 109, 101, 114, 114] })  // ESC[31m + "err"
    assert.equal(r.message, "err")
})
ok("empty and whitespace-only messages become (empty)", () => {
    assert.equal(row({ MESSAGE: "" }).message, "(empty)")
    assert.equal(row({ MESSAGE: "  \t" }).message, "(empty)")
})
ok("missing _PID → empty string (role type stability for the ListModel)", () => {
    assert.equal(row({ _PID: undefined }).pid, "")
})
ok("null input drops to null", () => {
    assert.equal(parseEntry(null), null)
})

// ── rowMatches ───────────────────────────────────────────────────────────────
ok("severity filter gates, 'all' lets everything through", () => {
    assert.equal(rowMatches("error", "x", "u", "all", ""), true)
    assert.equal(rowMatches("info", "x", "u", "error", ""), false)
    assert.equal(rowMatches("warn", "x", "u", "error", ""), false)
    assert.equal(rowMatches("warn", "x", "u", "warn", ""), true)
    assert.equal(rowMatches("info", "x", "u", "info", ""), true)
})
ok("search is a case-insensitive substring over message + unit", () => {
    assert.equal(rowMatches("info", "GPU Reset", "amdgpu", "all", "gpu reset"), true)   // via message
    assert.equal(rowMatches("info", "unrelated", "quickshell-bar", "all", "quickshell"), true) // via unit
    assert.equal(rowMatches("info", "unrelated", "quickshell-bar", "all", "nope"), false)
})
ok("both filters combine (AND)", () => {
    assert.equal(rowMatches("error", "GPU Reset", "amdgpu", "error", "gpu"), true)
    assert.equal(rowMatches("error", "GPU Reset", "amdgpu", "warn", "gpu"), false)
})

console.log("LogModel.test: " + n + " assertions-groups passed")
