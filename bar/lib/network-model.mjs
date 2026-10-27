// =============================================================================
// NetworkModel.mjs — pure parsing/formatting for NetworkService
// =============================================================================
// No Qt imports on purpose: the same file runs under Node, so parsers can be
// unit-tested against sample nmcli/ip/ping/sysfs output without launching the
// bar. ES module (DU8 refactor from .js): byte formatting lives in the shared
// units.mjs (synced copy at ../lib/units.mjs), everything else stays here.
// =============================================================================

import { formatBytes, formatRate } from "../lib/units.mjs"

export { formatBytes, formatRate }

// Pure state fold (Omarchy throughputState shape): given the previous sample,
// the new counters and a timestamp, return the rates/totals to display and the
// sample to carry forward. Guards: an iface change or a backwards counter
// (interface re-incarnated) yields no rate rather than a fake spike — the next
// tick re-baselines.
export function throughputState(prev, iface, rx, tx, nowMs) {
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

// =============================================================================
// ACCESS POINTS — the tray card's AP list (C3 network panel upgrade)
// =============================================================================
// Input: the raw Quickshell.Networking scan list (live WifiNetwork QObjects).
// Output: display records that KEEP the QObject (so stateChanging/connected
// stay live bindings in the delegate) alongside plain display fields. The
// connected network is EXCLUDED — the popup's hero row carries it (upstream
// NetworkPopout semantics; the settings app's OTHER NETWORKS does the same).
// Native scan carries no band, so the upstream SSID+band key collapses to
// SSID-only: a dual-band SSID shows its strongest BSS (the tradeoff the
// upstream file documents; without band data there is nothing to key on).

// WifiSecurityType values that need no password. Owe is Opportunistic WPA
// (enhanced open) — joins with no secrets, so it counts as open here.
var _OPEN_SECURITY = { Open: true, Unknown: true, Owe: true }

export function secured(secName) {
    return !_OPEN_SECURITY[secName]
}

// Best-per-SSID, strongest first, connected row filtered out.
export function groupAps(rawList, activeSsid) {
    var best = {}
    var list = rawList || []
    for (var i = 0; i < list.length; i++) {
        var net = list[i]
        if (!net || net.name === "" || net.name === null) continue
        if (net.connected || net.name === activeSsid) continue
        var prev = best[net.name]
        if (!prev || net.signalStrength > prev.signalStrength) best[net.name] = net
    }
    var out = []
    for (var name in best) {
        var n = best[name]
        out.push({
            net: n,                          // live QObject — delegate binds through it
            name: n.name,
            pct: Math.round((n.signalStrength || 0) * 100),
            secured: secured(String(n.security)),
            known: !!n.known
        })
    }
    out.sort(function(a, b) { return b.pct - a.pct })
    return out
}

// Content signature for the view's diff gate (the wifi list has regressed
// twice to Repeater resets — frozenAps only reassigns when this CHANGES).
export function apsSignature(grouped) {
    var parts = []
    for (var i = 0; i < grouped.length; i++)
        parts.push(grouped[i].name + ":" + grouped[i].pct + ":" +
                   (grouped[i].secured ? 1 : 0) + ":" + (grouped[i].known ? 1 : 0))
    return parts.join("|")
}

// Wifi-strength glyph (the settings WifiListView table, shared).
export function sigGlyph(pct) {
    return pct >= 70 ? "\u{f0928}"   // wifi-strong
         : pct >= 40 ? "\u{f0925}"   // wifi-good
         : pct >= 20 ? "\u{f0922}"   // wifi-weak
         :             "\u{f091f}"   // wifi-low
}

// Median of a numeric sample array (the speed test reports the median, not
// the max — a single stalled sample must not read as a faster link).
export function median(values) {
    var sorted = (values || []).slice().sort(function(a, b) { return a - b })
    return sorted.length ? sorted[Math.floor(sorted.length / 2)] : 0
}

// ConnectionFailReason → the row's inline error line.
export function failLabel(reasonName) {
    switch (reasonName) {
        case "NoSecrets":               return "Password required"
        case "WifiClientFailed":        return "Wrong password or rejected"
        case "WifiAuthTimeout":         return "Authentication timed out"
        case "WifiNetworkLost":         return "Network disappeared"
        case "WifiClientDisconnected":  return "Connection failed"
        default:                        return "Connection failed"
    }
}
