// Pure parsing/formatting model for the WireGuard plugin, ported verbatim
// from ngeran.wireguard's Model.js (MIT). No QML and no processes here, so
// node can exercise everything (model.test.mjs beside this file). Every
// value comes from `nmcli`, `tailscale`, or sysfs — all untrusted text; the
// QML side renders through `textFormat: Text.PlainText` sinks only.
//
// Quickshell JS engine notes (storage.mjs precedent): Date.now()/Math.random()
// throw — callers pass timestamps in. Math.round and the Date constructor
// are fine.
//
// v1 delta vs ngeran (Decision C): `wg show` parsing (parseWgDump) is kept
// for a future sudoers tier but nothing calls it from QML yet.

// Strip ANSI escapes and control characters, elide to `limit` chars — the
// only shape of tool stderr that may reach `lastError` or the panel.
export function sanitizeError(raw, limit) {
    var cap = limit || 160
    var text = String(raw || "")
        .replace(/\u001b\[[0-9;?]*[A-Za-z]/g, "")                    // ANSI CSI sequences
        .replace(/\u001b\][^\u0007]*(\u0007|\u001b\\)?/g, "")        // OSC sequences
        .replace(/[\u0000-\u001f\u007f-\u009f]/g, " ")               // C0/C1 controls incl. ESC
        .replace(/\s+/g, " ")
        .trim()
    if (text.length > cap) text = text.slice(0, cap - 1) + "…"
    return text
}

// nmcli terse output escapes column separators inside values as "\:".
export function unescapeNmcli(value) {
    return String(value || "").replace(/\\:/g, ":")
}

// Split one terse nmcli line into columns, honoring "\:" escapes.
export function splitTerse(line) {
    var parts = []
    var current = ""
    var text = String(line || "")
    for (var i = 0; i < text.length; i++) {
        if (text[i] === "\\" && text[i + 1] === ":") {
            current += ":"
            i++
        } else if (text[i] === ":") {
            parts.push(current)
            current = ""
        } else {
            current += text[i]
        }
    }
    parts.push(current)
    return parts
}

// `nmcli -t -f NAME,UUID,TYPE,STATE,DEVICE,ACTIVE,TIMESTAMP connection show`
// filtered to wireguard profiles: [{name, uuid, state, device, active, activatedAt}]
export function parseTunnelLines(raw) {
    var tunnels = []
    var lines = String(raw || "").split(/\r?\n/)
    for (var i = 0; i < lines.length; i++) {
        var columns = splitTerse(lines[i])
        if (columns.length < 7) continue
        if (columns[2] !== "wireguard") continue
        var timestamp = parseInt(columns[6], 10)
        tunnels.push({
            name: unescapeNmcli(columns[0]),
            uuid: columns[1],
            state: columns[3],
            device: columns[4],
            active: columns[5] === "yes",
            activatedAt: isNaN(timestamp) || timestamp <= 0 ? 0 : timestamp
        })
    }
    return tunnels
}

// Lines of "device rx_bytes tx_bytes" (sysfs counter walks). v1 reads sysfs
// through FileView, so this feeds tests + a future tier only.
export function parseCounters(raw) {
    var counters = {}
    var lines = String(raw || "").split(/\r?\n/)
    for (var i = 0; i < lines.length; i++) {
        var fields = lines[i].trim().split(/\s+/)
        if (fields.length !== 3) continue
        if (!(fields[0] in counters)) counters[fields[0]] = {
            rx: parseInt(fields[1], 10) || 0,
            tx: parseInt(fields[2], 10) || 0
        }
    }
    return counters
}

// The nmcli profile's peers string: one peer per public key, attributes
// space-separated ("PUBKEY allowed-ips=a;b endpoint=h:p persistent-keepalive=25").
// Public keys are base64 and end in "=", so an "=" alone does not make a
// token an attribute — only the known attribute names do.
export function parsePeerProfile(peersRaw) {
    var attributes = ["allowed-ips", "endpoint", "persistent-keepalive"]
    var peers = []
    var current = null
    var tokens = String(peersRaw || "").trim().split(/\s+/)
    for (var i = 0; i < tokens.length; i++) {
        var token = tokens[i]
        if (token === "") continue
        var key = ""
        for (var a = 0; a < attributes.length; a++) {
            if (token.indexOf(attributes[a] + "=") === 0) { key = attributes[a]; break }
        }
        if (key === "") {
            if (current) peers.push(current)
            current = { pubkey: token, endpoint: "", allowedIps: [], keepalive: 0 }
            continue
        }
        if (!current) continue
        var value = token.slice(key.length + 1)
        if (key === "endpoint") current.endpoint = value
        else if (key === "allowed-ips") current.allowedIps = value === "(none)" ? [] : value.split(";").filter(function(v) { return v !== "" })
        else if (key === "persistent-keepalive") current.keepalive = parseInt(value, 10) || 0
    }
    if (current) peers.push(current)
    return peers
}

