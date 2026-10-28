// =============================================================================
// netengineer.mjs — ENGINEER-pane multi-tool parser (pure, node-testable, I8)
// =============================================================================
// NetworkControlService._absorbEngineer consumed the combined probe output of
// iw / iw station / iw reg / ip -json (addr, route, -s link) / resolvectl /
// dhcpcd lease info / ss -tuln inline. This file owns that parsing; the
// service keeps the probe Process and applies the returned patch.
//
// Input contract: one text blob, sections headed by "==NAME" lines (IW,
// STATION, REG, ADDR, ROUTE, STATS, NEIGH, RESOLVE, DHCP, LISTEN). Returns a
// patch: `link` and `addr` are ALWAYS present (the service always assigned
// them); routes/ifaceStats/listeners/neighbors are present only when their
// section was — absent = the service keeps its previous value, exactly the
// old `if (sec.X !== undefined)` guards.
// =============================================================================

function parseSections(out) {
    var sec = {}
    var lines = (out || "").split("\n")
    var cur = ""
    for (var i = 0; i < lines.length; i++) {
        var L = lines[i]
        if (L.indexOf("==") === 0) { cur = L.substring(2).trim(); sec[cur] = ""; continue }
        if (cur !== "") sec[cur] += L + "\n"
    }
    return sec
}

