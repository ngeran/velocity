// =============================================================================
// LogModel.js — pure journalctl -o json parsing + client-side filtering
// =============================================================================
// No Qt imports (Node-testable via the module.exports guard — same convention
// as WeatherModel.js / NetworkModel.js).
//
// journalctl JSON quirks this parser handles (all observed in this machine's
// own journal):
//   - MESSAGE is a plain string OR an array of byte ints when the payload
//     carries ANSI escapes / non-UTF8 bytes (systemd's JSON encoding rule).
//   - __REALTIME_TIMESTAMP / _SOURCE_REALTIME_TIMESTAMP are microsecond
//     STRINGS since the epoch.
//   - PRIORITY is a "0".."7" string and may be absent. 0 emerg · 1 alert ·
//     2 crit · 3 err · 4 warning · 5 notice · 6 info · 7 debug.
//   - _SYSTEMD_UNIT may be absent: user-unit rows carry _SYSTEMD_USER_UNIT,
//     kernel rows carry _TRANSPORT:"kernel" + SYSLOG_IDENTIFIER, and some
//     processes only have _COMM.
// =============================================================================

// CSI (ESC[…m) and OSC (ESC]…BEL/ST) sequences in one pass.
var ANSI_RE = /\x1b\[[0-9;?]*[ -\/]*[@-~]|\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b./g

function stripAnsi(s) {
    return String(s || "").replace(ANSI_RE, "")
}

// MESSAGE decoder: string passthrough, byte-int array → text. Chunked
// fromCharCode — String.fromCharCode.apply() blows the engine's argument
// limit on multi-KB messages.
function decodeMessage(m) {
    if (m === undefined || m === null) return ""
    if (typeof m === "string") return m
    if (typeof m.length === "number") {          // array-like
        var out = "", CH = 4096
        for (var i = 0; i < m.length; i += CH)
            out += String.fromCharCode.apply(null, m.slice(i, i + CH))
        return out
    }
    return String(m)
}

// syslog priority → 3 display buckets used by the overlay's filter chips.
function severityOf(p) {
    if (p <= 3) return "error"
    if (p === 4) return "warn"
    return "info"
}

// Which service/identifier produced the row. ".service" is stripped so the
// unit column stays compact; kernel rows have no unit at all.
function unitOf(obj) {
    var u = obj._SYSTEMD_USER_UNIT || obj._SYSTEMD_UNIT
          || obj.SYSLOG_IDENTIFIER || obj._COMM || ""
    if (!u && obj._TRANSPORT === "kernel") u = "kernel"
    return String(u).replace(/\.service$/, "")
}

function pad2(v) { return v < 10 ? "0" + v : "" + v }

// journalctl JSON object → ListModel row, or null to drop the line. Every
// field's TYPE must be identical across rows — ListModel roles fix their
// type on first append and silently coerce (or warn) on drift.
function parseEntry(obj) {
    if (!obj) return null
    var p = parseInt(obj.PRIORITY, 10)
    if (isNaN(p)) p = 6
    if (p < 0) p = 0
    if (p > 7) p = 7
    var us = parseInt(obj.__REALTIME_TIMESTAMP || obj._SOURCE_REALTIME_TIMESTAMP, 10)
    var ts = isNaN(us) ? 0 : Math.floor(us / 1000)          // µs → ms
    var d = ts > 0 ? new Date(ts) : null
    var msg = stripAnsi(decodeMessage(obj.MESSAGE)).trim()
    return {
        ts: ts,
        timeLabel: d ? pad2(d.getHours()) + ":" + pad2(d.getMinutes()) + ":" + pad2(d.getSeconds())
                     : "--:--:--",
        priority: p,
        severity: severityOf(p),
        unit: unitOf(obj),
        pid: obj._PID !== undefined && obj._PID !== null ? String(obj._PID) : "",
        message: msg.length > 0 ? msg : "(empty)"
    }
}

// Filter predicate shared by the overlay's delegate height-collapse and the
// debounced "MATCHED n / m" scan. Takes plain values (never the ListModel
// object) so it is safe inside a delegate binding. sevFilter is
// "all"|"error"|"warn"|"info"; search is already lowercased.
function rowMatches(severity, message, unit, sevFilter, search) {
    if (sevFilter === "error" && severity !== "error") return false
    if (sevFilter === "warn"  && severity !== "warn")  return false
    if (sevFilter === "info"  && severity !== "info")  return false
    if (search && search.length > 0) {
        var hay = (String(message) + " " + String(unit)).toLowerCase()
        if (hay.indexOf(search) === -1) return false
    }
    return true
}

if (typeof module !== "undefined") {
    module.exports = {
        stripAnsi: stripAnsi,
        decodeMessage: decodeMessage,
        severityOf: severityOf,
        unitOf: unitOf,
        parseEntry: parseEntry,
        rowMatches: rowMatches
    }
}
