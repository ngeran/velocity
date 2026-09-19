// =============================================================================
// netparse.mjs — nmcli terse-output parsing (pure, node-testable)
// =============================================================================
// Extracted from NetworkControlService._absorbEnrich so the escape handling is
// unit-tested instead of re-discovered. nmcli -t escapes ":" inside values as
// "\:" (SSIDs and BSSIDs both contain raw colons) — split("\\:") to a sentinel
// first, split fields on raw ":", then sentinel back to ":" per field.
//
// Behavior is EXACTLY the pre-extraction code; netparse.test.mjs encodes it.
// =============================================================================

function unescapeSentinel(field) {
    return field.split("\u0001").join(":")
}

// "SSID\:with\:colons:AA\:BB:...:chan:freq:signal" -> [unescaped fields]
export function splitTerseLine(line) {
    return String(line).split("\\:").join("\u0001").split(":").map(unescapeSentinel)
}

export function bandFromFreq(mhz) {
    if (mhz >= 5000) return "5 GHz"
    if (mhz > 0) return "2.4 GHz"
    return ""
}

// Full enrichment: nmcli -t -f SSID,BSSID,CHAN,FREQ,SIGNAL,SECURITY output ->
// { ssid: { bssid(lowercase), chan, freq, band } }. Hidden APs (empty SSID)
// and short lines are skipped, mirroring _absorbEnrich.
export function parseWifiEnrich(out) {
    var bySsid = {}
    var lines = String(out).split("\n")
    for (var i = 0; i < lines.length; i++) {
        var parts = splitTerseLine(lines[i])
        if (parts.length < 5) continue
        var ssid = parts[0]
        if (!ssid) continue
        var freq = parseInt(parts[3]) || 0
        bySsid[ssid] = {
            bssid: parts[1].toLowerCase(),
            chan: parts[2] || "--",
            freq: freq,
            band: bandFromFreq(freq)
        }
    }
    return bySsid
}