// `wg show <iface> dump`: a 4-column interface header, then 8-column peer
// rows, all tab-separated. UNUSED in v1 (Decision C: no root `wg`) — kept
// for the possible sudoers tier, tested here so it cannot rot silently.
export function parseWgDump(raw) {
    var lines = String(raw || "").trim().split(/\r?\n/).filter(function(line) { return line.trim() !== "" })
    if (lines.length === 0) return { publicKey: "", listenPort: 0, peers: [] }
    var header = lines[0].split("\t")
    var peers = []
    for (var i = 1; i < lines.length; i++) {
        var columns = lines[i].split("\t")
        if (columns.length < 8) continue
        peers.push({
            pubkey: columns[0],
            endpoint: columns[2] === "(none)" ? "" : columns[2],
            allowedIps: columns[3] === "(none)" ? [] : columns[3].split(",").filter(function(v) { return v !== "" }),
            latestHandshake: parseInt(columns[4], 10) || 0,
            rx: parseInt(columns[5], 10) || 0,
            tx: parseInt(columns[6], 10) || 0,
            keepalive: parseInt(columns[7], 10) || 0
        })
    }
    return {
        publicKey: header[1] || "",
        listenPort: parseInt(header[2], 10) || 0,
        peers: peers
    }
}

// Per-device byte rates across a poll delta, elapsedMs in milliseconds.
// Math.max(0, …) absorbs counter resets (interface recreated) and wraps.
export function computeRates(previous, current, elapsedMs) {
    var rates = {}
    if (elapsedMs <= 0) return rates
    for (var device in current) {
        var before = previous ? previous[device] : null
        if (before) {
            rates[device] = {
                rx: Math.max(0, (current[device].rx - before.rx) / (elapsedMs / 1000)),
                tx: Math.max(0, (current[device].tx - before.tx) / (elapsedMs / 1000))
            }
        }
    }
    return rates
}

// Split a byte count into the digit string and binary unit, so the QML side
// can format the digits and keep the unit literal.
export function splitBytes(value) {
    var bytes = Math.max(0, Math.round(value || 0))
    var units = ["B", "KiB", "MiB", "GiB", "TiB"]
    var index = 0
    while (bytes >= 1024 && index < units.length - 1) {
        bytes /= 1024
        index++
    }
    var decimals = index === 0 ? 0 : (bytes >= 100 ? 0 : 1)
    return { digits: bytes, unit: units[index], decimals: decimals }
}

// Seconds until the most recent handshake, from the wg dump's unix stamp.
export function handshakeAge(latestHandshake, nowSeconds) {
    if (!latestHandshake || latestHandshake <= 0) return -1
    return Math.max(0, nowSeconds - latestHandshake)
}

// Uptime "1h 23m" / "4m 05s" label from an activation unix stamp. Ported
// helper (ngeran formatted this inline in Panel.qml) so tests cover it.
export function uptimeLabel(activatedAt, nowSeconds) {
    if (!activatedAt || activatedAt <= 0) return "—"
    var seconds = Math.max(0, nowSeconds - activatedAt)
    var h = Math.floor(seconds / 3600)
    var m = Math.floor((seconds % 3600) / 60)
    var s = seconds % 60
    if (h > 0) return h + "h " + (m < 10 ? "0" : "") + m + "m"
    return m + "m " + (s < 10 ? "0" : "") + s + "s"
}

// Tailscale's DNS names come with a trailing dot; the panel shows them bare.
export function trimDnsName(value) {
    var text = String(value || "")
    return text.charAt(text.length - 1) === "." ? text.slice(0, -1) : text
}

