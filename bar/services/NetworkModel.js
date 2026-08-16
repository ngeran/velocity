// =============================================================================
// NetworkModel.js — pure parsing/formatting for NetworkService
// =============================================================================
// No Qt imports on purpose: the same file runs under Node, so parsers can be
// unit-tested against sample nmcli/ip/ping/sysfs output without launching the
// bar (new parsers land here per the incremental Model.js adoption — see the
// Omarchy Quattro analysis).
// =============================================================================

// Two whitespace-separated counters: rx_bytes tx_bytes (from `cat` over both
// sysfs statistics files). Returns {rx, tx} ints or null when unreadable.
function parseStats(raw) {
    var f = (raw || "").trim().split(/\s+/)
    if (f.length < 2) return null
    var rx = parseInt(f[0], 10)
    var tx = parseInt(f[1], 10)
    if (isNaN(rx) || isNaN(tx)) return null
    return { rx: rx, tx: tx }
}

function formatBytes(n) {
    if (isNaN(n) || n < 0) return "—"
    if (n < 1024) return n + " B"
    var kb = n / 1024
    if (kb < 1024) return (kb < 10 ? kb.toFixed(1) : Math.round(kb)) + " KB"
    var mb = kb / 1024
    if (mb < 1024) return (mb < 10 ? mb.toFixed(1) : Math.round(mb)) + " MB"
    return (mb / 1024).toFixed(1) + " GB"
}

function formatRate(bytesPerSec) {
    return formatBytes(Math.max(0, Math.round(bytesPerSec))) + "/s"
}

// Pure state fold (Omarchy throughputState shape): given the previous sample,
// the new counters and a timestamp, return the rates/totals to display and the
// sample to carry forward. Guards: an iface change or a backwards counter
// (interface re-incarnated) yields no rate rather than a fake spike — the next
// tick re-baselines.
function throughputState(prev, iface, rx, tx, nowMs) {
    var next = { iface: iface, rx: rx, tx: tx, t: nowMs }
    var out = {
        rxRate: "", txRate: "",
        rxTotal: formatBytes(rx), txTotal: formatBytes(tx),
        state: next
    }
    if (!prev || prev.iface !== iface || nowMs <= prev.t) return out
    var dt = (nowMs - prev.t) / 1000
    if (dt <= 0) return out
    var drx = rx - prev.rx
    var dtx = tx - prev.tx
    if (drx < 0 || dtx < 0) return out
    out.rxRate = formatRate(drx / dt)
    out.txRate = formatRate(dtx / dt)
    return out
}

if (typeof module !== "undefined") {
    module.exports = {
        parseStats: parseStats,
        formatBytes: formatBytes,
        formatRate: formatRate,
        throughputState: throughputState
    }
}
