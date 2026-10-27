// =============================================================================
// shared/units.mjs — byte/rate formatting (DU8: the ONE binary formatter)
// =============================================================================
// Consumers (synced to bar/lib/ + settings/lib/ — separate -c roots cannot
// import across, so every root gets a byte-identical copy):
//   • bar/lib/network-model.mjs  — throughput totals/rates (imports here)
//   • settings/components/NetworkEngineerView.qml — iface counter rows
//
// NOTE: shared/storage.mjs's formatBytes is a DIFFERENT formatter on purpose
// (decimal, "1.0 TB" — drive sizes are marketed decimal). Do not merge it
// into this binary/1024 one; the two standards answer different questions.
// =============================================================================

// Binary byte size ("512 B", "2.5 KB", "100 MB", "1.5 GB"). Invalid/negative
// input reads as an em dash (a counter that hasn't populated yet).
export function formatBytes(n) {
    if (isNaN(n) || n < 0) return "—"
    if (n < 1024) return n + " B"
    var kb = n / 1024
    if (kb < 1024) return (kb < 10 ? kb.toFixed(1) : Math.round(kb)) + " KB"
    var mb = kb / 1024
    if (mb < 1024) return (mb < 10 ? mb.toFixed(1) : Math.round(mb)) + " MB"
    return (mb / 1024).toFixed(1) + " GB"
}

// Per-second rate label wrapping formatBytes ("2.5 KB/s").
export function formatRate(bytesPerSec) {
    return formatBytes(Math.max(0, Math.round(bytesPerSec))) + "/s"
}
