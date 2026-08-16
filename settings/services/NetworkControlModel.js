// =============================================================================
// NetworkControlModel.js — pure connect-failure classification
// =============================================================================
// No Qt imports (Node-testable via the module.exports guard, mirroring the
// bar's NetworkModel.js). Maps nmcli's failure stderr to a stable reason key
// + a human label; the key drives the WifiListView wrong-password reprompt.
// =============================================================================

function connectFailureReason(stderr) {
    var s = stderr || ""
    if (/secrets were required/i.test(s))          return { key: "wrong-password", label: "Wrong password" }
    if (/no network|not found|no longer in range/i.test(s)) return { key: "network-gone", label: "Network disappeared" }
    if (/timeout|timed out/i.test(s))              return { key: "timeout", label: "Timed out" }
    var first = ""
    var lines = s.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var t = lines[i].trim()
        if (t.length > 0) { first = t; break }
    }
    return { key: "failed", label: first ? first.slice(0, 80) : "Connect failed" }
}

if (typeof module !== "undefined") {
    module.exports = { connectFailureReason: connectFailureReason }
}
