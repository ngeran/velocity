// model.test.mjs — node asserts for the pure WireGuard plugin model (no
// framework, same contract as storage.test.mjs). Run via tools/run-unit-tests.
import assert from "node:assert"
import {
    sanitizeError, unescapeNmcli, splitTerse, parseTunnelLines, parseCounters,
    parsePeerProfile, parseWgDump, computeRates, splitBytes, handshakeAge,
    uptimeLabel, trimDnsName, parseTailscaleStatus, peerPath
} from "./model.mjs"

let n = 0
const ok = (name, fn) => { fn(); n++; console.log("  ok " + name) }

// ── nmcli terse parsing ────────────────────────────────────────────────────
ok("splitTerse honors escaped colons", () => {
    // A profile named "a:b" and device "wg:0" — the separator inside values
    // is "\:" in terse output.
    const cols = splitTerse("a\\:b:uuid1:wireguard:activated:wg\\:0:yes:1731000000")
    assert.deepStrictEqual(cols, ["a:b", "uuid1", "wireguard", "activated", "wg:0", "yes", "1731000000"])
    assert.strictEqual(unescapeNmcli("a\\:b"), "a:b")
})

ok("parseTunnelLines filters wireguard and maps fields", () => {
    const raw = [
        "Home LAN:u1:802-11-wireless:activated:wlan0:yes:1731000000",
        "iad-c46:u2:wireguard:activated:wg0:yes:1731000123",
        "Old VPN\\: US:u3:wireguard:deactivated:--:no:0",
        "garbage line"
    ].join("\n")
    const tunnels = parseTunnelLines(raw)
    assert.strictEqual(tunnels.length, 2)
    assert.deepStrictEqual(tunnels[0], {
        name: "iad-c46", uuid: "u2", state: "activated", device: "wg0",
        active: true, activatedAt: 1731000123
    })
    assert.deepStrictEqual(tunnels[1], {
        name: "Old VPN: US", uuid: "u3", state: "deactivated", device: "--",
        active: false, activatedAt: 0
    })
})

// ── sysfs counters ─────────────────────────────────────────────────────────
ok("parseCounters keeps first sample per device", () => {
    const counters = parseCounters("wg0 100 200\nwg0 999 999\neth0 5 6\nbad line")
    assert.deepStrictEqual(counters, {
        wg0: { rx: 100, tx: 200 },
        eth0: { rx: 5, tx: 6 }
    })
})

// ── rate math, incl. counter wrap/reset ────────────────────────────────────
ok("computeRates divides by elapsed and clamps resets to zero", () => {
    const before = { wg0: { rx: 1000, tx: 2000 } }
    const after = { wg0: { rx: 3000, tx: 2600 } }
    const rates = computeRates(before, after, 2000)
    assert.strictEqual(rates.wg0.rx, 1000)  // +2000 B / 2 s
    assert.strictEqual(rates.wg0.tx, 300)   // +600 B / 2 s
    // Interface recreated (counter reset): negative delta clamps to 0, no NaN.
    const reset = computeRates(before, { wg0: { rx: 10, tx: 10 } }, 1000)
    assert.strictEqual(reset.wg0.rx, 0)
    assert.strictEqual(reset.wg0.tx, 0)
    // New device with no baseline: no rate entry.
    const fresh = computeRates(before, { wg1: { rx: 5, tx: 5 } }, 1000)
    assert.ok(!("wg1" in fresh))
    // Zero/negative elapsed: nothing (guard against Infinity).
    assert.deepStrictEqual(computeRates(before, after, 0), {})
})

// ── wg dump (kept for the parked sudoers tier — must not rot) ─────────────
ok("parseWgDump parses header and peer rows", () => {
    const raw = [
        "wg0\tpubkeyABC\t51820\t0.0.0.0/0",
        "peerKEY1\tpeer1.example:51820\t1.2.3.4:51820\t10.0.0.2/32,0.0.0.0/0\t1731000000\t111\t222\t25",
        "peerKEY2\t(none)\t(none)\t(none)\t0\t0\t0\t0"
    ].join("\n")
    const dump = parseWgDump(raw)
    assert.strictEqual(dump.publicKey, "pubkeyABC")
    assert.strictEqual(dump.listenPort, 51820)
    assert.strictEqual(dump.peers.length, 2)
    assert.deepStrictEqual(dump.peers[0], {
        pubkey: "peerKEY1", endpoint: "1.2.3.4:51820",
        allowedIps: ["10.0.0.2/32", "0.0.0.0/0"],
        latestHandshake: 1731000000, rx: 111, tx: 222, keepalive: 25
    })
    assert.deepStrictEqual(dump.peers[1].allowedIps, [])
    assert.strictEqual(dump.peers[1].endpoint, "")
})

// ── profile peers string ───────────────────────────────────────────────────
ok("parsePeerProfile splits pubkeys from known attributes", () => {
    const raw = "KEYAAA== allowed-ips=0.0.0.0/0;::/0 endpoint=1.2.3.4:51820 persistent-keepalive=25 " +
                "KEYBBB= allowed-ips=10.0.0.2/32 endpoint=(none)"
    const peers = parsePeerProfile(raw)
    assert.strictEqual(peers.length, 2)
    assert.strictEqual(peers[0].endpoint, "1.2.3.4:51820")
    assert.deepStrictEqual(peers[0].allowedIps, ["0.0.0.0/0", "::/0"])
    assert.strictEqual(peers[0].keepalive, 25)
    // A base64 key ending "=" is a key, not an attribute.
    assert.strictEqual(peers[1].pubkey, "KEYBBB=")
    assert.strictEqual(peers[1].endpoint, "(none)")      // verbatim (ngeran behavior)
    assert.deepStrictEqual(peers[1].allowedIps, ["10.0.0.2/32"])
})

