// audio-classify.test.mjs — pins the live-verified node classes (V1).
// The type numbers are the live quickshell 0.3.0 / PipeWire 1.6.6 values the
// booleans were decoded from (Audio=1, Video=2, Stream=4, Source=8, Sink=16).
import { strict as assert } from "node:assert"
import { classifyNode, streamLabel, sinkGlyph, eqBarLevels } from "./audio-classify.mjs"

const HEADPHONES = "\u{f02cb}"
const BLUETOOTH = "\u{f00af}"
const HDMI = "\u{f0379}"
const SPEAKER = "\u{f04c3}"

let n = 0
const ok = (name, fn) => { fn(); n++; console.log("  ok " + name) }

ok("device sink classifies sink (isSink, !isStream — type 17)", () => {
    assert.equal(classifyNode({ isSink: true, isStream: false, hasAudio: true }), "sink")
})

ok("playback stream classifies playback, NOT sink (isStream && isSink — type 21)", () => {
    // Regression: the pre-V1 `n.isSink` filter put these in the OUTPUT list.
    assert.equal(classifyNode({ isSink: true, isStream: true, hasAudio: true }), "playback")
})

ok("capture stream classifies capture, NOT source (isStream && !isSink — type 13)", () => {
    // Regression: type 13 carries the Source bit, so `type & Source` put
    // recording apps in the INPUT device list.
    assert.equal(classifyNode({ isSink: false, isStream: true, hasAudio: true }), "capture")
})

ok("mic classifies source (!isSink, !isStream, hasAudio — type 9)", () => {
    assert.equal(classifyNode({ isSink: false, isStream: false, hasAudio: true }), "source")
})

ok("MIDI/Dummy classifies other (no audio object)", () => {
    assert.equal(classifyNode({ isSink: false, isStream: false, hasAudio: false }), "other")
})

ok("junk descriptors classify other, never throw", () => {
    assert.equal(classifyNode(null), "other")
    assert.equal(classifyNode(undefined), "other")
    assert.equal(classifyNode({}), "other")
})

ok("streamLabel prefers appName over nickname over name", () => {
    assert.equal(
        streamLabel({ appName: "Chromium", nickname: "Playback", name: "node.99" }),
        "Chromium")
    assert.equal(streamLabel({ nickname: "pw-cat", name: "node.99" }), "pw-cat")
    assert.equal(streamLabel({ name: "node.99" }), "node.99")
})

ok("streamLabel trims and empties safely", () => {
    assert.equal(streamLabel({ appName: "  Brave  ", nickname: "" }), "Brave")
    assert.equal(streamLabel({ appName: "   ", nickname: null }), "")
    assert.equal(streamLabel(null), "")
})

ok("eqBarLevels: silence and junk read as no bars", () => {
    assert.deepEqual(eqBarLevels(0, 1.2), [0, 0, 0])
    assert.deepEqual(eqBarLevels(0.005, 1.2), [0, 0, 0])
    assert.deepEqual(eqBarLevels(-1, 1.2), [0, 0, 0])
    assert.deepEqual(eqBarLevels(NaN, 1.2), [0, 0, 0])
})

ok("eqBarLevels: audible peaks stay inside [0.3, 1] on every bar", () => {
    for (const peak of [0.01, 0.2, 0.5, 1.0, 3.0]) {
        const bars = eqBarLevels(peak, 0.9)
        assert.equal(bars.length, 3)
        for (const b of bars) {
            assert.ok(b >= 0.3 && b <= 1, `peak ${peak}: ${b}`)
        }
    }
})

ok("eqBarLevels: deterministic per phase, junk phase falls back to 0", () => {
    assert.deepEqual(eqBarLevels(0.4, 1.3), eqBarLevels(0.4, 1.3))
    assert.deepEqual(eqBarLevels(0.4, NaN), eqBarLevels(0.4, 0))
    assert.notDeepEqual(eqBarLevels(0.4, 0), eqBarLevels(0.4, 1.7))
})

ok("sinkGlyph: headphones beat every other class", () => {
    assert.equal(sinkGlyph({ name: "bluez_output.AA", description: "WH-1000XM4 Headphones" }), HEADPHONES)
    assert.equal(sinkGlyph({ description: "USB Headset" }), HEADPHONES)
    assert.equal(sinkGlyph({ productName: "Earbuds Pro" }), HEADPHONES)
    assert.equal(sinkGlyph({ description: "AirPods" }), HEADPHONES)
})

ok("sinkGlyph: bluetooth from name prefix, device.api or product text", () => {
    assert.equal(sinkGlyph({ name: "bluez_output.49_59_EB" }), BLUETOOTH)
    assert.equal(sinkGlyph({ name: "alsa_output.x", deviceApi: "bluez5" }), BLUETOOTH)
    assert.equal(sinkGlyph({ productName: "Bluetooth Speaker" }), BLUETOOTH)
})

ok("sinkGlyph: hdmi/display and the generic fallback", () => {
    assert.equal(sinkGlyph({ name: "alsa_output.hdmi-stereo" }), HDMI)
    assert.equal(sinkGlyph({ description: "MPG321UX OLED Display" }), HDMI)
    assert.equal(sinkGlyph({ name: "alsa_output.pci-0.pro-output-0", description: "ALC1220 Analog" }), SPEAKER)
    assert.equal(sinkGlyph(null), SPEAKER)
})

console.log(`audio-classify.test: ${n} passed`)
