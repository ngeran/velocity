// audio-classify.mjs — PipeWire node classification for AudioService (V1).
// Live-verified on quickshell 0.3.0 / PipeWire 1.6.6: playback streams
// (pw-dump `Stream/Output/Audio`) publish `isSink: true, isStream: true`
// while capture streams publish `isSink: false, isStream: true` — so an
// `isSink`-only filter puts playing apps in the OUTPUT list, and a
// `type & Source` filter puts recording apps in INPUT (type 13 carries the
// Source bit). The omarchy omaudiopanel insight (Panel.qml:61-67): classify
// by the isSink/isStream booleans, never by type bits. `hasAudio` is the
// caller passing `n.audio != null` — device nodes without an audio object
// (MIDI/Dummy/Freewheel) are not pickable audio endpoints. Pure so the
// predicates are node-tested and identical for sinks/sources/sinkInputs.

// Classify a node descriptor `{ isSink, isStream, hasAudio }` into one of:
//   "sink"     device output  (isSink && !isStream — live type 17)
//   "source"   device input   (!isSink && !isStream && hasAudio — type 9)
//   "playback" playback stream (isStream && isSink — type 21; NOT a sink,
//                              the regression this lib exists to pin)
//   "capture"  capture stream  (isStream && !isSink — type 13; NOT a source
//                              pickable row even though type carries Source)
//   "other"    everything else (MIDI/Dummy/Freewheel/junk)
// Streams are decided FIRST: playback streams also carry isSink, so an
// isSink-first order would mis-file them as devices.
export function classifyNode(d) {
    if (!d) return "other"
    if (d.isStream) return d.isSink ? "playback" : "capture"
    if (d.isSink) return "sink"
    if (d.hasAudio) return "source"
    return "other"
}

// Stream row label: first non-empty of appName (properties["application.name"]
// — the real name; Chromium's nickname is the useless literal "Playback"),
// nickname, name — trimmed. Empty string when all are empty.
export function streamLabel(parts) {
    if (!parts) return ""
    const cand = [parts.appName, parts.nickname, parts.name]
    for (let i = 0; i < cand.length; i++) {
        const v = typeof cand[i] === "string" ? cand[i].trim() : ""
        if (v) return v
    }
    return ""
}

// Output device glyph: headphones, bluetooth, hdmi/display, generic speaker.
// Ported from omarchy omaudiopanel (Model.js:84). Descriptor carries the raw
// strings the caller has on hand:
//   { name, description, nickname, deviceApi, iconName, productName }
// (deviceApi/iconName/productName = properties["device.api"|"device.icon-name"
// |"device.product.name"]). Headphones win over bluetooth (a BT headset is
// still a headset); bluez_ names are bluetooth before the node even binds.
export function sinkGlyph(d) {
    if (!d) return "\u{f04c3}"
    const blob = [d.name, d.description, d.nickname, d.iconName, d.productName]
        .filter((s) => typeof s === "string" && s !== "")
        .join(" ")
        .toLowerCase()
    if (blob.includes("headphone") || blob.includes("headset") || blob.includes("earbud")
        || blob.includes("earphone") || blob.includes("airpod")) return "\u{f02cb}"
    if (String(d.name || "").startsWith("bluez_") || d.deviceApi === "bluez5"
        || blob.includes("bluetooth")) return "\u{f00af}"
    if (blob.includes("hdmi") || blob.includes("display")) return "\u{f0379}"
    return "\u{f04c3}"
}

// Three-bar "now playing" equalizer heights (0..1) for a PipeWire peak.
// Ported from omarchy omaudiopanel (Model.js:348): silence → [0,0,0]; the
// sqrt term lifts speech-level audio off the floor; each bar swings on a
// phase-shifted sine (phase advances on a 90 ms timer while the card is
// open) with a 0.3 floor so bars stay readable at low levels.
export function eqBarLevels(peak, phase) {
    if (!(peak >= 0.01)) return [0, 0, 0]
    const ph = Number.isFinite(phase) ? phase : 0
    const base = Math.min(1, 0.45 + Math.sqrt(peak) * 1.1)
    const bars = []
    for (let i = 0; i < 3; i++) {
        const swing = 0.5 + 0.5 * Math.abs(Math.sin(ph + i * 2.1))
        bars.push(Math.max(0.3, Math.min(1, base * swing)))
    }
    return bars
}
