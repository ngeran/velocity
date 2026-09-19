// netparse.test.mjs — plain node, no framework (ryoku pattern).
// Encodes the EXACT pre-extraction behavior of _absorbEnrich, including the
// hostile inputs that motivated the extraction (colons in SSIDs/BSSIDs).
import { strict as assert } from "node:assert"
import { splitTerseLine, bandFromFreq, parseWifiEnrich } from "./netparse.mjs"

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

ok("plain field split", () =>
    assert.deepEqual(splitTerseLine("a:b:c"), ["a", "b", "c"]))

ok("escaped colon stays inside the value", () =>
    assert.deepEqual(splitTerseLine("SSID\\:with\\:colons:AA\\:BB"), ["SSID:with:colons", "AA:BB"]))

ok("BSSID colons fully preserved", () => {
    const f = splitTerseLine("cafe:DE\\:AD\\:BE\\:EF\\:00\\:01:6:2437:42:WPA2")
    assert.equal(f[0], "cafe")
    assert.equal(f[1], "DE:AD:BE:EF:00:01")
    assert.equal(f[2], "6")
    assert.equal(f[3], "2437")
})

ok("band thresholds", () => {
    assert.equal(bandFromFreq(2437), "2.4 GHz")
    assert.equal(bandFromFreq(5180), "5 GHz")
    assert.equal(bandFromFreq(0), "")
    assert.equal(bandFromFreq(NaN), "")
})

ok("enrich rows: escape + lowercase bssid + band", () => {
    // JS literal "\:" is just ":" — every intended nmcli escape needs \\: here.
    const m = parseWifiEnrich("My\\:Net:DE\\:AD\\:BE\\:EF\\:00\\:01:36:5180:88:WPA2\n")
    assert.deepEqual(m["My:Net"], { bssid: "de:ad:be:ef:00:01", chan: "36", freq: 5180, band: "5 GHz" })
})

ok("hidden AP (empty SSID) skipped", () => {
    const m = parseWifiEnrich(":AA\\:BB:1:2412:90:--\n")
    assert.equal(Object.keys(m).length, 0)
})

ok("short lines skipped, empty output tolerated", () => {
    assert.deepEqual(parseWifiEnrich(""), {})
    assert.deepEqual(parseWifiEnrich("garbage\nno:fields"), {})
})

ok("unparseable freq reads as 0 / no band", () => {
    const m = parseWifiEnrich("x:AA:1:notafreq:50:open")
    assert.equal(m.x.freq, 0)
    assert.equal(m.x.band, "")
    assert.equal(m.x.chan, "1")
})

console.log("netparse: " + n + " assertions passed")