// ── byte / age / uptime formatting ─────────────────────────────────────────
ok("splitBytes picks unit and decimals", () => {
    assert.deepStrictEqual(splitBytes(512), { digits: 512, unit: "B", decimals: 0 })
    assert.deepStrictEqual(splitBytes(2048), { digits: 2, unit: "KiB", decimals: 1 })
    const mib = splitBytes(150 * 1048576)
    assert.strictEqual(mib.unit, "MiB")
    assert.strictEqual(mib.decimals, 0)   // ≥100 → whole digits
})

ok("handshakeAge guards zero and clock skew", () => {
    assert.strictEqual(handshakeAge(0, 1000), -1)
    assert.strictEqual(handshakeAge(990, 1000), 10)
    assert.strictEqual(handshakeAge(1100, 1000), 0)   // future stamp → 0
})

ok("uptimeLabel formats h/m/s", () => {
    assert.strictEqual(uptimeLabel(0, 5000), "—")
    assert.strictEqual(uptimeLabel(4977, 5000), "0m 23s")
    assert.strictEqual(uptimeLabel(5000 - 65, 5000), "1m 05s")
    assert.strictEqual(uptimeLabel(5000 - 3600 - 23 * 60, 5000), "1h 23m")
})

// ── sanitizeError ──────────────────────────────────────────────────────────
ok("sanitizeError strips control chars and elides", () => {
    assert.strictEqual(sanitizeError("\u001b[31mError: bad\u0007 thing\nnext"), "Error: bad thing next")
    const long = sanitizeError(new Array(300).join("x"))
    assert.ok(long.length <= 160 && long.endsWith("…"))
    assert.strictEqual(sanitizeError(""), "")
})

// ── tailscale status JSON shapes ───────────────────────────────────────────
const SELF = { ID: "1", HostName: "nixos-btw", DNSName: "nixos-btw.tail-net.ts.net.",
               TailscaleIPs: ["100.64.0.1"], OS: "linux", Online: true,
               RxBytes: 10, TxBytes: 20, UserID: "100" }

function tsJson(backend, extra) {
    return JSON.stringify(Object.assign({
        BackendState: backend, Version: "1.98.10",
        Self: SELF, Peer: {}, User: { "100": { LoginName: "nikos@example.com" } },
        Health: []
    }, extra || {}))
}

ok("parseTailscaleStatus Running shape", () => {
    const parsed = parseTailscaleStatus(tsJson("Running", {
        CurrentTailnet: { Name: "tail-net", MagicDNSSuffix: "tail-net.ts.net.", MagicDNSEnabled: true }
    }))
    assert.strictEqual(parsed.backendState, "Running")
    assert.strictEqual(parsed.self.dnsName, "nixos-btw.tail-net.ts.net")   // trailing dot trimmed
    assert.strictEqual(parsed.self.user, "nikos@example.com")
    assert.strictEqual(parsed.tailnetName, "tail-net")
    assert.strictEqual(parsed.magicDns, true)
    assert.strictEqual(parsed.exitNode, null)
})

ok("parseTailscaleStatus NeedsLogin keeps AuthURL", () => {
    const parsed = parseTailscaleStatus(tsJson("NeedsLogin", { AuthURL: "https://login.tailscale.com/a/xyz" }))
    assert.strictEqual(parsed.backendState, "NeedsLogin")
    assert.strictEqual(parsed.authUrl, "https://login.tailscale.com/a/xyz")
})

ok("parseTailscaleStatus sorts peers and resolves exit node", () => {
    const parsed = parseTailscaleStatus(tsJson("Running", {
        Peer: {
            "2": { ID: "2", HostName: "zeta", DNSName: "zeta.ts.net.", Online: false, TailscaleIPs: ["100.64.0.9"] },
            "3": { ID: "3", HostName: "alpha", Online: true, CurAddr: "192.168.1.5",
                   TailscaleIPs: ["100.64.0.3"], ExitNodeOption: true, Relay: "" },
            "4": { ID: "4", HostName: "exitbox", Online: true, ExitNodeOption: true,
                   TailscaleIPs: ["100.64.0.4"], Relay: "fra" }
        },
        ExitNodeStatus: { ID: "4", TailscaleIPs: ["100.64.0.4"], Online: true }
    }))
    assert.deepStrictEqual(parsed.peers.map(p => p.hostName), ["alpha", "exitbox", "zeta"])  // online first
    assert.strictEqual(parsed.exitNode.hostName, "exitbox")
    assert.strictEqual(peerPath(parsed.peers[0]), "direct")
    assert.strictEqual(peerPath(parsed.peers[1]), "relay · fra")
    assert.strictEqual(peerPath(parsed.peers[2]), "offline")
})

ok("parseTailscaleStatus malformed/non-JSON returns null", () => {
    assert.strictEqual(parseTailscaleStatus(""), null)
    assert.strictEqual(parseTailscaleStatus("tailscaled is not running"), null)
    assert.strictEqual(parseTailscaleStatus("[1,2,3]"), null)
})

ok("parseTailscaleStatus Stopped shape", () => {
    const parsed = parseTailscaleStatus(tsJson("Stopped"))
    assert.strictEqual(parsed.backendState, "Stopped")
    assert.deepStrictEqual(parsed.peers, [])
    assert.strictEqual(trimDnsName(parsed.tailnetSuffix), parsed.tailnetSuffix)
})

console.log(`model.test.mjs: ${n} ok`)