// `tailscale status --json`:
// {BackendState, AuthURL, Self, Peer, User, CurrentTailnet, ExitNodeStatus, Health}
// Returns null when the CLI printed something that is not JSON (daemon down).
export function parseTailscaleStatus(raw) {
    var data
    try { data = JSON.parse(String(raw || "")) } catch (e) { return null }
    if (!data || typeof data !== "object" || Array.isArray(data)) return null

    var users = data.User && typeof data.User === "object" ? data.User : {}
    function userName(id) {
        var user = users[String(id)]
        if (!user || typeof user !== "object") return ""
        return String(user.LoginName || user.DisplayName || "")
    }

    var selfData = data.Self && typeof data.Self === "object" ? data.Self : {}
    var self = {
        id: String(selfData.ID || ""),
        hostName: String(selfData.HostName || ""),
        dnsName: trimDnsName(selfData.DNSName),
        ips: Array.isArray(selfData.TailscaleIPs) ? selfData.TailscaleIPs.map(String) : [],
        os: String(selfData.OS || ""),
        online: selfData.Online === true,
        relay: String(selfData.Relay || ""),
        curAddr: String(selfData.CurAddr || ""),
        rx: Number(selfData.RxBytes) || 0,
        tx: Number(selfData.TxBytes) || 0,
        user: userName(selfData.UserID)
    }

    var peers = []
    var peerMap = data.Peer && typeof data.Peer === "object" ? data.Peer : {}
    for (var key in peerMap) {
        var peer = peerMap[key]
        if (!peer || typeof peer !== "object") continue
        peers.push({
            id: String(peer.ID || key),
            hostName: String(peer.HostName || ""),
            dnsName: trimDnsName(peer.DNSName),
            os: String(peer.OS || ""),
            ips: Array.isArray(peer.TailscaleIPs) ? peer.TailscaleIPs.map(String) : [],
            online: peer.Online === true,
            exitNode: peer.ExitNode === true,
            exitNodeOption: peer.ExitNodeOption === true,
            relay: String(peer.Relay || ""),
            curAddr: String(peer.CurAddr || ""),
            rx: Number(peer.RxBytes) || 0,
            tx: Number(peer.TxBytes) || 0,
            user: userName(peer.UserID)
        })
    }
    // Online first, then by name, so a short list shows the devices that matter.
    peers.sort(function(a, b) {
        if (a.online !== b.online) return a.online ? -1 : 1
        return String(a.hostName).localeCompare(String(b.hostName))
    })

    var exit = null
    var exitStatus = data.ExitNodeStatus
    if (exitStatus && typeof exitStatus === "object" && exitStatus.ID) {
        var exitId = String(exitStatus.ID)
        var exitIps = Array.isArray(exitStatus.TailscaleIPs) ? exitStatus.TailscaleIPs.map(String) : []
        for (var i = 0; i < peers.length; i++) {
            if (peers[i].id === exitId || (exitIps.length > 0 && peers[i].ips.join() === exitIps.join())) {
                exit = peers[i]
                break
            }
        }
        if (!exit) exit = { id: exitId, hostName: "", dnsName: "", ips: exitIps, online: exitStatus.Online === true }
    }

    var tailnet = data.CurrentTailnet && typeof data.CurrentTailnet === "object" ? data.CurrentTailnet : {}
    var health = Array.isArray(data.Health)
        ? data.Health.map(function(h) { return String(h) }).filter(function(h) { return h !== "" })
        : []

    return {
        backendState: String(data.BackendState || "Unknown"),
        authUrl: String(data.AuthURL || ""),
        tailnetName: String(tailnet.Name || tailnet.MagicDNSSuffix || trimDnsName(data.MagicDNSSuffix) || ""),
        tailnetSuffix: trimDnsName(tailnet.MagicDNSSuffix || data.MagicDNSSuffix),
        magicDns: tailnet.MagicDNSEnabled === true,
        self: self,
        peers: peers,
        exitNode: exit,
        health: health,
        version: String(data.Version || "")
    }
}

// One short "direct" / "relay · fra" / "idle" label for a peer row.
export function peerPath(peer) {
    if (!peer) return ""
    if (peer.curAddr && peer.curAddr !== "") return "direct"
    if (peer.relay && peer.relay !== "") return "relay · " + peer.relay
    return peer.online ? "idle" : "offline"
}

// Dual export: the Quickshell JS engine loads .mjs via `import`, node's
// test runner goes through require (storage.mjs precedent).
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        sanitizeError, unescapeNmcli, splitTerse, parseTunnelLines, parseCounters,
        parsePeerProfile, parseWgDump, computeRates, splitBytes, handshakeAge,
        uptimeLabel, trimDnsName, parseTailscaleStatus, peerPath
    }
}
