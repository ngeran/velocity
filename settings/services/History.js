// History.js — metric ring-buffer helpers for the Core section.
// Ported from omarchy-system-monitor (Metrics.qml / Metrics.js). Pure JS with
// no Qt imports so it stays shared by every service that needs a rolling
// window: a history is an array of { time: msEpoch, value: number }, oldest
// first, capped to `maxSamples` entries covering at most `windowMs`.
.pragma library

function appendHistory(current, timestamp, value, windowMs, maxSamples) {
    if (!isFinite(value) || value < 0) return current
    var cutoff = timestamp - windowMs
    var next = []
    for (var i = 0; i < current.length; i++) {
        if (current[i].time >= cutoff) next.push(current[i])
    }
    next.push({ time: timestamp, value: value })
    if (next.length > maxSamples) next = next.slice(next.length - maxSamples)
    return next
}

function peakValue(list) {
    var peak = 0
    if (!list) return peak
    for (var i = 0; i < list.length; i++) {
        var value = Number(list[i].value)
        if (isFinite(value) && value > peak) peak = value
    }
    return peak
}