export function parseEngineer(out) {
    var sec = parseSections(out)
    var link = {}, addr = {}
    var patch = { link: link, addr: addr }
    var m

    if (sec.IW !== undefined) {
        if ((m = /freq:\s*([\d.]+)/.exec(sec.IW))) {
            link.freqMhz = parseFloat(m[1])
            link.channel = Math.round(link.freqMhz < 3000 ? (link.freqMhz - 2407) / 5
                                                          : (link.freqMhz - 5000) / 5)
        }
        if ((m = /signal:\s*(-?[\d.]+)\s*dBm(?:\s*\[([^\]]*)\])?/.exec(sec.IW))) {
            link.signalDbm = parseFloat(m[1])
            if (m[2] !== undefined) link.chains = m[2]
        }
        if ((m = /tx bitrate:\s*([\d.]+)\s*MBit\/s\s*(.*)/.exec(sec.IW))) {
            link.txBitrate = m[1] + " MBit/s"
            if (m[2] !== "") link.txMcs = m[2].trim()
        }
    }
    if (sec.STATION !== undefined) {
        if ((m = /signal avg:\s*(-?[\d.]+)\s*dBm/.exec(sec.STATION))) link.signalAvgDbm = parseFloat(m[1])
        if ((m = /beacon signal avg:\s*(-?[\d.]+)\s*dBm/.exec(sec.STATION))) link.beaconAvgDbm = parseFloat(m[1])
        if ((m = /rx bitrate:\s*([\d.]+)\s*MBit\/s/.exec(sec.STATION))) link.rxBitrate = m[1] + " MBit/s"
        // airtime-health counters (nexthop-derived): "full signal bar,
        // slow Wi-Fi" usually lives here, not in the signal number
        if ((m = /tx retries:\s*(\d+)/.exec(sec.STATION))) link.txRetries = parseInt(m[1], 10)
        if ((m = /tx failed:\s*(\d+)/.exec(sec.STATION))) link.txFailed = parseInt(m[1], 10)
        if ((m = /beacon loss:\s*(\d+)/.exec(sec.STATION))) link.beaconLoss = parseInt(m[1], 10)
        if ((m = /rx drop(?:ped)? misc:\s*(\d+)/.exec(sec.STATION))) link.rxDropMisc = parseInt(m[1], 10)
        if ((m = /tx packets:\s*(\d+)/.exec(sec.STATION))) link.txPackets = parseInt(m[1], 10)
        if (link.txRetries !== undefined && link.txPackets !== undefined
            && (link.txPackets + link.txRetries) > 0)
            link.retryPct = Math.round(link.txRetries / (link.txPackets + link.txRetries) * 1000) / 10
    }
    if (sec.REG !== undefined && sec.REG.trim() !== "") link.regDomain = sec.REG.trim()

    var j = function(t) { try { return JSON.parse(sec[t]) } catch (e) { return null } }
    if (sec.ADDR !== undefined) {
        var aj = j("ADDR")
        if (aj && aj[0] && aj[0].addr_info) {
            var v4 = [], v6 = []
            for (var a = 0; a < aj[0].addr_info.length; a++) {
                var ai = aj[0].addr_info[a]
                if (ai.scope !== "global" || !ai.local) continue
                var cidr = ai.local + "/" + ai.prefixlen
                if (ai.family === "inet6") v6.push(cidr); else v4.push(cidr)
            }
            addr.v4 = v4; addr.v6 = v6
        }
    }
    if (sec.ROUTE !== undefined) {
        var rj = j("ROUTE")
        var rs = []
        if (rj) for (var r = 0; r < rj.length; r++) {
            var ro = rj[r]
            rs.push({ dst: ro.dst || "default", via: ro.gateway || ro.prefsrc || "—",
                      dev: ro.dev || "—", metric: ro.metric !== undefined ? ro.metric : "—",
                      proto: ro.protocol || "—" })
        }
        rs.sort(function(a, b) { return (a.dst === "default" ? -1 : 1) - (b.dst === "default" ? -1 : 1) || a.metric - b.metric })
        patch.routes = rs
    }
    if (sec.STATS !== undefined) {
        var sj = j("STATS")
        if (sj && sj[0]) {
            var s64 = sj[0].stats64 || {}
            patch.ifaceStats = {
                mtu: sj[0].mtu || "—",
                rxBytes: (s64.rx && s64.rx.bytes) || 0, rxErrors: (s64.rx && s64.rx.errors) || 0,
                rxDropped: (s64.rx && s64.rx.dropped) || 0,
                txBytes: (s64.tx && s64.tx.bytes) || 0, txErrors: (s64.tx && s64.tx.errors) || 0,
                txDropped: (s64.tx && s64.tx.dropped) || 0
            }
        }
    }
    if (sec.NEIGH !== undefined) {
        var nj = j("NEIGH")
        var ns = []
        if (nj) for (var n = 0; n < nj.length; n++)
            if (nj[n].lladdr) ns.push({ ip: nj[n].dst, mac: nj[n].lladdr, dev: nj[n].dev || "—" })
        patch.neighbors = ns
    }
    if (sec.RESOLVE !== undefined) {
        var ds = []
        var dm = /DNS Servers:(.*)/.exec(sec.RESOLVE)
        if (dm) ds = dm[1].trim().split(/\s+/).filter(function(s) { return s !== "" })
        if (ds.length === 0 && (m = /Current DNS Server:\s*(\S+)/.exec(sec.RESOLVE))) ds = [m[1]]
        addr.dnsServers = ds
        if ((m = /DNS Domain:\s*(.*)/.exec(sec.RESOLVE))) addr.dnsDomain = m[1].trim()
    }
    if (sec.DHCP !== undefined) {
        if ((m = /dhcp_server_identifier\s*=\s*(\S+)/.exec(sec.DHCP))) addr.dhcpServer = m[1]
        if ((m = /dhcp_lease_time\s*=\s*(\d+)/.exec(sec.DHCP))) {
            var s = parseInt(m[1], 10)
            addr.leaseHours = Math.round(s / 360) / 10   // hours, 1dp
        }
    }
    if (sec.LISTEN !== undefined) {
        var ls = []
        var ll = sec.LISTEN.split("\n")
        for (var p = 0; p < ll.length; p++) {
            var parts = ll[p].trim().split(/\s+/)
            if (parts.length >= 5 && (parts[0] === "tcp" || parts[0] === "udp"))
                ls.push({ proto: parts[0], local: parts[4] })
        }
        patch.listeners = ls
    }
    return patch
}
