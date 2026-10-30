// netengineer.test.mjs — ENGINEER-pane multi-tool parsing (I8 split)
import * as M from "./netengineer.mjs"

let n = 0
function ok(cond, label) {
    n++
    if (!cond) { console.error("FAIL: " + label); process.exitCode = 1 }
}

const FULL = [
    "==IW",
    "      freq: 5180",
    "      signal: -52.00 dBm [72, 71, 70, 68]",
    "      tx bitrate: 866.7 MBit/s VHT-MCS 9 80MHz",
    "==STATION",
    "      signal avg: -55.00 dBm",
    "      beacon signal avg: -54.00 dBm",
    "      rx bitrate: 780.0 MBit/s",
    "      tx retries: 123",
    "      tx failed: 4",
    "      beacon loss: 0",
    "      rx drop misc: 8",
    "      tx packets: 1000",
    "==REG",
    "country US: DFS-ETSI",
    "==ADDR",
    '[{"ifindex":2,"addr_info":[{"family":"inet6","scope":"global","local":"fe80::1","prefixlen":64},{"family":"inet","scope":"global","local":"192.168.1.10","prefixlen":24},{"family":"inet","scope":"link","local":"169.254.1.2","prefixlen":16}]}]',
    "==ROUTE",
    '[{"dst":"192.168.1.0/24","dev":"wlan0","protocol":"kernel","metric":600},{"dst":"default","gateway":"192.168.1.1","dev":"wlan0","metric":600,"protocol":"dhcp"}]',
    "==STATS",
    '[{"mtu":1500,"stats64":{"rx":{"bytes":1000,"errors":1,"dropped":2},"tx":{"bytes":2000,"errors":3,"dropped":4}}}]',
    "==NEIGH",
    '[{"dst":"192.168.1.1","lladdr":"aa:bb:cc:dd:ee:ff","dev":"wlan0"},{"dst":"192.168.1.255","dev":"wlan0"}]',
    "==RESOLVE",
    "DNS Servers: 1.1.1.1 8.8.8.8",
    "DNS Domain: lan",
    "==DHCP",
    "dhcp_server_identifier=192.168.1.1",
    "dhcp_lease_time=7200",
    "==LISTEN",
    "tcp   LISTEN 0   128   0.0.0.0:22   0.0.0.0:*",
    "udp   UNCONN 0   0     0.0.0.0:68   0.0.0.0:*"
].join("\n")

const p = M.parseEngineer(FULL)

// ── iw ──────────────────────────────────────────────────────────────────────
ok(p.link.freqMhz === 5180 && p.link.channel === 36, "5 GHz freq → channel 36")
ok(p.link.signalDbm === -52 && p.link.chains === "72, 71, 70, 68", "signal + per-chain bracket")
ok(p.link.txBitrate === "866.7 MBit/s" && p.link.txMcs === "VHT-MCS 9 80MHz", "tx bitrate + MCS suffix")

// ── station ─────────────────────────────────────────────────────────────────
ok(p.link.signalAvgDbm === -55 && p.link.beaconAvgDbm === -54, "station averages")
ok(p.link.rxBitrate === "780.0 MBit/s", "rx bitrate")
ok(p.link.txRetries === 123 && p.link.txPackets === 1000 && p.link.txFailed === 4, "airtime counters")
ok(p.link.retryPct === 11, "retryPct 123/1123 → 11.0 (1dp)")
ok(p.link.rxDropMisc === 8 && p.link.beaconLoss === 0, "drop/loss counters")

// ── reg ─────────────────────────────────────────────────────────────────────
ok(p.link.regDomain === "country US: DFS-ETSI", "reg domain (trimmed section)")

// ── ip -json addr ───────────────────────────────────────────────────────────
ok(JSON.stringify(p.addr.v4) === '["192.168.1.10/24"]', "v4 globals only (link-scope skipped)")
ok(JSON.stringify(p.addr.v6) === '["fe80::1/64"]', "v6 globals")

// ── routes (default first) ──────────────────────────────────────────────────
ok(p.routes.length === 2 && p.routes[0].dst === "default" && p.routes[0].via === "192.168.1.1",
   "default route sorts first")
ok(p.routes[1].dst === "192.168.1.0/24" && p.routes[1].proto === "kernel", "second route fields")

// ── stats64 ─────────────────────────────────────────────────────────────────
ok(p.ifaceStats.mtu === 1500 && p.ifaceStats.rxBytes === 1000 && p.ifaceStats.txDropped === 4,
   "iface stats block")

// ── neighbors (lladdr required) ─────────────────────────────────────────────
ok(p.neighbors.length === 1 && p.neighbors[0].mac === "aa:bb:cc:dd:ee:ff", "neighbor needs lladdr")

// ── resolvectl ──────────────────────────────────────────────────────────────
ok(JSON.stringify(p.addr.dnsServers) === '["1.1.1.1","8.8.8.8"]', "dns servers split")
ok(p.addr.dnsDomain === "lan", "dns domain")

// ── dhcp lease ──────────────────────────────────────────────────────────────
ok(p.addr.dhcpServer === "192.168.1.1" && p.addr.leaseHours === 2, "lease 7200 s → 2.0 h")

// ── listeners ───────────────────────────────────────────────────────────────
ok(p.listeners.length === 2 && p.listeners[0].local === "0.0.0.0:22"
   && p.listeners[1].proto === "udp", "tcp+udp listeners (parts[4])")

// ── patch semantics: absent sections stay absent ────────────────────────────
const mini = M.parseEngineer("==IW\n      freq: 2412\n")
ok(mini.link.freqMhz === 2412 && mini.link.channel === 1, "2.4 GHz → channel 1")
ok(mini.routes === undefined && mini.ifaceStats === undefined
   && mini.neighbors === undefined && mini.listeners === undefined, "absent sections → absent fields")
ok(mini.link.regDomain === undefined && mini.addr.dnsServers === undefined, "no reg/dns")
ok(mini.link !== undefined && mini.addr !== undefined, "link/addr always present")

const empty = M.parseEngineer("")
ok(empty.link.txBitrate === undefined && empty.routes === undefined, "empty blob → bare patch")

// empty REG section must not set regDomain
const regOnly = M.parseEngineer("==REG\n\n==IW\n      freq: 5180\n")
ok(regOnly.link.regDomain === undefined && regOnly.link.channel === 36, "blank REG skipped")

// RESOLVE fallback: no "DNS Servers:" → Current DNS Server
const fb = M.parseEngineer("==RESOLVE\nCurrent DNS Server: 9.9.9.9\nDNS Domain: home\n")
ok(JSON.stringify(fb.addr.dnsServers) === '["9.9.9.9"]' && fb.addr.dnsDomain === "home",
   "current-dns-server fallback")

// garbage JSON in a section must not throw (j() → null → empty list, exactly
// like the original's unconditional root.engRoutes = rs)
const bad = M.parseEngineer("==ROUTE\nnot json\n==NEIGH\n[broken\n")
ok(JSON.stringify(bad.routes) === "[]" && JSON.stringify(bad.neighbors) === "[]",
   "garbage JSON sections → empty lists, no throw")

console.log(`netengineer.test: ${n} asserts`)
